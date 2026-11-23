# Fundamentos

De dónde sale cada regla de `city`. Las páginas son del informe DORA "The ROI of AI-assisted Software Development" v2026.1 (copia en `aidd-metrics/docs/referencias/`). Los artículos son de anthropic.com/engineering, revisados el 2026-09-29; el más reciente del índice es del 2026-05-25.

## Tesis

DORA mide la IA por los cuellos de botella que elimina, no por el código que genera: "We don't measure AI by the code it writes but by the bottlenecks it clears" (p.7). La IA amplifica el sistema donde cae. Si el código "piles up in front of manual security reviews or brittle deployment pipelines", la ganancia local se pierde aguas abajo (p.13).

Anthropic llega a lo mismo desde el lado del agente: "find the simplest solution possible, and only increasing complexity when needed" (Building effective agents, 2024-12-19). BMAD agregó complejidad sin que tuviéramos evidencia de que hiciera falta. `city` parte de lo mínimo y agrega piezas cuando `bitacora.md` las pida.

## Regla por regla

| Regla de `city` | DORA | Anthropic |
|---|---|---|
| Cortes de ≤400 líneas, un PR por corte | Frente al aumento de inestabilidad con IA, invertir en "strong version control practices and small batch sizes to catch errors before they reach the user" (p.19). "Working in small batches" como guardarraíl de proceso (p.33). | "Una feature a la vez" fue lo que resolvió que el agente intentara hacer todo de una vez (Effective harnesses for long-running agents, 2025-11-26). |
| PR directo a `main`, sin hitos apilados | El impuesto de verificación aumenta el lead time y reduce los despliegues posibles (p.33). | Cerrar cada sesión con el código "apto para merge a main" (Effective harnesses). |
| Spec de una página = hito, con funcionalidades de pasos verificables, implementada en sesión nueva | El aprendizaje pasa de "prompting" a "systems built on context, intent, and specification" (p.9). | Claude entrevista con AskUserQuestion, escribe `SPEC.md` y se implementa en otra sesión; la spec nombra archivos e interfaces, lo que queda fuera y la verificación (Best practices, docs vigentes). El planificador define alcance y diseño de alto nivel, sin detalle de implementación (Harness design for long-running application development, 2026-03-24). |
| Saltar la spec si el cambio cabe en una frase | | "If you could describe the diff in one sentence, skip the plan." (Best practices) |
| Tests primero y evidencia en vez de afirmaciones | Automated testing y continuous integration son lo que hace que la curva J rebote (p.10). Invertir fuerte en pruebas automáticas contra el impuesto de verificación (p.33). | Darle al agente una verificación ejecutable y pedir evidencia (Best practices). El verificador tiene que ser casi perfecto o el agente resuelve el problema equivocado (Building a C compiler with a team of parallel Claudes, 2026-02-05). |
| Revisor en contexto limpio, también como check de CI, sin la prosa del PR | "Leveraging AI to assist with code reviews" como forma de bajar el impuesto de verificación (p.33). | "tuning a standalone evaluator to be skeptical turns out to be far more tractable than making a generator critical of its own work" (Harness design). Revisar con un subagente en contexto fresco y limitarlo a corrección y requisitos (Best practices). Al clasificador de auto mode se le quita la prosa del asistente para que no lo convenza (How we built Claude Code auto mode). |
| Evaluador independiente que prueba como usuario y es el único dueño de `passes` | Automated testing y continuous integration hacen que la curva J rebote (p.10), e invertir en pruebas automáticas baja el impuesto de verificación (p.33). | "the evaluator used the Playwright MCP to click through the running application the way a user would, testing UI features, API endpoints, and database states". El evaluador se calibró con ejemplos, porque al principio encontraba problemas reales y "talk itself into deciding they weren't a big deal". Y "It is worth the cost when the task sits beyond what the current model does reliably solo" (Harness design). El verificador tiene que ser casi perfecto (Building a C compiler): por eso un paso que no se pudo verificar no pasa. |
| Control humano en tres lugares (`/city:check`, la feature completa antes del flag, la retro) y en lo que retiene CODEOWNERS | La confianza en la IA "is not blind. It is a calculated reliance built on a system that rewards verification over raw volume" (p.40): el merge depende de verificación que no se salta, no del volumen revisado. Revisiones de seguridad síncronas obligatorias y ADRs mantienen la familiaridad con el código (p.33). Por eso el agente `security` corre cuando el diff toca su superficie y un ADR lo lee otra squad. | "human review remains crucial for ensuring solutions align with broader system requirements" (Building effective agents). El auto mode "is not a drop-in replacement for careful human review" (How we built Claude Code auto mode, 2026-03-25): por eso la persona lee la feature completa, los ADR y lo que toca la política, y el alcance nunca es una instancia municipal. |
| Merge por checks: ruleset, CODEOWNERS, sandbox y hook de dependencias | "nonoptional checkpoints and pre-commit hooks paired with static analysis" (p.33). Pasar de controles manuales a "automated nonoptional security and quality gates" (p.42). | Hooks para lo que tiene que pasar siempre (Best practices). El plugin trae el hook `dependency-guard`; el ruleset de `main` exige el CI del repo, el `revisor` y la `evidencia`. |
| Contexto corto y a demanda: el kit lee `.city.json` y no cambia el `CLAUDE.md` del repo | Documentación "high fidelity and machine readable" y datos internos accesibles a la IA (p.41 y p.44). | "the smallest possible set of high-signal tokens" (Effective context engineering for AI agents, 2025-09-29). Las skills cargan su contenido solo al invocarse (Equipping agents for the real world with Agent Skills, 2025-10-16). Un `CLAUDE.md` inflado hace que Claude ignore las instrucciones (Best practices). |
| Un agente con plan, no seis personas | | Los sistemas multiagente gastan unas 15× los tokens de un chat y el código se paraleliza menos que la investigación (How we built our multi-agent research system, 2025-06-13). |
| Quitar piezas del kit de a una y revisarlas al cambiar de modelo | La ruta al ROI es construir capacidades, no correr detrás de la última herramienta (p.49). | "every component in a harness encodes an assumption about what the model can't do on its own" (Harness design). Con Opus 4.6 Anthropic quitó los sprints de ese harness y dejó el evaluador en una sola pasada al final (Harness design). Esos supuestos "can go stale as models improve" (Scaling Managed Agents, 2026-04-08). |
| Rama `<branches>` y label `city` para medir | Sin línea base no hay forma de saber el impacto (p.4). Monitorear lead time y change failure rate como alerta temprana durante la curva J (p.10). | Empezar con 20 a 50 casos reales y leer las transcripciones (Demystifying evals for AI agents, 2026-01-09). |
| No juzgar a una squad antes de su semana 4 | La curva J es "the tuition cost of transformation" (p.4). Las iniciativas fracasan cuando el liderazgo lee la fase de aprendizaje como fracaso y retira el apoyo en plena caída (p.8). | |
| Rotular experimentos con `experiment` | La frecuencia de experimentos es un indicador adelantado (p.45) y cada prototipo es una opción barata (p.46). | |
| Postura clara sobre IA en el equipo | "Clear and communicated AI stance" da la seguridad psicológica para pasar del escepticismo manual a la supervisión efectiva (p.40). | |

