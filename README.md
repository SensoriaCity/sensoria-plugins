# sensoria-plugins

El marketplace `sensoria` con los plugins de Claude Code de Sensoria. Hoy trae uno, `city`: el flujo de desarrollo con agentes de Sensoria para `city` y `city-v2`. Cada repo le dice al kit cómo es su stack con un `.city.json` en la raíz.

## Qué trae

| Skill o agente | Quién lo usa | Qué hace |
|---|---|---|
| `/city:spec` | Cualquiera | Escribe la spec de una página de un hito y la parte en cortes verticales que caben en el tope; los agrega a `features` con `passes: false`. Con `partir <id>`, reemplaza una funcionalidad que no es un corte |
| `/city:build` | Cualquiera | Construye una funcionalidad en su rama: compuerta de corte, prueba primero, tamaño, ADR, revisor y evaluador sobre una instalación limpia. `passes` cambia solo con la evidencia del evaluador |
| `/city:ship` | Cualquiera | Abre el PR con la plantilla del repo y el label, y lo deja en auto-merge por squash o esperando el merge de una persona (`git.merge`) |
| `/city:check` | Quien libera | Reporte de cierre de solo lectura: mergeados, `passes` con evidencia, retenidos, PR en rojo, ADR y qué clickear |
| `/city:revisar` | CI, o cualquiera a mano | Revisa un PR por número con el `revisor` y deja `veredicto.md` y `veredicto.txt` para el check de CI |
| `city:revisor` | `build`, `ship` y `revisar` | Lee el diff en contexto limpio; termina en "listo para merge" o "no mergear" |
| `city:seguridad` | `build` | Audita los archivos del diff que tocan autenticación, permisos, archivos, integraciones o el CLI |
| `city:evaluador` | `build` | Prueba la funcionalidad como usuario con Playwright, curl y bash; su evidencia es el único camino a `passes` |

## Empezar

1. Leer `docs/metodo.md`.
2. Seguir la preparación de `docs/adopcion.md` en el repo que adopta.
3. En `aidd-metrics`, aplicar `docs/integracion-aidd-metrics.md`.

Instalación para todo un repo, desde su clon:

```bash
claude plugin marketplace add SensoriaCity/sensoria-plugins --scope project
claude plugin install city@sensoria --scope project
```

Para probar un cambio del kit sin instalarlo, desde el clon del repo:

```bash
claude --plugin-dir ~/Projects/sensoria-plugins/plugins/city
```

## Estructura

```
.claude-plugin/marketplace.json     marketplace "sensoria" con el plugin city
plugins/city/
  .claude-plugin/plugin.json        versión del kit
  .mcp.json                         servidor de Playwright, con versión fija, para el evaluador
  city.schema.json                  contrato de .city.json
  skills/spec/                      SKILL.md + cortes.md (qué es un corte) + plantilla-spec.md
  skills/build/                     SKILL.md
  skills/ship/                      SKILL.md + plantilla-pr.md
  skills/check/                     SKILL.md + plantilla-cierre.md
  skills/revisar/                   SKILL.md, la que corre en GitHub Actions
  agents/                           revisor.md, seguridad.md y evaluador.md, sin edición
  hooks/hooks.json                  dependency-guard antes de Bash y de cada edición
  scripts/                          tamano.sh, passes.sh, entorno-qa.py y dependency-guard.sh
docs/
  metodo.md                         el método: ciclo, reglas, agentes, CI, capas y control humano
  adopcion.md                       city-v2 primero, luego una squad de city por semana
  fundamentos.md                    DORA y Anthropic detrás de cada regla
  coexistencia-bmad.md              qué no se toca en city mientras haya squads en BMAD
  integracion-aidd-metrics.md       firma del flujo y eventos de adopción
  ejemplos/city-v2.city.json        el .city.json de city-v2
bitacora.md                         registro semanal de cada repo o squad
scripts/numeros.py                  números semanales desde GitHub, sin esperar al dashboard
scripts/validar.sh                  valida el kit antes de publicar un cambio
CHANGELOG.md                        un cambio de comportamiento por semana
```

El estado final de AIDD Lite, cuyo piloto no llegó a empezar, quedó en el tag `aidd-lite-0.2.0`.

## Mantener el kit

Ver `CLAUDE.md`. Antes de publicar cualquier cambio: `./scripts/validar.sh`.
