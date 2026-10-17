#!/usr/bin/env python3
"""Imprime qa.url o qa.puerto de .city.json con sus variables expandidas.

    python3 qa.py url|puerto

Un valor de qa puede nombrar variables del entorno como ${VAR} o
${VAR:-valor}: goal.sh exporta las del slot del lab (CITY_SLOT, CITY_HTTP_PORT,
CITY_MAILPIT_PORT y CITY_BASE_DOMAIN) y, sin slot, vale lo que va después de
:-. Solo eso: ni comandos ni otras formas de $. url sale con el puerto de
qa.puerto si no trae uno. Sale con 1 si falta la clave, una variable no tiene
valor ni valor por omisión, o el puerto no es un número de 1 a 65535.
qa.instalar no pasa por aquí: lo corre la shell, que expande las mismas formas.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

VARIABLE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-([^${}]*))?\}")


def expande(valor):
    def una(m):
        actual = os.environ.get(m.group(1), "")
        if actual:
            return actual
        if m.group(2) is None:
            raise ValueError(f"{m.group(1)} no tiene valor ni valor por omisión")
        return m.group(2)

    salida = VARIABLE.sub(una, str(valor))
    if "$" in VARIABLE.sub("", str(valor)):
        raise ValueError(f"solo se expanden ${{VAR}} y ${{VAR:-valor}}: {valor!r}")
    return salida


def qa():
    git = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    cfg = Path(git.stdout.strip() or ".") / ".city.json"
    if not cfg.is_file():
        raise ValueError("no hay .city.json en la raíz del repo")
    return json.loads(cfg.read_text(encoding="utf-8")).get("qa", {})


def puerto(cfg):
    if "puerto" not in cfg:
        return None
    p = expande(cfg["puerto"])
    if not p.isdigit() or not 1 <= int(p) <= 65535:
        raise ValueError(f"qa.puerto no es un puerto: {p!r}")
    return int(p)


def url(cfg):
    if not cfg.get("url"):
        raise ValueError("qa.url falta en .city.json")
    u = expande(cfg["url"])
    p = puerto(cfg)
    partes = urlsplit(u)
    if p is not None and partes.hostname and partes.port is None:
        u = urlunsplit(partes._replace(netloc=f"{partes.netloc}:{p}"))
    return u


if __name__ == "__main__":
    clave = sys.argv[1] if len(sys.argv) > 1 else ""
    if clave not in ("url", "puerto"):
        print("uso: qa.py url|puerto", file=sys.stderr)
        sys.exit(2)
    try:
        cfg = qa()
        valor = url(cfg) if clave == "url" else puerto(cfg)
    except ValueError as e:
        print(f"qa: {e}", file=sys.stderr)
        sys.exit(1)
    if valor is None:
        print("qa: qa.puerto falta en .city.json", file=sys.stderr)
        sys.exit(1)
    print(valor)
