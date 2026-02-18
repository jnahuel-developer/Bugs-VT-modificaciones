#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Simulador TCP de "máquina/terminal" para pruebas locales.

Propósito
---------
Este proceso escucha en un puerto TCP (por defecto 127.0.0.1:13000) y actúa como
receptor del crédito que envía la aplicación.

Según el código actual, la aplicación envía un mensaje ASCII con el formato:

    $<MercadoPagoId>,<MaquinaId>,<MontoEnCentavos>!

Luego intenta leer hasta 100 bytes de respuesta, pero NO valida su contenido.
Por lo tanto, este simulador devuelve un "OK" (ASCII) para destrabar el flujo.

Características
---------------
- Acepta múltiples conexiones (servidor multihilo).
- Imprime por consola lo recibido (payload crudo y parseado).
- Responde inmediatamente con un ACK configurable (por defecto: "OK").
- Cierra la conexión luego de responder (la app también cierra).

Uso
---
1) Asegurar que la app apunte al host/puerto correctos (defaults: 127.0.0.1 / 13000).
2) Ejecutar:
       python maquina_simulator.py
   o:
       python maquina_simulator.py --host 127.0.0.1 --port 13000

3) Disparar un pago en la app y observar en consola el mensaje recibido.

Notas
-----
- Si se desea simular "falla de máquina", puede ejecutarse con --no-reply
  para que el cliente quede esperando lectura y eventualmente reintente.
"""

from __future__ import annotations

import argparse
import socketserver
import sys
from datetime import datetime, timezone


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def try_parse_payload(text: str) -> dict:
    """
    Intenta parsear el protocolo esperado:
        $mpId,maquinaId,montoCentavos!
    Devuelve dict con campos parseados o con error.
    """
    raw = text.strip()
    if not raw:
        return {"ok": False, "error": "payload vacío"}

    if raw[0] != "$" or "!" not in raw:
        return {"ok": False, "error": "formato inesperado (se esperaba prefijo '$' y sufijo '!')", "raw": raw}

    # Tomar contenido entre $ y !
    core = raw[1: raw.index("!")]
    parts = core.split(",")
    if len(parts) != 3:
        return {"ok": False, "error": f"cantidad de campos inesperada: {len(parts)} (se esperaban 3)", "raw": raw}

    mp_id = parts[0].strip()
    maquina_id = parts[1].strip()
    monto_cent = parts[2].strip()

    # Conversión best-effort
    mp_id_i = None
    monto_cent_i = None
    try:
        mp_id_i = int(mp_id)
    except Exception:
        pass

    try:
        monto_cent_i = int(monto_cent)
    except Exception:
        pass

    monto_pesos = None
    if monto_cent_i is not None:
        monto_pesos = monto_cent_i / 100.0

    return {
        "ok": True,
        "mp_id_raw": mp_id,
        "mp_id": mp_id_i,
        "maquina_id": maquina_id,
        "monto_centavos_raw": monto_cent,
        "monto_centavos": monto_cent_i,
        "monto_pesos": monto_pesos,
    }


class MachineTCPHandler(socketserver.BaseRequestHandler):
    """
    Handler por conexión.
    Lee hasta ver '!' o hasta timeout/cierre.
    """

    def handle(self) -> None:
        server: "MachineTCPServer" = self.server  # type: ignore
        peer = f"{self.client_address[0]}:{self.client_address[1]}"

        self.request.settimeout(server.read_timeout)

        data = b""
        try:
            while True:
                chunk = self.request.recv(4096)
                if not chunk:
                    break
                data += chunk
                if b"!" in data:
                    break
        except Exception as ex:
            print(f"[{utc_now_iso()}] {peer} - ERROR leyendo socket: {ex}", file=sys.stderr)

        # Decodificar en ASCII (la app manda ASCIIEncoding)
        try:
            text = data.decode("ascii", errors="replace")
        except Exception:
            text = repr(data)

        print(f"[{utc_now_iso()}] {peer} - RX (raw bytes): {data!r}")
        print(f"[{utc_now_iso()}] {peer} - RX (ascii): {text}")

        parsed = try_parse_payload(text)
        if parsed.get("ok"):
            mpid = parsed.get("mp_id", parsed.get("mp_id_raw"))
            maq = parsed.get("maquina_id")
            cent = parsed.get("monto_centavos", parsed.get("monto_centavos_raw"))
            pesos = parsed.get("monto_pesos")
            if pesos is not None:
                print(f"[{utc_now_iso()}] {peer} - PARSE OK -> mp_id={mpid} maquina_id={maq} monto={cent} centavos ({pesos:.2f})")
            else:
                print(f"[{utc_now_iso()}] {peer} - PARSE OK -> mp_id={mpid} maquina_id={maq} monto_centavos={cent}")
        else:
            print(f"[{utc_now_iso()}] {peer} - PARSE FAIL -> {parsed}")

        # Responder ACK si corresponde
        if not server.no_reply:
            try:
                self.request.sendall(server.ack_bytes)
                print(f"[{utc_now_iso()}] {peer} - TX (ack): {server.ack_bytes!r}")
            except Exception as ex:
                print(f"[{utc_now_iso()}] {peer} - ERROR enviando ACK: {ex}", file=sys.stderr)


class MachineTCPServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True

    def __init__(
        self,
        server_address,
        handler_class,
        *,
        ack_bytes: bytes,
        read_timeout: float,
        no_reply: bool,
    ):
        super().__init__(server_address, handler_class)
        self.ack_bytes = ack_bytes
        self.read_timeout = read_timeout
        self.no_reply = no_reply


def main() -> None:
    parser = argparse.ArgumentParser(description="Simulador TCP de máquina/terminal (receptor de crédito).")
    parser.add_argument("--host", default="127.0.0.1", help="Host de escucha (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=13000, help="Puerto de escucha (default: 13000)")
    parser.add_argument("--ack", default="OK", help="Respuesta ASCII a enviar (default: OK)")
    parser.add_argument("--read-timeout", type=float, default=10.0, help="Timeout de lectura por conexión en segundos (default: 10)")
    parser.add_argument("--no-reply", action="store_true", help="No enviar respuesta (para simular fallas y reintentos).")
    args = parser.parse_args()

    ack_bytes = args.ack.encode("ascii", errors="replace")

    server = MachineTCPServer(
        (args.host, args.port),
        MachineTCPHandler,
        ack_bytes=ack_bytes,
        read_timeout=args.read_timeout,
        no_reply=args.no_reply,
    )

    print(f"[{utc_now_iso()}] Simulador de máquina escuchando en tcp://{args.host}:{args.port}")
    print(f"[{utc_now_iso()}] ACK configurado: {ack_bytes!r} | no_reply={args.no_reply} | read_timeout={args.read_timeout}s")
    print("CTRL+C para salir.\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\n[{utc_now_iso()}] Saliendo...")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
