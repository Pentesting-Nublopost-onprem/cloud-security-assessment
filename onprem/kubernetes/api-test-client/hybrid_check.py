#!/usr/bin/env python3
"""Prueba de la conexión híbrida on-prem -> Azure (VAmPI en Container Apps).

Comprueba, desde el pod api-test-client: resolución DNS, conexión TCP 443,
certificado TLS, que HTTP no se sirve en claro, la API y la autenticación.

Lee del entorno (Secret de Kubernetes): VAMPI_URL, VAMPI_USER, VAMPI_PASSWORD
y VAMPI_EMAIL. Nunca imprime la contraseña ni el token.

Uso:
  python /app/hybrid_check.py          # pruebas
  python /app/hybrid_check.py --init   # antes, reinicia la base de datos de VAmPI
                                       # (se pierde cada vez que escala a cero)
"""

import json
import os
import socket
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

TIMEOUT = 45  # segundos; el primer acceso arranca la réplica (cold start)
results = []


def record(name, ok, detail):
    results.append((name, ok))
    print(f"[{'OK   ' if ok else 'FALLO'}] {name}: {detail}", flush=True)


def env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"Falta la variable {name}: revisa el fichero .env y el Secret vampi-credentials")
    return value


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def request(method, url, body=None, token=None, follow=True):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    opener = urllib.request.build_opener() if follow else urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(req, timeout=TIMEOUT) as resp:
            return resp.status, resp.headers, resp.read().decode(errors="replace")
    except urllib.error.HTTPError as err:
        return err.code, err.headers, err.read().decode(errors="replace")


def as_json(text):
    try:
        return json.loads(text)
    except ValueError:
        return {}


def main():
    init_db = "--init" in sys.argv[1:]
    base = env("VAMPI_URL").rstrip("/")
    user, password, email = env("VAMPI_USER"), env("VAMPI_PASSWORD"), env("VAMPI_EMAIL")
    parsed = urllib.parse.urlparse(base)
    host = parsed.hostname
    if parsed.scheme != "https" or not host:
        sys.exit("VAMPI_URL debe empezar por https://")

    started = datetime.now(timezone.utc)
    print(f"Conexión híbrida on-prem -> Azure | {started:%Y-%m-%d %H:%M:%S} UTC | destino {host}\n")

    # 1. DNS
    try:
        addrs = sorted({info[4][0] for info in socket.getaddrinfo(host, 443, proto=socket.IPPROTO_TCP)})
        record("DNS", True, ", ".join(addrs))
    except socket.gaierror as err:
        record("DNS", False, err)
        return summary()

    # 2. TCP 443
    try:
        t0 = time.monotonic()
        with socket.create_connection((host, 443), timeout=TIMEOUT):
            record("TCP 443", True, f"conexión en {(time.monotonic() - t0) * 1000:.0f} ms")
    except OSError as err:
        record("TCP 443", False, err)
        return summary()

    # 3. TLS: certificado válido para el nombre y protocolo moderno
    try:
        ctx = ssl.create_default_context()
        with socket.create_connection((host, 443), timeout=TIMEOUT) as raw:
            with ctx.wrap_socket(raw, server_hostname=host) as tls:
                cert = tls.getpeercert()
                issuer = dict(item[0] for item in cert["issuer"]).get("organizationName", "?")
                record("TLS", True, f"{tls.version()}, emisor {issuer}, caduca {cert['notAfter']}")
    except (ssl.SSLError, OSError) as err:
        record("TLS", False, err)

    # 4. HTTP en claro: no debe servir contenido
    try:
        status, headers, _ = request("GET", f"http://{host}/", follow=False)
        location = headers.get("Location", "") if headers else ""
        ok = status in (301, 302, 307, 308) and location.startswith("https://")
        record("Solo HTTPS", ok, f"HTTP {status} -> {location or 'sin redirección'}")
    except (urllib.error.URLError, OSError) as err:
        record("Solo HTTPS", True, f"puerto 80 cerrado ({err})")

    try:
        api_checks(base, user, password, email, init_db)
    except (urllib.error.URLError, OSError) as err:
        record("API", False, err)
    return summary()


def api_checks(base, user, password, email, init_db):
    # 5. API accesible desde la IP del laboratorio (la primera petición arranca la réplica)
    for _ in range(3):
        status, _, body = request("GET", f"{base}/")
        if status not in (502, 503, 504):
            break
        time.sleep(10)
    if status == 403:
        record("API", False, "403: la IP pública no está permitida (¿ha cambiado? actualiza allowed_ip)")
        return
    record("API", status == 200, f"HTTP {status} {as_json(body).get('message', '')}".strip())

    if init_db:
        status, _, _ = request("GET", f"{base}/createdb")
        record("Base de datos", status == 200, f"/createdb -> HTTP {status}")

    # 6. Autenticación
    status, _, body = request("POST", f"{base}/users/v1/register",
                              {"username": user, "password": password, "email": email})
    detail = as_json(body).get("message", f"HTTP {status}")
    if status >= 500:
        detail += " (¿base de datos sin inicializar? repite con --init)"
    record("Usuario de prueba", status == 200, detail)

    status, _, body = request("POST", f"{base}/users/v1/login", {"username": user, "password": password})
    token = as_json(body).get("auth_token")
    record("Login", bool(token), "token recibido" if token else as_json(body).get("message", f"HTTP {status}"))

    status, _, _ = request("GET", f"{base}/me")
    record("Sin token -> 401", status == 401, f"HTTP {status}")

    if token:
        status, _, body = request("GET", f"{base}/me", token=token)
        record("Con token -> /me", status == 200 and user in body, f"HTTP {status}")


def summary():
    failed = [name for name, ok in results if not ok]
    print(f"\nResultado: {len(results) - len(failed)}/{len(results)} pruebas superadas")
    if failed:
        print("Fallan: " + ", ".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
