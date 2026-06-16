#!/usr/bin/env python3
"""
Backend de conexión a Strava (sin dependencias externas, solo Python estándar).

Completa la conexión que empieza el usuario en la web (web/conectar.html):
  1. Canjea el "código" de autorización por un token de acceso.
  2. Baja las actividades reales del usuario desde la API de Strava.
  3. Las guarda (limpias, sin datos sensibles) en verificador/actividades_strava.json.
  4. Corre el verificador para decidir si la meta se cumplió.

Por qué un backend: el canje del código necesita el CLIENT_SECRET, que NO puede
estar en el navegador (se filtraría). Por eso vive acá, leído desde backend/.env.

USO:
  # Opción A — recién autorizaste en la web, pegá la URL de retorno completa:
  python3 backend/conectar_strava.py "http://localhost:8000/conectar.html?code=ABC123&scope=read,activity:read_all"

  # Opción B — ya conectaste antes (hay refresh token en .env), solo refresca y baja:
  python3 backend/conectar_strava.py

REQUISITOS (para conectarse de verdad):
  Registrar una app gratis en https://www.strava.com/settings/api y poner en backend/.env:
    STRAVA_CLIENT_ID=...
    STRAVA_CLIENT_SECRET=...
  (ver backend/.env.example)
"""

import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ENV = Path(__file__).resolve().parent / ".env"
DESTINO = RAIZ / "verificador" / "actividades_strava.json"
VERIFICADOR = RAIZ / "verificador" / "verificar.py"

TOKEN_URL = "https://www.strava.com/oauth/token"
API = "https://www.strava.com/api/v3"

# Campos que conservamos (sin GPS, ubicación ni ID de atleta).
CAMPOS = ["id", "name", "type", "sport_type", "distance", "moving_time",
          "elapsed_time", "total_elevation_gain", "average_speed",
          "average_heartrate", "start_date_local"]


def cargar_env() -> dict:
    """Lee backend/.env como diccionario simple KEY=VALUE."""
    env = {}
    if ENV.exists():
        for linea in ENV.read_text().splitlines():
            linea = linea.strip()
            if not linea or linea.startswith("#") or "=" not in linea:
                continue
            k, v = linea.split("=", 1)
            env[k.strip()] = v.strip()
    return env


def guardar_env(clave: str, valor: str) -> None:
    """Reemplaza o agrega una línea KEY=... en backend/.env."""
    patron = re.compile(rf"^{clave}=.*$", re.MULTILINE)
    cuerpo = ENV.read_text() if ENV.exists() else ""
    if patron.search(cuerpo):
        cuerpo = patron.sub(f"{clave}={valor}", cuerpo)
    else:
        if cuerpo and not cuerpo.endswith("\n"):
            cuerpo += "\n"
        cuerpo += f"{clave}={valor}\n"
    ENV.write_text(cuerpo)


def post(url: str, datos: dict) -> dict:
    """POST con datos de formulario; devuelve el JSON de respuesta."""
    body = urllib.parse.urlencode(datos).encode()
    req = urllib.request.Request(url, data=body, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        print(f"✗ Error HTTP {e.code} en {url}: {e.read().decode()[:300]}", file=sys.stderr)
        sys.exit(1)


def get(url: str, token: str) -> list:
    """GET autenticado con Bearer token; devuelve el JSON."""
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        print(f"✗ Error HTTP {e.code} en {url}: {e.read().decode()[:300]}", file=sys.stderr)
        sys.exit(1)


def obtener_access_token(env: dict) -> str:
    """Consigue un access_token: canjea el código (si vino una URL) o refresca."""
    cid = env.get("STRAVA_CLIENT_ID", "")
    secret = env.get("STRAVA_CLIENT_SECRET", "")
    if not cid or not secret:
        print("✗ Falta STRAVA_CLIENT_ID / STRAVA_CLIENT_SECRET en backend/.env", file=sys.stderr)
        print("  Registrá una app en https://www.strava.com/settings/api (ver backend/.env.example)", file=sys.stderr)
        sys.exit(1)

    # ¿Vino una URL de retorno con ?code=... ?
    if len(sys.argv) > 1 and "code=" in sys.argv[1]:
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(sys.argv[1]).query)
        code = qs.get("code", [None])[0]
        print(f"→ Canjeando código ({code[:8]}…) por tokens…")
        data = post(TOKEN_URL, {
            "client_id": cid, "client_secret": secret,
            "code": code, "grant_type": "authorization_code",
        })
        guardar_env("STRAVA_REFRESH_TOKEN", data["refresh_token"])
        print("✓ Conectado. Refresh token guardado en backend/.env")
        return data["access_token"]

    # Si no, usamos el refresh token guardado
    refresh = env.get("STRAVA_REFRESH_TOKEN", "")
    if refresh:
        print("→ Refrescando token con el refresh token guardado…")
        data = post(TOKEN_URL, {
            "client_id": cid, "client_secret": secret,
            "refresh_token": refresh, "grant_type": "refresh_token",
        })
        return data["access_token"]

    print("✗ No hay código ni refresh token.", file=sys.stderr)
    print("  Primero conectate en la web (web/conectar.html) y pegá acá la URL de retorno:", file=sys.stderr)
    print('  python3 backend/conectar_strava.py "http://localhost:8000/conectar.html?code=..."', file=sys.stderr)
    sys.exit(1)


def main() -> None:
    env = cargar_env()
    token = obtener_access_token(env)

    print("→ Bajando tus actividades desde Strava…")
    actividades = get(f"{API}/athlete/activities?per_page=30", token)

    limpias = [{k: a.get(k) for k in CAMPOS if k in a} for a in actividades]
    DESTINO.write_text(json.dumps(limpias, ensure_ascii=False, indent=2))
    print(f"✓ Guardadas {len(limpias)} actividades (limpias) en {DESTINO.relative_to(RAIZ)}")

    print("\n→ Corriendo el verificador sobre tus datos reales…\n")
    subprocess.run([sys.executable, str(VERIFICADOR)])


if __name__ == "__main__":
    main()
