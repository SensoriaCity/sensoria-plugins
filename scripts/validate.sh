#!/usr/bin/env bash
# Valida el kit antes de publicar un cambio. Compatible con el bash 3.2 de macOS.
set -uo pipefail
cd "$(dirname "$0")/.."

CITY=plugins/city
fail=0
err() { echo "  ✗ $1"; fail=1; }

echo "1/10 claude plugin validate --strict (marketplace)"
claude plugin validate --strict . || fail=1

echo "2/10 claude plugin validate --strict (plugin y skills)"
claude plugin validate --strict "$CITY" || fail=1
claude plugin validate --strict "$CITY/skills" || fail=1

echo "3/10 frontmatter y tamaño de skills y agentes"
for f in "$CITY"/skills/*/SKILL.md "$CITY"/agents/*.md; do
  [ -f "$f" ] || continue
  [ "$(head -1 "$f")" = "---" ] || err "sin frontmatter: $f"
  grep -q '^name: ' "$f" || err "sin name: $f"
  grep -q '^description: ' "$f" || err "sin description: $f"
  n=$(wc -l < "$f" | tr -d ' ')
  [ "$n" -le 120 ] || err "más de 120 líneas ($n): $f"
done
# review corre en CI sin persona: es la única que el modelo puede invocar, y es corta.
R="$CITY/skills/review/SKILL.md"
for f in "$CITY"/skills/*/SKILL.md; do
  if [ "$f" = "$R" ]; then
    grep -q '^disable-model-invocation:' "$f" && err "review corre en CI: no lleva disable-model-invocation"
    n=$(wc -l < "$f" | tr -d ' ')
    [ "$n" -le 60 ] || err "review pasa de 60 líneas ($n)"
  else
    grep -q '^disable-model-invocation: true' "$f" || err "falta disable-model-invocation: true en $f"
  fi
  grep -q '^argument-hint: ' "$f" || err "falta argument-hint en $f"
done
n=$(wc -l < "$CITY/skills/goal/SKILL.md" 2>/dev/null | tr -d ' ')
[ "${n:-0}" -gt 0 ] && [ "$n" -le 60 ] || err "goal falta o pasa de 60 líneas (${n:-0})"
if [ -f "$R" ]; then
  grep -o 'gh pr view [^`]*' "$R" | grep -qv -- '--json headRefName,baseRefName,title$' && err "review lee del PR más que rama, base y título"
  grep -qF '<id> · origin/<head> · origin/<base>' "$R" || err "review no delega con una sola línea id · rama · base"
else
  err "falta la skill review"
fi
for f in "$CITY"/agents/*.md; do
  [ -f "$f" ] || continue
  grep -qE '^tools: ' "$f" || err "sin lista de tools (heredaría las de edición): $f"
  if grep -E '^tools:' "$f" | grep -qE 'Edit|Write|MultiEdit|NotebookEdit'; then
    err "tiene herramientas de edición: $f"
  fi
done
for f in "$CITY"/agents/*.md; do
  grep -qx 'model: inherit' "$f" || err "falta model: inherit en $f"
done

echo "4/10 archivos referenciados con \${CLAUDE_SKILL_DIR} y \${CLAUDE_PLUGIN_ROOT}"
for f in "$CITY"/skills/*/SKILL.md; do
  d=$(dirname "$f")
  for ref in $(grep -oE '\$\{CLAUDE_SKILL_DIR\}/[A-Za-z0-9._/-]+' "$f" | sed 's|^\${CLAUDE_SKILL_DIR}/||' | sort -u); do
    [ -f "$d/$ref" ] || err "no existe $d/$ref (referenciado en $f)"
  done