## Lo que DORA pide y `city` no resuelve solo

- **Plataforma interna y datos accesibles a la IA** (p.41 a p.44). `city` los usa pero no los construye. Si el revisor, el evaluador o el build tropiezan por falta de contexto de un módulo, eso va a la bitácora y se resuelve con documentación del módulo, no con más pasos en el kit.
- **Registro real de despliegues.** `aidd-metrics` usa el merge a `main` como proxy (ADR-001). Con PRs directos a `main` y despliegue por tag el proxy mejora, pero sigue siendo proxy.
- **Tiempo ahorrado como capacidad reinvertida, nunca como reducción de personal** (p.25 y p.48). Aplica igual a la adopción.

## Fuentes

- DORA, [The ROI of AI-assisted Software Development v2026.1](https://dora.dev/vc/airoi/?v=2026.1)
- [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents), 2024-12-19
- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system), 2025-06-13
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents), 2025-09-29
- [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills), 2025-10-16
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents), 2025-11-26
- [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents), 2026-01-09
- [Building a C compiler with a team of parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler), 2026-02-05
- [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps), 2026-03-24
- [How we built Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode), 2026-03-25
- [Scaling Managed Agents](https://www.anthropic.com/engineering/managed-agents), 2026-04-08
- [Claude Code best practices](https://code.claude.com/docs/en/best-practices) (el artículo de 2025-04-18 hoy redirige a esta documentación)
