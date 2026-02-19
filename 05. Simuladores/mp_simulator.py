#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Simulador simple de Mercado Pago para pruebas locales.

- Sirve "payments" por ID en:
    GET /v1/payments/{id}
    GET /payments/{id}

- Admin API para cargar pagos y escenarios:
    GET  /__admin/payments
    POST /__admin/payments
    POST /__admin/reset
    POST /__admin/scenarios/mixed_ok
    POST /__admin/scenarios/mixed_fail
    POST /__admin/scenarios/simple

- Soporta "status_sequence" para que un mismo payment_id vaya cambiando de status
  en cada consulta GET (útil para simular: authorized -> approved con el mismo id).

Sin dependencias externas (solo stdlib).
"""

from __future__ import annotations

import argparse
import json
import threading
import time
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict, Optional
from urllib.parse import urlparse, parse_qs

_LOCK = threading.Lock()

DEFAULT_REFUND_DELAY_OK_SECONDS = 45
DEFAULT_REFUND_DELAY_TIMEOUT_SECONDS = 600


def build_next_refund_mode(mode: str = "ok", delay_seconds: int = 0) -> Dict[str, Any]:
    return {
        "mode": mode,
        "delay_seconds": max(0, int(delay_seconds)),
        "set_at": utc_now_iso(),
    }


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


@dataclass
class PaymentRecord:
    id: int
    status: str
    transaction_amount: float
    external_reference: str
    currency_id: str = "ARS"
    payment_method_id: str = "account_money"

    # Para simular status cambiante:
    status_sequence: Optional[list[str]] = None
    sequence_index: int = 0

    date_created: str = utc_now_iso()

    def to_mp_json(self) -> Dict[str, Any]:
        """JSON mínimo que suele mapear bien a SDKs (status, transaction_amount, external_reference, etc.)"""
        status_detail_map = {
            "approved": "accredited",
            "authorized": "pending",
            "rejected": "rejected",
            "cancelled": "cancelled",
        }
        payload = {
            "id": self.id,
            "status": self.status,
            "status_detail": status_detail_map.get(self.status, "pending"),
            "transaction_amount": self.transaction_amount,
            "currency_id": self.currency_id,
            "payment_method_id": self.payment_method_id,
            "external_reference": self.external_reference,
            "date_created": self.date_created,
        }
        return payload

    def advance_if_needed(self) -> None:
        """Si existe status_sequence, avanza al próximo estado por cada GET."""
        if not self.status_sequence:
            return
        if self.sequence_index < 0:
            self.sequence_index = 0
        if self.sequence_index >= len(self.status_sequence):
            # Queda clavado en el último
            self.status = self.status_sequence[-1]
            return

        self.status = self.status_sequence[self.sequence_index]
        # Avanza para el próximo GET
        if self.sequence_index < len(self.status_sequence) - 1:
            self.sequence_index += 1


class PaymentStore:
    def __init__(self, persist_path: Optional[str] = None) -> None:
        self.persist_path = persist_path
        self.payments: Dict[int, PaymentRecord] = {}
        self.refund_state: Dict[int, Dict[str, Any]] = {}
        self.next_refund_mode: Dict[str, Any] = build_next_refund_mode("ok", 0)

    def load(self) -> None:
        if not self.persist_path:
            return
        try:
            with open(self.persist_path, "r", encoding="utf-8") as f:
                raw = json.load(f)
            p = {}
            for k, v in raw.get("payments", {}).items():
                rec = PaymentRecord(**v)
                p[int(k)] = rec
            self.payments = p
            self.refund_state = {int(k): v for k, v in raw.get("refund_state", {}).items()}
            self.next_refund_mode = raw.get("next_refund_mode", build_next_refund_mode("ok", 0))
        except FileNotFoundError:
            return

    def save(self) -> None:
        if not self.persist_path:
            return
        data = {
            "payments": {str(pid): asdict(rec) for pid, rec in self.payments.items()},
            "refund_state": {str(pid): state for pid, state in self.refund_state.items()},
            "next_refund_mode": self.next_refund_mode,
        }
        with open(self.persist_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def reset(self) -> None:
        self.payments = {}
        self.refund_state = {}
        self.next_refund_mode = build_next_refund_mode("ok", 0)
        self.save()

    def upsert(self, rec: PaymentRecord) -> None:
        self.payments[rec.id] = rec
        self.save()

    def list_all(self) -> Dict[int, PaymentRecord]:
        return dict(self.payments)

    def get(self, pid: int) -> Optional[PaymentRecord]:
        return self.payments.get(pid)

    def ensure_payment(self, pid: int) -> PaymentRecord:
        rec = self.get(pid)
        if rec is None:
            rec = PaymentRecord(
                id=pid,
                status="approved",
                transaction_amount=0.0,
                external_reference=f"SIM_{pid}",
            )
            self.upsert(rec)
        return rec

    def get_next_refund_mode(self) -> Dict[str, Any]:
        return dict(self.next_refund_mode)

    def set_next_refund_mode(self, mode: str, delay_seconds: int = 0) -> Dict[str, Any]:
        self.next_refund_mode = build_next_refund_mode(mode, delay_seconds)
        self.save()
        return self.get_next_refund_mode()

    def consume_next_refund_mode(self) -> Dict[str, Any]:
        mode = self.get_next_refund_mode()
        self.next_refund_mode = build_next_refund_mode("ok", 0)
        self.save()
        return mode

    def schedule_refund(self, pid: int, mode_used: str, delay_seconds: int = 0) -> Dict[str, Any]:
        now_epoch = time.time()
        apply_at: Optional[float] = None
        if delay_seconds > 0:
            apply_at = now_epoch + delay_seconds

        state = {
            "requested_at": now_epoch,
            "apply_at": apply_at,
            "mode_used": mode_used,
            "delay_seconds": int(delay_seconds),
            "applied": False,
        }
        self.refund_state[pid] = state

        if delay_seconds <= 0:
            rec = self.ensure_payment(pid)
            rec.status = "refunded"
            rec.status_sequence = ["refunded"]
            rec.sequence_index = 0
            state["applied"] = True
            state["applied_at"] = now_epoch
            self.upsert(rec)

        self.save()
        return state

    def apply_pending_refund_if_due(self, pid: int) -> bool:
        state = self.refund_state.get(pid)
        if not state or state.get("applied"):
            return False

        apply_at = state.get("apply_at")
        if apply_at is None or time.time() < float(apply_at):
            return False

        rec = self.ensure_payment(pid)
        rec.status = "refunded"
        rec.status_sequence = ["refunded"]
        rec.sequence_index = 0
        state["applied"] = True
        state["applied_at"] = time.time()
        self.upsert(rec)
        self.save()
        print(f"[{utc_now_iso()}] Refund transition applied for payment_id={pid}")
        return True


STORE: PaymentStore


def json_response(handler: BaseHTTPRequestHandler, status: int, payload: Any) -> None:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def text_response(handler: BaseHTTPRequestHandler, status: int, text: str) -> None:
    body = text.encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "text/plain; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def read_json_body(handler: BaseHTTPRequestHandler) -> Any:
    length = int(handler.headers.get("Content-Length", "0") or "0")
    if length <= 0:
        return None
    raw = handler.rfile.read(length)
    if not raw:
        return None
    return json.loads(raw.decode("utf-8"))


class MpSimHandler(BaseHTTPRequestHandler):
    server_version = "MpSim/1.0"

    def log_message(self, format: str, *args: Any) -> None:
        # Log simple por consola
        print("[%s] %s - %s" % (utc_now_iso(), self.address_string(), format % args))

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        qs = parse_qs(parsed.query)

        if path == "":
            path = "/"

        # Health
        if path == "/":
            return json_response(self, 200, {"ok": True, "service": "mp-simulator", "time": utc_now_iso()})

        # Admin list
        if path == "/__admin/payments":
            with _LOCK:
                allp = STORE.list_all()
                payload = {
                    "count": len(allp),
                    "payments": {str(pid): asdict(rec) for pid, rec in allp.items()},
                }
            return json_response(self, 200, payload)

        if path == "/__admin/next_refund":
            with _LOCK:
                mode = STORE.get_next_refund_mode()
            return json_response(self, 200, {"ok": True, "next_refund_mode": mode})

        # Payments endpoints
        pid = self._extract_payment_id(path)
        if pid is not None:
            with _LOCK:
                STORE.apply_pending_refund_if_due(pid)
                rec = STORE.get(pid)
                if rec is None:
                    return json_response(self, 404, {"message": "payment not found", "id": pid})
                # Avanza si tiene secuencia
                rec.advance_if_needed()
                STORE.upsert(rec)

                # Permitir override rápido vía query (?status=approved)
                if "status" in qs and qs["status"]:
                    rec.status = str(qs["status"][0])
                    STORE.upsert(rec)

                payload = rec.to_mp_json()

            return json_response(self, 200, payload)

        return json_response(self, 404, {"message": "not found", "path": path})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        qs = parse_qs(parsed.query)

        # Reset
        if path == "/__admin/reset":
            with _LOCK:
                STORE.reset()
            return json_response(self, 200, {"ok": True, "message": "reset done"})

        if path == "/__admin/next_refund/reset":
            with _LOCK:
                mode = STORE.set_next_refund_mode("ok", 0)
            print(f"[{utc_now_iso()}] next_refund_mode set via admin: {mode}")
            return json_response(self, 200, {"ok": True, "next_refund_mode": mode})

        if path == "/__admin/next_refund/ok":
            with _LOCK:
                mode = STORE.set_next_refund_mode("ok", 0)
            print(f"[{utc_now_iso()}] next_refund_mode set via admin: {mode}")
            return json_response(self, 200, {"ok": True, "next_refund_mode": mode})

        if path == "/__admin/next_refund/delay_ok":
            seconds = self._query_int(qs, "seconds", DEFAULT_REFUND_DELAY_OK_SECONDS)
            with _LOCK:
                mode = STORE.set_next_refund_mode("delay_ok", seconds)
            print(f"[{utc_now_iso()}] next_refund_mode set via admin: {mode}")
            return json_response(self, 200, {"ok": True, "next_refund_mode": mode})

        if path == "/__admin/next_refund/delay_timeout":
            seconds = self._query_int(qs, "seconds", DEFAULT_REFUND_DELAY_TIMEOUT_SECONDS)
            with _LOCK:
                mode = STORE.set_next_refund_mode("delay_timeout", seconds)
            print(f"[{utc_now_iso()}] next_refund_mode set via admin: {mode}")
            return json_response(self, 200, {"ok": True, "next_refund_mode": mode})

        if path == "/__admin/next_refund/no_response":
            with _LOCK:
                mode = STORE.set_next_refund_mode("no_response", 0)
            print(f"[{utc_now_iso()}] next_refund_mode set via admin: {mode}")
            return json_response(self, 200, {"ok": True, "next_refund_mode": mode})

        if self._is_refund_path(path):
            refund_pid = self._extract_refund_payment_id(path)
            if refund_pid is None:
                return json_response(self, 400, {"message": "invalid payment id"})
            return self._handle_refund(refund_pid)

        # Upsert payment
        if path == "/__admin/payments":
            body = read_json_body(self)
            if not isinstance(body, dict):
                return json_response(self, 400, {"message": "JSON body requerido"})
            try:
                rec = PaymentRecord(**body)
            except TypeError as e:
                return json_response(self, 400, {"message": "payload inválido", "error": str(e)})
            with _LOCK:
                STORE.upsert(rec)
            return json_response(self, 200, {"ok": True, "id": rec.id})

        # Scenarios
        if path == "/__admin/scenarios/mixed_ok":
            body = read_json_body(self) or {}
            return self._scenario_mixed(body, ok=True)

        if path == "/__admin/scenarios/mixed_fail":
            body = read_json_body(self) or {}
            return self._scenario_mixed(body, ok=False)

        if path == "/__admin/scenarios/mixed_rejected":
            body = read_json_body(self) or {}
            return self._scenario_mixed(body, ok=True, payment_2_final_status="rejected")

        if path == "/__admin/scenarios/mixed_cancelled":
            body = read_json_body(self) or {}
            return self._scenario_mixed(body, ok=True, payment_2_final_status="cancelled")

        if path == "/__admin/scenarios/simple":
            body = read_json_body(self) or {}
            return self._scenario_simple(body)

        return json_response(self, 404, {"message": "not found", "path": path})

    def _extract_payment_id(self, path: str) -> Optional[int]:
        # Acepta /v1/payments/{id} o /payments/{id}
        parts = path.strip("/").split("/")
        if len(parts) == 3 and parts[0] == "v1" and parts[1] == "payments":
            return self._to_int(parts[2])
        if len(parts) == 2 and parts[0] == "payments":
            return self._to_int(parts[1])
        return None

    def _is_refund_path(self, path: str) -> bool:
        parts = path.strip("/").split("/")
        if len(parts) == 4 and parts[0] == "v1" and parts[1] == "payments" and parts[3] == "refunds":
            return True
        if len(parts) == 3 and parts[0] == "payments" and parts[2] == "refunds":
            return True
        return False

    def _extract_refund_payment_id(self, path: str) -> Optional[int]:
        parts = path.strip("/").split("/")
        if len(parts) == 4 and parts[0] == "v1" and parts[1] == "payments" and parts[3] == "refunds":
            return self._to_int(parts[2])
        if len(parts) == 3 and parts[0] == "payments" and parts[2] == "refunds":
            return self._to_int(parts[1])
        return None

    def _query_int(self, qs: Dict[str, list[str]], key: str, default: int) -> int:
        raw = qs.get(key, [str(default)])[0]
        try:
            return max(0, int(raw))
        except (TypeError, ValueError):
            return default

    def _handle_refund(self, pid: int) -> None:
        if pid is None:
            return json_response(self, 400, {"message": "invalid payment id"})

        with _LOCK:
            rec = STORE.ensure_payment(pid)
            mode = STORE.consume_next_refund_mode()

        mode_name = str(mode.get("mode", "ok"))
        mode_delay = int(mode.get("delay_seconds", 0) or 0)
        print(f"[{utc_now_iso()}] next_refund_mode consumed by payment_id={pid}: {mode}")

        if mode_name == "no_response":
            print(f"[{utc_now_iso()}] refund no_response mode active for payment_id={pid}; sleeping")
            time.sleep(3600)
            return

        delay_to_apply = 0
        if mode_name == "delay_ok":
            delay_to_apply = mode_delay if mode_delay > 0 else DEFAULT_REFUND_DELAY_OK_SECONDS
        elif mode_name == "delay_timeout":
            delay_to_apply = mode_delay if mode_delay > 0 else DEFAULT_REFUND_DELAY_TIMEOUT_SECONDS

        with _LOCK:
            state = STORE.schedule_refund(pid, mode_name, delay_to_apply)

        refund_id = int(time.time() * 1000)
        payload = {
            "id": refund_id,
            "payment_id": rec.id,
            "status": "approved",
            "mode_used": mode_name,
            "delay_seconds": delay_to_apply,
            "refund_state": state,
        }
        return json_response(self, 200, payload)

    def _to_int(self, s: str) -> Optional[int]:
        try:
            return int(s)
        except ValueError:
            return None

    def _scenario_simple(self, body: Dict[str, Any]) -> None:
        """
        Crea 1 payment APPROVED.
        Body opcional:
          {
            "payment_id": 2323,
            "external_reference": "BGSQR_05500",
            "amount": 100.0,
            "payment_method_id": "debvisa"
          }
        """
        payment_id = int(body.get("payment_id", 2323))
        ext = str(body.get("external_reference", "BGSQR_05500"))
        amount = float(body.get("amount", 100.0))
        method = str(body.get("payment_method_id", "debvisa"))

        rec = PaymentRecord(
            id=payment_id,
            status="approved",
            transaction_amount=amount,
            external_reference=ext,
            payment_method_id=method,
            status_sequence=["approved"],
        )
        with _LOCK:
            STORE.upsert(rec)

        return json_response(self, 200, {"ok": True, "scenario": "simple", "payment_id": payment_id})

    def _scenario_mixed(self, body: Dict[str, Any], ok: bool, payment_2_final_status: str = "approved") -> None:
        """
        Crea escenario mixto:
        - payment_id_1: authorized -> approved (mismo id cambia status)
        - payment_id_2: approved
        Ambos comparten external_reference.

        Body opcional:
          {
            "payment_id_1": 135601127719,
            "payment_id_2": 136220249654,
            "external_reference": "BGSQR_05500",
            "amount_1": 420.73,
            "amount_2": 9.27,
            "method_1": "account_money",
            "method_2": "master"
          }

        ok=True  => ambas partes existen
        ok=False => sólo existe 1 approved (payment_id_2); sirve para testear timeout
        """
        pid1 = int(body.get("payment_id_1", 135601127719))
        pid2 = int(body.get("payment_id_2", 136220249654))
        ext = str(body.get("external_reference", "BGSQR_05500"))
        a1 = float(body.get("amount_1", 420.73))
        a2 = float(body.get("amount_2", 9.27))
        m1 = str(body.get("method_1", "account_money"))
        m2 = str(body.get("method_2", "master"))

        rec1 = PaymentRecord(
            id=pid1,
            status="authorized",
            transaction_amount=a1,
            external_reference=ext,
            payment_method_id=m1,
            status_sequence=["authorized", "approved"] if ok else ["authorized"],  # en FAIL, nunca pasa a approved
        )

        rec2 = PaymentRecord(
            id=pid2,
            status=payment_2_final_status,
            transaction_amount=a2,
            external_reference=ext,
            payment_method_id=m2,
            status_sequence=[payment_2_final_status],
        )

        with _LOCK:
            STORE.upsert(rec1)
            STORE.upsert(rec2)

        scenario_name = "mixed_fail"
        if ok:
            scenario_name = {
                "approved": "mixed_ok",
                "rejected": "mixed_rejected",
                "cancelled": "mixed_cancelled",
            }.get(payment_2_final_status, "mixed_ok")

        return json_response(
            self,
            200,
            {
                "ok": True,
                "scenario": scenario_name,
                "payment_id_1": pid1,
                "payment_id_2": pid2,
                "external_reference": ext,
            },
        )


def run_server(host: str, port: int, persist_path: Optional[str]) -> None:
    global STORE
    STORE = PaymentStore(persist_path=persist_path)
    with _LOCK:
        STORE.load()

    httpd = ThreadingHTTPServer((host, port), MpSimHandler)
    print(f"MP Simulator escuchando en http://{host}:{port}")
    print("Endpoints:")
    print("  GET  /v1/payments/{id}")
    print("  GET  /payments/{id}")
    print("  GET  /__admin/payments")
    print("  GET  /__admin/next_refund")
    print("  POST /__admin/payments")
    print("  POST /__admin/reset")
    print("  POST /__admin/next_refund/reset")
    print("  POST /__admin/next_refund/ok")
    print("  POST /__admin/next_refund/delay_ok?seconds=45")
    print("  POST /__admin/next_refund/delay_timeout?seconds=600")
    print("  POST /__admin/next_refund/no_response")
    print("  POST /v1/payments/{id}/refunds")
    print("  POST /payments/{id}/refunds")
    print("  POST /__admin/scenarios/simple")
    print("  POST /__admin/scenarios/mixed_ok")
    print("  POST /__admin/scenarios/mixed_fail")
    print("  POST /__admin/scenarios/mixed_rejected")
    print("  POST /__admin/scenarios/mixed_cancelled")
    print("")
    print("CTRL+C para salir.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nSaliendo...")


def main() -> None:
    parser = argparse.ArgumentParser(description="Simulador local de Mercado Pago (payments GET).")
    parser.add_argument("--host", default="127.0.0.1", help="Host de escucha (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=5005, help="Puerto de escucha (default: 5005)")
    parser.add_argument(
        "--persist",
        default="mp_sim_data.json",
        help="Archivo JSON de persistencia simple (default: mp_sim_data.json). Usar '' para no persistir.",
    )
    args = parser.parse_args()

    persist = args.persist if args.persist.strip() else None
    run_server(args.host, args.port, persist)


if __name__ == "__main__":
    main()