done
for f in "$CITY"/skills/*/SKILL.md "$CITY"/agents/*.md; do
  [ -f "$f" ] || continue
  P=$CITY
  for ref in $(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$f" | sed 's|^\${CLAUDE_PLUGIN_ROOT}/||' | sort -u); do
    [ -f "$P/$ref" ] || err "no existe $P/$ref (referenciado en $f)"
  done
done

echo "5/10 .mcp.json y herramientas del evaluador"
python3 - "$CITY" evaluator <<'PY' || fail=1
import json, re, sys
plugin, agente = sys.argv[1], sys.argv[2]
cfg = json.load(open(f"{plugin}/.mcp.json"))["mcpServers"]
nombre = json.load(open(f"{plugin}/.claude-plugin/plugin.json"))["name"]
ok = True
def mal(m):
    global ok
    print(f"  ✗ {m}"); ok = False
if "playwright" not in cfg:
    mal("falta el servidor playwright en .mcp.json")
else:
    args = " ".join(cfg["playwright"].get("args", []))
    version = re.search(r"@playwright/mcp@(\d+\.\d+\.\d+)", args)
    if not version:
        mal("la versión de @playwright/mcp no está fija")
    salida = cfg["playwright"]["args"]
    salida = salida[salida.index("--output-dir") + 1] if "--output-dir" in salida[:-1] else ""
    if not salida or "CLAUDE_PROJECT_DIR" in salida:
        mal("@playwright/mcp necesita --output-dir fuera del repo")
    elif "${CITY_SLOT:-" not in salida:
        mal("--output-dir de @playwright/mcp va por slot del lab, con ${CITY_SLOT:-…}")
    elif salida not in open(f"{plugin}/agents/{agente}.md").read():
        mal(f"{agente} no nombra la carpeta de Playwright de .mcp.json: {salida}")
# Herramientas de cada versión fija de @playwright/mcp (tools/list). Al subir
# la versión, agrega su lista aquí.
EXISTEN = {
    "0.0.83": set("""browser_click browser_close browser_console_messages browser_drag browser_drop
        browser_emulate_media browser_evaluate browser_file_upload browser_fill_form browser_find
        browser_handle_dialog browser_hover browser_navigate browser_navigate_back
        browser_network_request browser_network_requests browser_press_key browser_resize
        browser_run_code_unsafe browser_select_option browser_snapshot browser_tabs
        browser_take_screenshot browser_type browser_wait_for""".split()),
}
linea = next((l for l in open(f"{plugin}/agents/{agente}.md") if l.startswith("tools:")), "")
tools = [t.strip() for t in linea[len("tools:"):].split(",") if t.strip()]
prefijo = f"mcp__plugin_{nombre}_playwright__"
existen = EXISTEN.get(version.group(1)) if "playwright" in cfg and version else None
if "playwright" in cfg and version and existen is None:
    mal(f"validate.sh no conoce las herramientas de @playwright/mcp@{version.group(1)}")
for t in tools:
    if not t.startswith("mcp__"):
        continue
    if not t.startswith(prefijo):
        mal(f"{agente}: {t} no es de un servidor de {plugin}/.mcp.json")
    elif "*" in t:
        mal(f"{agente} no debe tener comodines: {t}")
    elif existen is not None and t[len(prefijo):] not in existen:
        mal(f"{agente}: {t} no existe en @playwright/mcp@{version.group(1)}")
for necesaria in ("browser_navigate", "browser_snapshot", "browser_take_screenshot"):
    if prefijo + necesaria not in tools:
        mal(f"{agente} no tiene {prefijo}{necesaria}")
for t in tools:
    if t.endswith("browser_run_code_unsafe") or t.endswith("browser_evaluate") or t == prefijo.rstrip("_"):
        mal(f"{agente} no debe tener {t}")
sys.exit(0 if ok else 1)
PY

echo "6/10 versión del plugin registrada en CHANGELOG.md"
v=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$CITY/.claude-plugin/plugin.json")
grep -q "^## city $v " CHANGELOG.md || err "CHANGELOG.md no tiene entrada para city $v"

echo "7/10 el kit no sabe nada del stack"
for f in "$CITY"/skills/*/SKILL.md "$CITY"/agents/*.md; do
  grep -q '\.city\.json' "$f" || err "no lee .city.json: $f"
done
for a in reviewer evaluator security; do [ -f "$CITY/agents/$a.md" ] || err "falta el agente $a"; done
if grep -rn 'php84\|pnpm -C web\|bin/city\|8080' "$CITY/skills" "$CITY/agents"; then err "stack en duro en $CITY"; fi
if grep -rn 'diff --shortstat' "$CITY/skills" "$CITY/agents"; then err "el tamaño se mide solo con scripts/size.sh"; fi
for f in "$CITY/skills/build/SKILL.md" "$CITY/skills/ship/SKILL.md"; do
  grep -qF 'bash "${CLAUDE_PLUGIN_ROOT}/scripts/size.sh"' "$f" || err "no llama a scripts/size.sh: $f"
done
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$CITY/city.schema.json" || err "city.schema.json no es JSON"

echo "8/10 size.sh, passes.sh, slice.sh, check-spec.sh, owners.sh, qa.py y qa-env.py en un repo de prueba"
T="$(pwd)/$CITY/scripts/size.sh"
bash -n "$T" || err "size.sh no compila"
tmp=$(mktemp -d)
(
  cd "$tmp" && git init -q && git checkout -q -b main \
    && git -c user.name=v -c user.email=v@v commit -q --allow-empty -m base \
    && git checkout -q -b city/prueba && mkdir -p ev \
    && printf 'a\nb\nc\n' > a.txt && printf 'x\n' > composer.lock && printf 'e\n' > ev/S1.md \
    && git add . && git -c user.name=v -c user.email=v@v commit -q -m corte
) || err "no pude armar el repo de prueba"
[ "$(cd "$tmp" && bash "$T" 2>/dev/null)" = "Tamaño: 4 líneas contra main (tope 400)" ] || err "sin .city.json debería contar 4 líneas contra main"
printf '{"line_limit": 3, "evidence_dir": "ev/"}\n' > "$tmp/.city.json"
(cd "$tmp/ev" && bash "$T" >/dev/null 2>&1) || err "con evidence_dir fuera, 3 líneas caben en tope 3"
printf '{"line_limit": 2, "evidence_dir": "ev"}\n' > "$tmp/.city.json"
(cd "$tmp" && bash "$T" >/dev/null 2>&1); [ $? -eq 1 ] || err "3 líneas deberían pasar el tope 2 y salir con 1"
printf '{"tope_lineas": 2, "evidencia_dir": "ev"}\n' > "$tmp/.city.json"
(cd "$tmp" && bash "$T" >/dev/null 2>&1); [ $? -eq 1 ] || err "con tope_lineas y evidencia_dir (claves de city 2.x) debería medir igual y salir con 1"
(cd / && bash "$T" >/dev/null 2>&1); [ $? -eq 2 ] || err "fuera de un repo git debería salir con 2"
# --ref mide otra rama sin cambiar de rama, con el .city.json de esa rama (aquí no tiene: tope 400).
(cd "$tmp" && git checkout -q main) || err "no pude volver a main en el repo de prueba"
[ "$(cd "$tmp" && bash "$T" main --ref city/prueba 2>/dev/null)" = "Tamaño: 4 líneas de city/prueba contra main (tope 400)" ] || err "size.sh --ref debería medir city/prueba desde main"
[ "$(cd "$tmp" && bash "$T" 2>/dev/null)" = "Tamaño: 0 líneas contra main (tope 2)" ] || err "size.sh sin --ref debería seguir midiendo HEAD"
(cd "$tmp" && bash "$T" --ref no-existe >/dev/null 2>&1); [ $? -eq 2 ] || err "size.sh --ref con una rama que no existe debería salir con 2"
(cd "$tmp" && bash "$T" --ref >/dev/null 2>&1); [ $? -eq 2 ] || err "size.sh --ref sin rama debería salir con 2"
(cd "$tmp" && git checkout -q city/prueba) || err "no pude volver a city/prueba en el repo de prueba"
# --help muestra el uso; y un corte apilado se mide contra la rama del corte de abajo, no contra main.
(cd "$tmp" && bash "$T" --help 2>/dev/null) | grep -q '^Uso: size.sh \[base\] \[--ref <commit>\]' || err "size.sh --help debería mostrar el uso"
(cd "$tmp" && bash "$T" --help >/dev/null 2>&1) || err "size.sh --help debería salir con 0"
(cd "$tmp" && bash "$T" --no-existe >/dev/null 2>&1); [ $? -eq 2 ] || err "size.sh con una opción desconocida debería salir con 2"
(
  cd "$tmp" && git checkout -q -b city/arriba && printf 'd\ne\n' > b.txt && git add b.txt \
    && git -c user.name=v -c user.email=v@v commit -q -m "corte apilado"
) || err "no pude armar la rama apilada del repo de prueba"
[ "$(cd "$tmp" && bash "$T" 2>/dev/null)" = "Tamaño: 5 líneas contra main (tope 2)" ] || err "size.sh sin base, en una rama apilada, cuenta también el corte de abajo (5 líneas)"
[ "$(cd "$tmp" && bash "$T" city/prueba 2>/dev/null)" = "Tamaño: 2 líneas contra city/prueba (tope 2)" ] || err "size.sh <base> en una rama apilada debería contar solo el corte de arriba (2 líneas)"
(cd "$tmp" && bash "$T" city/prueba >/dev/null 2>&1) || err "size.sh <base> en una rama apilada debería caber en el tope"
(cd "$tmp" && git checkout -q city/prueba && git branch -q -D city/arriba) || err "no pude volver a city/prueba desde la rama apilada"

# passes.sh, con cada bash que haya en la máquina (el 3.2 de macOS y el de PATH).
S="$(pwd)/$CITY/scripts/passes.sh"
bashes=$( { echo /bin/bash; command -v bash; ls /opt/homebrew/bin/bash /usr/local/bin/bash 2>/dev/null; } | sort -u)
ciudad() { printf '{"features": "%s", "evidence_dir": "ev"}\n' "$1" > "$tmp/.city.json"; }
mkdir -p "$tmp/f.orig"
printf '{\n  "id": "S1",\n  "steps": [\n    "a"\n  ],\n  "passes": false\n}\n' > "$tmp/f.orig/S1.json"
printf '{\n  "id": "S2",\n  "passes": false\n}\n' > "$tmp/f.orig/S2.json"
printf '[{"id": "S2", "passes": false}]\n' > "$tmp/viejo.json"
cabecera='# Evidencia · S2 · 2026-10-03 · abc1234\n\n| Paso | Qué hizo | Resultado |\n|---|---|---|\n| 1 | … | cumple |\n\n## Hallazgos\nNinguno.\n\n'
passes() { (cd "$tmp" && "$B" "$S" "$@" >/dev/null 2>&1); }
for B in $bashes; do
  v=$("$B" -c 'echo $BASH_VERSION')
  "$B" -n "$S" || err "passes.sh no compila con bash $v"
  ciudad f; rm -rf "$tmp/f"; cp -R "$tmp/f.orig" "$tmp/f"; rm -f "$tmp/ev/S2.md" "$tmp/ev/S4.md"
  passes S2 && err "bash $v: passes.sh sin evidencia debería fallar"
  printf "$cabecera" > "$tmp/ev/S2.md"
  passes S2 && err "bash $v: passes.sh con un reporte sin veredicto debería fallar"
  printf "${cabecera}VEREDICTO: no pasa\n" > "$tmp/ev/S2.md"
  passes S2 && err "bash $v: passes.sh con VEREDICTO: no pasa debería fallar"
  printf "$(echo "$cabecera" | sed 's/S2/S1/')VEREDICTO: pasa\n" > "$tmp/ev/S2.md"
  passes S2 && err "bash $v: passes.sh con un reporte de otro id debería fallar"
  printf "${cabecera}VEREDICTO: pasa\n" > "$tmp/ev/S2.md"
  ciudad viejo.json
  passes S2 && err "bash $v: passes.sh con features en un solo archivo debería fallar"
  ciudad f
  cp "$tmp/f.orig/S1.json" "$tmp/f/S4.json"; cp "$tmp/f.orig/S1.json" "$tmp/f.orig/S4.json"
  printf "$(echo "$cabecera" | sed 's/S2/S4/')VEREDICTO: pasa\n" > "$tmp/ev/S4.md"
  passes S4 && err "bash $v: passes.sh con un archivo cuyo id no es su nombre debería fallar"
  diff -r "$tmp/f" "$tmp/f.orig" >/dev/null || err "bash $v: passes.sh no debería tocar features cuando falla"
  passes S2 || err "bash $v: passes.sh con un reporte correcto debería cambiar S2"
  [ "$(diff "$tmp/f.orig/S2.json" "$tmp/f/S2.json" | grep -c '^[<>]')" -eq 2 ] || err "bash $v: passes.sh debería cambiar una sola línea"
  [ "$(jq -r .passes "$tmp/f/S2.json")" = true ] || err "bash $v: passes.sh debería dejar S2 en true"
  cmp -s "$tmp/f/S1.json" "$tmp/f.orig/S1.json" || err "bash $v: passes.sh debería cambiar S2 y no S1"
  passes S2 || err "bash $v: passes.sh sobre un passes ya en true debería salir con 0"
  passes S3 && err "bash $v: passes.sh con un id que no está en features debería fallar"
  printf '{"id": "S2", "passes": false}\n' > "$tmp/f/S2.json"
  cp "$tmp/f/S2.json" "$tmp/S2.compacto"
  passes S2 && err "bash $v: passes.sh no debería reformatear una funcionalidad sin el formato de jq"
  cmp -s "$tmp/f/S2.json" "$tmp/S2.compacto" || err "bash $v: passes.sh no debería tocar una funcionalidad sin el formato de jq"
  rm -f "$tmp/f.orig/S4.json"
done

# passes.sh --check y --reset: un passes true vale mientras el código que probó el evaluador sea el de la cabeza.
V=$(mktemp -d)
gv() { git -C "$V" -c user.name=v -c user.email=v@v -c core.autocrlf=false "$@"; }
pv() { (cd "$V" && bash "$S" "$@" >/dev/null 2>&1); }
pv_es() { [ "$(jq -r .passes "$V/f/S2.json" | tr -d '\r')" = "$1" ]; }
evidencia_v() { printf '# Evidencia · S2 · 2026-11-17 · %s\n\n| Paso | Qué hizo | Resultado |\n|---|---|---|\n| 1 | … | cumple |\n\nVEREDICTO: %s\n' "$1" "$2" > "$V/ev/S2.md"; }
(
  gv init -q && gv checkout -q -b main && mkdir -p "$V/f" "$V/ev" \
    && printf '{"features": "f", "evidence_dir": "ev"}\n' > "$V/.city.json" \
    && printf '{\n  "id": "S2",\n  "passes": false\n}\n' > "$V/f/S2.json" && printf 'a\n' > "$V/a.txt" \
    && gv add . && gv commit -q -m base && gv checkout -q -b city/prueba \
    && printf 'b\n' > "$V/codigo.txt" && gv add . && gv commit -q -m corte
) || err "no pude armar el repo de prueba de passes.sh --check"
pv S2 --check || err "passes.sh --check con passes false debería salir con 0"
evidencia_v "$(gv rev-parse --short HEAD)" pasa
pv S2 || err "passes.sh con la evidencia del commit de la cabeza debería cambiar S2"
gv add . && gv commit -q -m evidencia
pv S2 --check || err "passes.sh --check no debería vencer la evidencia por el commit de la evidencia y del passes"
gv checkout -q main && printf 'z\n' > "$V/otro.txt" && gv add . && gv commit -q -m "avanza main" \
  && gv checkout -q city/prueba && gv merge -q --no-edit main || err "no pude mezclar main en el repo de prueba"
pv S2 --check || err "passes.sh --check no debería vencer la evidencia por un merge de la base sin conflictos"
printf 'c\n' >> "$V/codigo.txt" && gv commit -q -am "cambia el código"
pv S2 --check; [ $? -eq 1 ] || err "passes.sh --check debería salir con 1 si el código cambió después de evaluar"
pv S2 --check --ref city/prueba; [ $? -eq 1 ] || err "passes.sh --check --ref debería leer la rama y salir con 1"
pv_es true || err "passes.sh --check no debería escribir"
pv S2 --reset || err "passes.sh --reset debería salir con 0 al devolver un passes vencido"
pv_es false || err "passes.sh --reset debería dejar passes en false si el código cambió después de evaluar"
# --reset marca la evidencia vencida: ya no puede seguir diciendo "pasa", y passes.sh no la acepta.
tail -n 1 "$V/ev/S2.md" | tr -d '\r' | grep -qE "^VENCIDA: evaluó [0-9a-f]+; el código cambió en $(gv rev-parse --short HEAD)\$" \
  || err "passes.sh --reset debería terminar la evidencia vencida en 'VENCIDA: evaluó <commit>; el código cambió en <commit>'"
[ "$(grep -c '^VEREDICTO: pasa' "$V/ev/S2.md")" -eq 1 ] || err "passes.sh --reset no debería borrar el veredicto de la evidencia, solo marcarla"
case "$(cd "$V" && bash "$S" S2 2>&1)" in *'está vencida (VENCIDA: evaluó '*) ;; *) err "passes.sh debería decir que una evidencia con la marca VENCIDA está vencida" ;; esac
pv S2 --reset || err "passes.sh --reset sobre un passes ya en false debería salir con 0"
[ "$(grep -c '^VENCIDA:' "$V/ev/S2.md")" -eq 1 ] || err "passes.sh --reset no debería marcar dos veces la misma evidencia"
pv S2 && err "passes.sh con la evidencia de un commit vencido debería fallar"
pv_es false || err "passes.sh no debería poner true con la evidencia de un commit vencido"
evidencia_v "$(gv rev-parse --short HEAD)" pasa
pv S2 && pv_es true || err "passes.sh con una evidencia nueva del commit de la cabeza debería volver a true"
pv S2 --reset && pv_es true || err "passes.sh --reset no debería tocar un passes vigente"
evidencia_v abc1234 pasa
pv S2 --check; [ $? -eq 2 ] || err "passes.sh --check debería salir con 2 si no encuentra el commit evaluado"
pv S2 --reset; [ $? -eq 2 ] || err "passes.sh --reset debería salir con 2 si no encuentra el commit evaluado"
pv_es true || err "passes.sh --reset no debería escribir si no pudo comprobar"
evidencia_v "$(gv rev-parse --short HEAD)" "no pasa"
pv S2 --check; [ $? -eq 1 ] || err "passes.sh --check debería salir con 1 si la evidencia ya no dice pasa"
pv S2 --reset && pv_es false || err "passes.sh --reset debería devolver a false un passes cuya evidencia ya no dice pasa"
grep -q '^VENCIDA:' "$V/ev/S2.md" && err "passes.sh --reset no debería marcar como VENCIDA una evidencia que ya decía no pasa"
# Con una evidencia marcada y el passes todavía en true (alguien lo dejó así), --check la rechaza.
evidencia_v "$(gv rev-parse --short HEAD)" pasa && pv S2 && printf 'VENCIDA: evaluó abc1234; el código cambió en def5678\n' >> "$V/ev/S2.md"
pv S2 --check; [ $? -eq 1 ] || err "passes.sh --check debería salir con 1 con una evidencia marcada VENCIDA"
pv S2 --base no-existe --check; [ $? -eq 2 ] || err "passes.sh --base con una rama que no existe debería salir con 2"
pv S2 --ref main && err "passes.sh --ref sin --check debería fallar"
rm -rf "$V"

# passes.sh --check después de un squash-merge real: el commit evaluado no es ancestro de main,
# y en un clon nuevo ni siquiera está. Vale el commit que trajo la evidencia a main.
V=$(mktemp -d); V2=$(mktemp -d)
(
  gv init -q && gv checkout -q -b main && mkdir -p "$V/f" "$V/ev" "$V/docs" \
    && printf '{"features": "f", "evidence_dir": "ev"}\n' > "$V/.city.json" \
    && printf '{\n  "id": "S2",\n  "passes": false\n}\n' > "$V/f/S2.json" && printf 'a\n' > "$V/a.txt" \
    && gv add . && gv commit -q -m base && gv checkout -q -b city/prueba \
    && printf 'b\n' > "$V/codigo.txt" && gv add . && gv commit -q -m corte
) || err "no pude armar el repo de prueba del squash"
evidencia_v "$(gv rev-parse --short HEAD)" pasa
pv S2 && gv add . && gv commit -q -m evidencia || err "no pude dejar la evidencia en la rama del squash"
gv checkout -q main && printf 'z\n' > "$V/otro.txt" && gv add . && gv commit -q -m "avanza main" \
  && gv merge -q --squash city/prueba >/dev/null 2>&1 && gv commit -q -m "corte (#1)" || err "no pude hacer el squash-merge en el repo de prueba"
gv merge-base --is-ancestor city/prueba main && err "(prueba) tras el squash, la rama no debería ser ancestro de main"
pv S2 --check || err "passes.sh --check debería salir con 0 sobre main después de un squash-merge"
pv S2 --check --ref main || err "passes.sh --check --ref main debería salir con 0 después de un squash-merge"
printf 'y\n' >> "$V/otro.txt" && gv commit -q -am "otro corte"
pv S2 --check || err "passes.sh --check no debería vencer la evidencia por un commit posterior que no toca archivos del corte"
git clone -q --no-local --branch main --single-branch "$V" "$V2/clon" 2>/dev/null || err "no pude clonar el repo de prueba del squash"
git -C "$V2/clon" cat-file -e "$(gv rev-parse city/prueba)" 2>/dev/null && err "(prueba) el clon no debería traer el commit evaluado"
(cd "$V2/clon" && bash "$S" S2 --check >/dev/null 2>&1) || err "passes.sh --check debería salir con 0 en un clon que ya no trae el commit evaluado"
# Corregir un corte ya mezclado: una rama con código propio pide otra pasada; una que solo toca docs, no.
gv checkout -q -b city/2026-11-23-S2-fix && printf 'n\n' > "$V/docs/nota.md" && gv add . && gv commit -q -m docs
pv S2 --check || err "passes.sh --check no debería pedir otra pasada a una rama que solo cambia docs"
printf 'n\n' > "$V/nuevo.txt" && gv add . && gv commit -q -m "corrige el corte"
pv S2 --check; [ $? -eq 1 ] || err "passes.sh --check debería salir con 1 en una rama que cambia código de un corte ya mezclado"
evidencia_v "$(gv rev-parse --short HEAD)" pasa
pv S2 --check || err "passes.sh --check debería valer con la evidencia renovada sobre la cabeza de la rama de corrección"
gv add . && gv commit -q -m "evidencia renovada"
pv S2 --check || err "passes.sh --check debería seguir valiendo tras el commit de la evidencia renovada"
gv checkout -q main && gv merge -q --squash city/2026-11-23-S2-fix >/dev/null 2>&1 && gv commit -q -m "corrección (#2)" \
  || err "no pude hacer el squash-merge de la corrección"
pv S2 --check || err "passes.sh --check debería salir con 0 sobre main después del squash de la corrección"
# Otro corte, S3, entra después con su propia evidencia y toca los archivos que tocó S2: no vence a S2.
# Lo que vence una evidencia es código nuevo en la rama que se comprueba, no la historia posterior de main.
printf '{\n  "id": "S3",\n  "passes": false\n}\n' > "$V/f/S3.json" && gv add . && gv commit -q -m "spec de S3" \
  && gv checkout -q -b city/2026-11-24-S3 && printf 's3\n' >> "$V/codigo.txt" && printf 's3\n' >> "$V/nuevo.txt" \
  && gv commit -q -am "corte S3" || err "no pude armar la rama del corte S3"
printf '# Evidencia · S3 · 2026-11-24 · %s\n\n| Paso | Qué hizo | Resultado |\n|---|---|---|\n| 1 | … | cumple |\n\nVEREDICTO: pasa\n' "$(gv rev-parse --short HEAD)" > "$V/ev/S3.md"
pv S3 && gv add . && gv commit -q -m "evidencia de S3" || err "no pude dejar la evidencia de S3 en su rama"
pv S2 --check; [ $? -eq 1 ] || err "passes.sh --check de un corte mezclado debería salir con 1 en una rama con código propio (de ese corte se pregunta con --ref)"
pv S2 --check --ref main || err "passes.sh --check --ref main debería valer para S2 desde la rama de otro corte"
gv checkout -q main && gv merge -q --squash city/2026-11-24-S3 >/dev/null 2>&1 && gv commit -q -m "corte S3 (#3)" \
  || err "no pude hacer el squash-merge del corte S3"
gv diff --quiet HEAD~1 HEAD -- codigo.txt nuevo.txt && err "(prueba) el corte S3 debería cambiar archivos que tocó S2"
pv S2 --check || err "passes.sh --check no debería vencer un corte mezclado porque un corte posterior, con su evidencia, tocó sus archivos"
pv S2 --check --ref main || err "passes.sh --check --ref main no debería vencer un corte mezclado por un corte posterior"
pv S3 --check || err "passes.sh --check debería valer para el corte posterior sobre main"
pv S2 --reset && pv_es true || err "passes.sh --reset no debería tocar un corte mezclado porque otro corte tocó sus archivos"
grep -q '^VENCIDA:' "$V/ev/S2.md" && err "passes.sh --reset no debería marcar la evidencia de un corte mezclado que sigue vigente"
rm -rf "$V2/clon2"; git clone -q --no-local --branch main --single-branch "$V" "$V2/clon2" 2>/dev/null || err "no pude clonar el repo de prueba con dos cortes"
(cd "$V2/clon2" && bash "$S" S2 --check >/dev/null 2>&1) || err "passes.sh --check debería valer para S2 en un clon nuevo, después de un corte posterior"
# Una rama -fix nueva, con código, sigue pidiendo su pasada aunque main haya avanzado.
gv checkout -q -b city/2026-11-25-S2-fix2 && printf 'f\n' >> "$V/codigo.txt" && gv commit -q -am "corrige S2 otra vez"
pv S2 --check; [ $? -eq 1 ] || err "passes.sh --check debería salir con 1 en una rama -fix con código, también después de un corte posterior"
gv checkout -q main
# Límite documentado en passes.sh: un cambio que llega a main por otro camino (sin rama -fix) no se nota aquí.
printf 'c\n' >> "$V/nuevo.txt" && gv commit -q -am "cambia un archivo del corte en main"
pv S2 --check || err "passes.sh --check sobre main no mira la historia posterior al merge del corte (límite documentado)"
pv_es true || err "passes.sh --check no debería escribir después de un squash"
rm -rf "$V" "$V2"

# Corte apilado: su rama sale de la del corte de abajo, que aún no está en main. Con --base <rama de abajo>
# la huella cuenta solo el corte de arriba; sin ella, un commit nuevo del de abajo lo vence.
V=$(mktemp -d)
pv3_es() { [ "$(jq -r .passes "$V/f/S3.json" | tr -d '\r')" = "$1" ]; }
(
  gv init -q && gv checkout -q -b main && mkdir -p "$V/f" "$V/ev" \
    && printf '{"features": "f", "evidence_dir": "ev"}\n' > "$V/.city.json" \
    && printf '{\n  "id": "S2",\n  "passes": false\n}\n' > "$V/f/S2.json" \
    && printf '{\n  "id": "S3",\n  "passes": false\n}\n' > "$V/f/S3.json" \
    && gv add . && gv commit -q -m base && gv checkout -q -b city/abajo \
    && printf 'a\n' > "$V/abajo.txt" && gv add . && gv commit -q -m "corte de abajo" \
    && gv checkout -q -b city/arriba && printf 'b\n' > "$V/arriba.txt" && gv add . && gv commit -q -m "corte de arriba"
) || err "no pude armar el repo de prueba del corte apilado"
printf '# Evidencia · S3 · 2026-11-24 · %s\n\n| Paso | Qué hizo | Resultado |\n|---|---|---|\n| 1 | … | cumple |\n\nVEREDICTO: pasa\n' "$(gv rev-parse --short HEAD)" > "$V/ev/S3.md"
pv S3 --base city/abajo && pv3_es true && gv add . && gv commit -q -m "evidencia de S3" || err "passes.sh --base debería poner true un corte apilado con la evidencia de su cabeza"
pv S3 --check --base city/abajo || err "passes.sh --check --base no debería vencer la evidencia por el commit de la evidencia"
gv checkout -q city/abajo && printf 'a2\n' >> "$V/abajo.txt" && gv commit -q -am "el corte de abajo cambia" \
  && gv checkout -q city/arriba && gv merge -q --no-edit city/abajo || err "no pude traer el corte de abajo a la rama apilada"
pv S3 --check; [ $? -eq 1 ] || err "passes.sh --check sin --base, en una rama apilada, cuenta el código del corte de abajo como propio"
pv S3 --check --base city/abajo || err "passes.sh --check --base <rama de abajo> no debería vencer el corte de arriba por un commit del de abajo"
pv S3 --check --base city/abajo --ref city/arriba || err "passes.sh --check --base debería valer también con --ref"
printf 'b2\n' >> "$V/arriba.txt" && gv commit -q -am "el corte de arriba cambia"
pv S3 --check --base city/abajo; [ $? -eq 1 ] || err "passes.sh --check --base debería salir con 1 si cambió el código del corte de arriba"
pv S3 --reset --base city/abajo && pv3_es false || err "passes.sh --reset --base debería devolver a false el corte de arriba"
grep -q '^VENCIDA: evaluó ' "$V/ev/S3.md" || err "passes.sh --reset --base debería marcar la evidencia vencida"
rm -rf "$V"

# slice.sh y check-spec.sh sobre un hito de city 3.0, con un .city.json de 2.x (evidencia_dir).
L="$(pwd)/$CITY/scripts/slice.sh"; K="$(pwd)/$CITY/skills/spec/check-spec.sh"
bash -n "$L" || err "slice.sh no compila"
bash -n "$K" || err "check-spec.sh no compila"
H=docs/apps/app/mod-28-prueba/h01-hito
printf '{"features": "f", "evidencia_dir": "ev"}\n' > "$tmp/.city.json"
mkdir -p "$tmp/$H/slices" && echo "# spec" > "$tmp/$H/spec.md"
corte() { # corte <id> <class> <claves de más>
  printf '{"id": "%s", "class": "%s", "steps": [{"do": "a", "expect": "b"}, {"do": "c", "expect": "d"}], "depends_on": [], "estimated_lines": 100, "spec": "x", "passes": false%s}\n' \
    "$1" "$2" "$3" > "$tmp/$H/slices/$1.json"
}
spec_dice() { case "$(cd "$tmp" && bash "$K" "$H" 2>&1)" in *"$1"*) return 0 ;; esac; return 1; }
corte m28-h01-s01 data ''
corte m28-h01-s02 slice ', "rung": 1, "blocked_by": [{"question": "q", "owner": "o", "blocks_since": "2026-11-17"}]'
(cd "$tmp" && bash "$K" "$H" >/dev/null 2>&1) || err "check-spec.sh debería aceptar un hito en regla: rung opcional en data y blocked_by bien formado"
[ "$(cd "$tmp" && bash "$L" m28-h01-s02 | tr -d '\r' | sed -n 's/^evidence=//p')" = "$H/evidence/m28-h01-s02.md" ] || err "slice.sh debería dar la evidencia del hito en la clave evidence"
[ "$(cd "$tmp" && bash "$L" S1 | tr -d '\r' | sed -n 's/^evidence=//p')" = "ev/S1.md" ] || err "slice.sh debería leer evidencia_dir de un .city.json 2.x"
corte m28-h01-s03 slice ''
spec_dice 'm28-h01-s03: rung' || err "check-spec.sh debería exigir rung en class slice"
corte m28-h01-s03 slice ', "rung": 1, "blocked_by": "Ana"'
spec_dice 'm28-h01-s03: blocked_by' || err "check-spec.sh debería rechazar un blocked_by que no es una lista de objetos"
corte m28-h01-s03 slice ', "rung": 1, "clase": "Corte"'
spec_dice 'clase del formato anterior' || err "check-spec.sh debería rechazar las claves en español"
# estimate_basis: planned (por omisión) admite el 75 % del tope; measured, el tope entero (jq toma la última clave repetida).
corte m28-h01-s03 slice ', "rung": 1, "estimated_lines": 320'
spec_dice 'm28-h01-s03: estimated_lines 320 pasa 300' || err "check-spec.sh debería rechazar 320 líneas estimadas sin estimate_basis (75 % de 400)"
corte m28-h01-s03 slice ', "rung": 1, "estimated_lines": 320, "estimate_basis": "planned"'
spec_dice 'm28-h01-s03: estimated_lines 320 pasa 300' || err "check-spec.sh debería rechazar 320 líneas con estimate_basis planned"
corte m28-h01-s03 slice ', "rung": 1, "estimated_lines": 320, "estimate_basis": "measured"'
(cd "$tmp" && bash "$K" "$H" >/dev/null 2>&1) || err "check-spec.sh debería aceptar 320 líneas con estimate_basis measured (bajo el tope de 400)"
corte m28-h01-s03 slice ', "rung": 1, "estimated_lines": 400, "estimate_basis": "measured"'
(cd "$tmp" && bash "$K" "$H" 400 >/dev/null 2>&1) || err "check-spec.sh debería aceptar el tope entero con estimate_basis measured"
corte m28-h01-s03 slice ', "rung": 1, "estimated_lines": 401, "estimate_basis": "measured"'
spec_dice 'm28-h01-s03: estimated_lines 401 pasa 400' || err "check-spec.sh debería rechazar una estimación measured por encima del tope"
(cd "$tmp" && bash "$K" "$H" 500 >/dev/null 2>&1) || err "check-spec.sh debería leer el tope de su segundo argumento también con measured"
corte m28-h01-s03 slice ', "rung": 1, "estimate_basis": "medido"'
spec_dice 'm28-h01-s03: estimate_basis medido' || err "check-spec.sh debería rechazar un estimate_basis que no es planned ni measured"
# replaced_by: el corte ya no se construye, y puede apuntar a uno anterior.
corte m28-h01-s03 slice ', "estimated_lines": 900, "replaced_by": ["m28-h01-s01"]'
(cd "$tmp" && bash "$K" "$H" >/dev/null 2>&1) || err "check-spec.sh no debería exigir rung ni estimación a un corte con replaced_by, también hacia un corte anterior"
spec_dice '1 reemplazados' || err "check-spec.sh debería contar aparte los cortes reemplazados"
corte m28-h01-s03 slice ', "replaced_by": ["m28-h01-s77"]'
spec_dice 'replaced_by nombra m28-h01-s77' || err "check-spec.sh debería rechazar un replaced_by hacia un corte que no existe"
corte m28-h01-s03 slice ', "replaced_by": ["m28-h01-s01"]'
corte m28-h01-s04 slice ', "rung": 1, "depends_on": ["m28-h01-s03"]'
spec_dice 'm28-h01-s04: depende de m28-h01-s03, que fue reemplazado' || err "check-spec.sh debería rechazar un depends_on hacia un corte reemplazado"
# revision: un corte que nació o cambió en /city:spec revise; solo hacia él vale un depends_on a un id mayor.
corte m28-h01-s04 slice ', "rung": 1, "depends_on": ["m28-h01-s05"]'; corte m28-h01-s05 slice ', "rung": 1'
spec_dice 'm28-h01-s04: depende de m28-h01-s05, que va después' || err "check-spec.sh debería rechazar un depends_on hacia un id mayor sin revision"
corte m28-h01-s05 slice ', "rung": 1, "revision": "2026-11-20"'
spec_dice 'spec.md no trae esa fecha' || err "check-spec.sh debería exigir la fecha de revision bajo Decisiones tomadas de spec.md"
printf '# spec\n\n## Decisiones tomadas\n- 2026-11-20 · Ana Ruiz (PO) · s05 nace de su respuesta\n' > "$tmp/$H/spec.md"
(cd "$tmp" && bash "$K" "$H" >/dev/null 2>&1) || err "check-spec.sh debería aceptar un depends_on hacia un id mayor que trae revision"
corte m28-h01-s05 slice ', "rung": 1, "revision": "2026-11-20", "depends_on": ["m28-h01-s04"]'
spec_dice 'ciclo entre m28-h01-s04, m28-h01-s05' || err "check-spec.sh debería rechazar un ciclo de depends_on"
corte m28-h01-s05 slice ', "rung": 1, "revision": "2026-11-20"'
# "Decisiones tomadas" vale numerada o con viñetas: basta la fecha en una línea de la sección.
printf '# spec\n\n## Decisiones tomadas\n1. 2026-11-20 · Ana Ruiz (PO) · s05 nace de su respuesta · cortes: m28-h01-s05\n' > "$tmp/$H/spec.md"
(cd "$tmp" && bash "$K" "$H" >/dev/null 2>&1) || err "check-spec.sh debería aceptar Decisiones tomadas como lista numerada"
# ships_with: el corte no se despliega sin los que nombra, que existen y pueden ir después.
corte m28-h01-s04 slice ', "rung": 1, "depends_on": ["m28-h01-s05"], "ships_with": ["m28-h01-s05"]'
(cd "$tmp" && bash "$K" "$H" >/dev/null 2>&1) || err "check-spec.sh debería aceptar ships_with hacia un corte posterior que existe"
corte m28-h01-s04 slice ', "rung": 1, "depends_on": ["m28-h01-s05"], "ships_with": "m28-h01-s05"'
spec_dice 'm28-h01-s04: ships_with no es una lista' || err "check-spec.sh debería rechazar un ships_with que no es una lista"
corte m28-h01-s04 slice ', "rung": 1, "depends_on": ["m28-h01-s05"], "ships_with": []'
spec_dice 'm28-h01-s04: ships_with no es una lista no vacía' || err "check-spec.sh debería rechazar un ships_with vacío"
corte m28-h01-s04 slice ', "rung": 1, "depends_on": ["m28-h01-s05"], "ships_with": ["m28-h01-s04"]'
spec_dice 'm28-h01-s04: ships_with no es una lista no vacía de ids de otros cortes' || err "check-spec.sh debería rechazar un ships_with hacia el mismo corte"
corte m28-h01-s04 slice ', "rung": 1, "depends_on": ["m28-h01-s05"], "ships_with": ["m28-h01-s77"]'
spec_dice 'm28-h01-s04: ships_with nombra m28-h01-s77, que no existe' || err "check-spec.sh debería rechazar un ships_with hacia un corte que no existe"
corte m28-h01-s04 slice ', "rung": 1, "depends_on": ["m28-h01-s05"], "ships_with": ["m28-h01-s03"]'
spec_dice 'm28-h01-s04: ships_with nombra m28-h01-s03, que fue reemplazado' || err "check-spec.sh debería rechazar un ships_with hacia un corte reemplazado"
corte m28-h01-s04 slice ', "rung": 1, "depends_on": ["m28-h01-s05"]'
# --base: lo que un PR de clase spec puede cambiar de los cortes que ya están en la base.
gt() { git -C "$tmp" -c user.name=v -c user.email=v@v -c core.autocrlf=false "$@"; }
base_dice() { case "$(cd "$tmp" && bash "$K" "$H" 400 --base HEAD 2>&1)" in *"$1"*) return 0 ;; esac; return 1; }
base_ok() { (cd "$tmp" && bash "$K" "$H" 400 --base HEAD >/dev/null 2>&1); }
gt add -A && gt commit -q -m spec || err "no pude guardar la spec de prueba"
base_ok || err "check-spec.sh --base sin cambios debería salir con 0"
# Un git show que falla (en Windows, "Filename too long") es un error del script, no un corte que cambió:
# sale con 2 y sin líneas "falla:". Y lo llama con core.longpaths, que es lo que lo evita.
fg=$(mktemp -d); git_real=$(command -v git)
printf '#!/bin/sh\nfor a in "$@"; do if [ "$a" = show ]; then echo "$*" >> "%s/llamadas"; echo "fatal: Filename too long" >&2; exit 128; fi; done\nexec "%s" "$@"\n' "$fg" "$git_real" > "$fg/git"
chmod +x "$fg/git"
salida_fg=$(cd "$tmp" && PATH="$fg:$PATH" bash "$K" "$H" 400 --base HEAD 2>&1); rc_fg=$?
[ "$rc_fg" -eq 2 ] || err "check-spec.sh --base debería salir con 2 si git show falla (salió con $rc_fg)"
echo "$salida_fg" | grep -q '^falla:' && err "check-spec.sh --base no debería traducir un git show fallido en fallas de los cortes"
echo "$salida_fg" | grep -q 'git show no pudo leer.*Filename too long' || err "check-spec.sh --base debería decir que git show no pudo leer el corte, con el error de git"
grep -q -- '-c core.longpaths=true show' "$fg/llamadas" 2>/dev/null || err "check-spec.sh --base debería llamar a git show con -c core.longpaths=true"
rm -rf "$fg"
corte m28-h01-s04 slice ', "rung": 2, "depends_on": ["m28-h01-s05"]'
base_dice 'm28-h01-s04: cambió respecto a HEAD y no trae revision' || err "check-spec.sh --base debería exigir revision a un corte editado"
corte m28-h01-s04 slice ', "rung": 2, "depends_on": ["m28-h01-s05"], "revision": "2026-11-20"'
base_ok || err "check-spec.sh --base debería aceptar un corte con passes false editado con revision"
corte m28-h01-s02 slice ', "rung": 1'
base_ok || err "check-spec.sh --base no debería pedir revision por quitar blocked_by (unblock)"
rm -f "$tmp/$H/slices/m28-h01-s01.json"
base_dice 'm28-h01-s01: está en HEAD y aquí no' || err "check-spec.sh --base debería rechazar un corte borrado"
mkdir -p "$tmp/$H/evidence" && echo e > "$tmp/$H/evidence/m28-h01-s01.md" && corte m28-h01-s01 data ', "passes": true'
gt add -A && gt commit -q -m "s01 pasa" || err "no pude guardar el corte con passes true"
corte m28-h01-s01 data ', "passes": true, "description": "otra", "revision": "2026-11-20"'
base_dice 'm28-h01-s01: tiene passes true en HEAD y cambió' || err "check-spec.sh --base debería rechazar cualquier cambio en un corte con passes true"
corte m28-h01-s01 data ', "passes": true'
corte m28-h01-s02 slice ', "rung": 1, "passes": true'
base_dice 'm28-h01-s02: cambia passes' || err "check-spec.sh --base debería rechazar un passes que cambia en un PR de spec"
corte m28-h01-s02 slice ', "rung": 1'
(cd "$tmp" && bash "$K" "$H" 400 --base no-existe >/dev/null 2>&1); [ $? -eq 2 ] || err "check-spec.sh --base con un commit que no existe debería salir con 2"
rm -f "$tmp/$H/slices/m28-h01-s03.json"; corte m29-h01-s03 slice ', "rung": 1'
spec_dice 'm29-h01-s03: el id no es m28-h01-s' || err "check-spec.sh debería exigir el módulo y el hito de la carpeta en el id"
(cd "$tmp" && bash "$L" m29-h01-s03 >/dev/null 2>&1) && err "slice.sh debería fallar con un id que no vive en su módulo e hito"

# owners.sh: ruta con dueño es la unión de codeowners_paths y del archivo de dueños del repo.
W="$(pwd)/$CITY/scripts/owners.sh"
bash -n "$W" || err "owners.sh no compila"
duenos() { (cd "$tmp" && bash "$W" "$@" 2>/dev/null | tr -d '\r'); }
printf '{"codeowners_paths": ["docs/adr/**", "docker/**"]}\n' > "$tmp/.city.json"
[ "$(duenos --check | tr '\n' ' ')" = "file= pattern=docs/adr/** pattern=docker/** " ] || err "owners.sh sin archivo de dueños debería listar codeowners_paths y no divergir"
mkdir -p "$tmp/.github" && printf '# dueños\n/docs/adr/ @tl\n/docker/ @tl # infra\n/app/Core/ @tl\nMakefile @tl\nsuelto\n' > "$tmp/.github/CODEOWNERS"
(cd "$tmp" && bash "$W" --check >/dev/null 2>&1); [ $? -eq 1 ] || err "owners.sh --check debería salir con 1 si .city.json y el archivo de dueños divergen"
(cd "$tmp" && bash "$W" >/dev/null 2>&1) || err "owners.sh sin --check debería salir con 0 aunque diverjan"
duenos | grep -qx 'file=.github/CODEOWNERS' || err "owners.sh debería encontrar .github/CODEOWNERS"
duenos | grep -qx 'only_file=/app/Core/' || err "owners.sh debería avisar de una ruta que solo está en el archivo de dueños"
duenos | grep -q '^only_config=' && err "owners.sh debería tomar docs/adr/** y /docs/adr/ por la misma ruta"
[ "$(printf 'docs/adr/A.md\napp/Core/X\napp/Otro/Y\nsub/Makefile\nsuelto\ndocker/a/b.sh\n' | duenos --match | tr '\n' ' ')" = "docs/adr/A.md app/Core/X sub/Makefile docker/a/b.sh " ] \
  || err "owners.sh --match debería dar las rutas de la unión (y no una línea sin dueños)"
# shared: solo codeowners_paths (rutas compartidas, piden ADR). owned: solo el archivo de dueños (alguien aprueba).
[ "$(printf 'docs/adr/A.md\napp/Core/X\napp/Otro/Y\nsub/Makefile\ndocker/a/b.sh\n' | duenos --match shared | tr '\n' ' ')" = "docs/adr/A.md docker/a/b.sh " ] \
  || err "owners.sh --match shared debería dar solo las rutas de codeowners_paths"
[ "$(printf 'docs/adr/A.md\napp/Core/X\napp/Otro/Y\nsub/Makefile\ndocker/a/b.sh\n' | duenos --match owned | tr '\n' ' ')" = "docs/adr/A.md app/Core/X sub/Makefile docker/a/b.sh " ] \
  || err "owners.sh --match owned debería dar solo las rutas del archivo de dueños"
(cd "$tmp" && printf 'a\n' | bash "$W" --match otra >/dev/null 2>&1); [ $? -eq 2 ] || err "owners.sh --match con un lado que no es shared ni owned debería salir con 2"
printf '{"codeowners_paths": ["docs/adr/**"], "codeowners_file": "DUENOS"}\n' > "$tmp/.city.json"
(cd "$tmp" && bash "$W" >/dev/null 2>&1); [ $? -eq 2 ] || err "owners.sh debería salir con 2 si codeowners_file no existe"
printf 'docs/adr/ @tl\n' > "$tmp/DUENOS"
(cd "$tmp" && bash "$W" --check >/dev/null 2>&1) || err "owners.sh --check debería leer codeowners_file y salir con 0 si coinciden"
gt add -A && gt commit -q -m duenos && rm -f "$tmp/DUENOS" || err "no pude guardar el archivo de dueños de prueba"
(cd "$tmp" && bash "$W" --ref HEAD --check >/dev/null 2>&1) || err "owners.sh --ref debería leer .city.json y el archivo de dueños del commit"
rm -rf "$tmp"

# qa.py: solo ${VAR} y ${VAR:-valor}, sin slot al valor por omisión; url con qa.port si no trae puerto.
Q="$(pwd)/$CITY/scripts/qa.py"; E="$(pwd)/$CITY/scripts/qa-env.py"
tmp=$(mktemp -d); git -C "$tmp" init -q
qa_cfg() { printf '{"qa": %s}\n' "$1" > "$tmp/.city.json"; }
qa_es() { # qa_es <esperado> <clave> [VAR=valor...]
  local esperado=$1 clave=$2; shift 2
  [ "$(cd "$tmp" && env -u CITY_SLOT -u CITY_HTTP_PORT -u CITY_BASE_DOMAIN "$@" python3 "$Q" "$clave" 2>/dev/null)" = "$esperado" ] \
    || err "qa.py $clave con $(cat "$tmp/.city.json") ${*:-sin variables} debería dar '$esperado'"
}
qa_cfg '{"url": "http://app.${CITY_BASE_DOMAIN:-city.localhost}:${CITY_HTTP_PORT:-18080}", "port": "${CITY_HTTP_PORT:-18080}"}'
qa_es http://app.city.localhost:18080 url
qa_es 18080 port
qa_es http://app.s2.city.localhost:8082 url CITY_BASE_DOMAIN=s2.city.localhost CITY_HTTP_PORT=8082
qa_es 8082 port CITY_HTTP_PORT=8082
[ "$(cd "$tmp" && CITY_HTTP_PORT=8082 python3 "$E")" = "ENTORNO: local (http://app.city.localhost:8082)" ] \
  || err "qa-env sin URL debería expandir qa.url de .city.json"
qa_cfg '{"url": "http://app.localhost", "port": 18080}'
qa_es http://app.localhost:18080 url
qa_cfg '{"url": "http://app.localhost", "puerto": 18081}' # la clave de city 2.x
qa_es http://app.localhost:18081 url
qa_es 18081 port
for c in '{"url": "http://$(whoami).localhost"}' '{"url": "http://${HOME_NO_EXISTE}.localhost"}' \
  '{"url": "http://app.localhost", "port": "${CITY_HTTP_PORT:-x}"}' '{"smoke": "x"}'; do
  qa_cfg "$c"
  (cd "$tmp" && python3 "$Q" url >/dev/null 2>&1) && err "qa.py url debería fallar con $c"
done
rm -rf "$tmp"

for u in http://app.localhost:18080 http://127.0.0.1:18080 http://LOCALHOST/ https://app.city.localhost; do
  python3 "$E" "$u" >/dev/null || err "qa-env debería aceptar $u"
done
for u in https://example.com http://10.0.0.5 'http://[::1]/' http://localhost.example.com \
  http://localhost@example.com ftp://localhost http://localhost:99999 'sin url'; do
  python3 "$E" "$u" >/dev/null && err "qa-env debería bloquear $u"
done
# *.test con la resolución simulada: entra solo si todas sus direcciones son 127.0.0.1.
qa_test() { # qa_test <direcciones separadas por coma, o vacío si no resuelve>
  python3 - "$E" "$1" >/dev/null <<'PY'
import runpy, socket, sys
script, ips = sys.argv[1], [d for d in sys.argv[2].split(",") if d]
def falsa(host, *a, **k):
    if not ips:
        raise socket.gaierror(8, "no resuelve")
    return [(socket.AF_INET6 if ":" in d else socket.AF_INET, 1, 6, "", (d, 80)) for d in ips]
socket.getaddrinfo = falsa
sys.argv = [script, "http://city.test"]
runpy.run_path(script, run_name="__main__")
PY
}
qa_test 127.0.0.1 || err "qa-env debería aceptar un .test que resuelve a 127.0.0.1"
for ips in 10.0.0.5 127.0.0.1,10.0.0.5 127.0.0.1,::1 ''; do
  qa_test "$ips" && err "qa-env debería bloquear un .test que resuelve a '${ips:-nada}'"
done
python3 "$E" http://city.example >/dev/null && err "qa-env debería bloquear un dominio que no es .test"

echo "9/10 prueba del hook de dependencias en bash 3.2 y bash 5"
# El test llama al hook con `bash`: un enlace al frente del PATH hace que test y
# hook corran con el mismo bash.
G="$(pwd)/$CITY/scripts/dependency-guard.test.sh"
for B in /bin/bash /opt/homebrew/bin/bash; do
  if [ ! -x "$B" ]; then echo "  (sin $B en esta máquina: se salta la prueba en bash 5)"; continue; fi
  d=$(mktemp -d) && ln -s "$B" "$d/bash"
  if salida=$(PATH="$d:$PATH" "$B" "$G" 2>&1); then
    echo "  $(echo "$salida" | tail -1)"
  else
    echo "$salida" | grep '^FALLA' | sed 's/^/  /'
    err "dependency-guard.test.sh falla con bash $("$B" -c 'echo $BASH_VERSION'): $(echo "$salida" | tail -1)"
  fi
  rm -rf "$d"
done

echo "10/10 goal.sh: ShellCheck y prueba en seco con claude falso en bash 3.2 y bash 5"
GS="$CITY/scripts/goal.sh"; GT="$CITY/scripts/goal.test.sh"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$GS" "$GT" || err "ShellCheck no pasa limpio sobre goal.sh o goal.test.sh"
else
  err "falta shellcheck (brew install shellcheck)"
fi
for B in /bin/bash /opt/homebrew/bin/bash; do
  if [ ! -x "$B" ]; then echo "  (sin $B en esta máquina: se salta la prueba en bash 5)"; continue; fi
  "$B" -n "$GS" || err "goal.sh no compila con bash $("$B" -c 'echo $BASH_VERSION')"
  if salida=$("$B" "$GT" 2>&1); then
    echo "  $(echo "$salida" | tail -1)"
  else
    echo "$salida" | grep '^FALLA' | sed 's/^/  /'
    err "goal.test.sh falla con bash $("$B" -c 'echo $BASH_VERSION')"
  fi
done

if [ "$fail" -eq 0 ]; then echo "OK"; else echo "FALLÓ"; exit 1; fi
