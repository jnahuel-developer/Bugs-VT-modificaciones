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
        payload = {
            "id": self.id,
            "status": self.status,
            "status_detail": "accredited" if self.status == "approved" else "pending",
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
        except FileNotFoundError:
            return

    def save(self) -> None:
        if not self.persist_path:
            return
        data = {"payments": {str(pid): asdict(rec) for pid, rec in self.payments.items()}}
        with open(self.persist_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def reset(self) -> None:
        self.payments = {}
        self.save()

    def upsert(self, rec: PaymentRecord) -> None:
        self.payments[rec.id] = rec
        self.save()

    def list_all(self) -> Dict[int, PaymentRecord]:
        return dict(self.payments)

    def get(self, pid: int) -> Optional[PaymentRecord]:
        return self.payments.get(pid)


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

        # Payments endpoints
        pid = self._extract_payment_id(path)
        if pid is not None:
            with _LOCK:
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

        # Reset
        if path == "/__admin/reset":
            with _LOCK:
                STORE.reset()
            return json_response(self, 200, {"ok": True, "message": "reset done"})

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

    def _scenario_mixed(self, body: Dict[str, Any], ok: bool) -> None:
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
            status="approved",
            transaction_amount=a2,
            external_reference=ext,
            payment_method_id=m2,
            status_sequence=["approved"],
        )

        with _LOCK:
            STORE.upsert(rec1)
            STORE.upsert(rec2)

        return json_response(
            self,
            200,
            {
                "ok": True,
                "scenario": "mixed_ok" if ok else "mixed_fail",
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
    print("  POST /__admin/payments")
    print("  POST /__admin/reset")
    print("  POST /__admin/scenarios/simple")
    print("  POST /__admin/scenarios/mixed_ok")
    print("  POST /__admin/scenarios/mixed_fail")
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
