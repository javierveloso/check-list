# Checklist v2 — Code Review Kit

Catálogo modular de checklists de **code review**, diseñado para ser consumido por
un agente de revisión automatizada (LLM) **y** por revisores humanos.

- Agnóstico de lenguaje/framework: los controles están redactados en términos de
  **comportamiento esperado** y **señales de problema**, no de API de una librería concreta.
- Cada control tiene un **ID estable**, una **severidad**, **banderas rojas** accionables,
  y **metadata de búsqueda** (`Dónde buscar` / `Patrones` / `Señal de N/A`) para que un
  agente lo evalúe mecánicamente.
- Dividido en módulos pequeños (200-400 líneas) para que el agente cargue solo lo relevante.
- Un **índice maestro** (`index.yaml`) permite consumo programático.

---

## Por dónde empezar

| Si eres... | Lee primero |
|---|---|
| Un **agente de auditoría** (LLM con Glob/Grep/Read) | [`EXECUTION_GUIDE.md`](EXECUTION_GUIDE.md) — modos, workflow, árbol de decisión |
| Un **agente que va a aplicar fixes** | [`_prompts/agent-fixer.md`](_prompts/agent-fixer.md) + el `FIX_PLAN.md` del run |
| Quien **integra el kit en CI/CD** | [`_prompts/`](_prompts/) (system prompts listos) + [`REPORTING_GUIDE.md`](REPORTING_GUIDE.md) |
| Un **revisor humano** | Este README + el `.md` de la categoría que te interese |
| Quien va a **agregar/editar controles** | [`_templates/control-template.md`](_templates/control-template.md) |

---

## Estructura

```
checklist-v2/
├── README.md                    ← Este archivo (overview general)
├── EXECUTION_GUIDE.md           ← Cómo un AGENTE ejecuta el catálogo
├── REPORTING_GUIDE.md           ← Formato de salida (findings.json, REPORT.md, FIX_PLAN.md)
├── index.yaml                   ← Catálogo estructurado de TODOS los controles
│
├── _templates/
│   ├── control-template.md      ← Plantilla para nuevos controles
│   ├── REPORT.md.tpl            ← Plantilla del reporte humano
│   ├── fix-plan.md.tpl          ← Plantilla del plan de fixes
│   └── findings.schema.json     ← JSON Schema del findings.json
│
├── _prompts/
│   ├── agent-auditor.md         ← System prompt: full-audit
│   ├── agent-pr-reviewer.md     ← System prompt: pr-review
│   ├── agent-fixer.md           ← System prompt: aplicar fixes
│   └── agent-coordinator.md     ← System prompt: orquestar workers en paralelo
│
├── 01-seguridad/                ← OWASP Top 10, auth, criptografía, headers, archivos
├── 02-api-diseno/               ← REST, versionado, paginación, idempotencia
├── 03-calidad-codigo/           ← Estilo, naming, SOLID, complejidad, errores
├── 04-testing/                  ← Estrategia, unit, integración, E2E, mocks
├── 05-rendimiento/              ← Frontend (CWV), backend async, BD, caché
├── 06-proteccion-datos/         ← GDPR-style, PII, consentimiento, retención
├── 07-ia-llm/                   ← Prompts, seguridad, costos, hallucinations
├── 08-usabilidad-ux/            ← Nielsen, feedback, formularios, estados UI
├── 09-accesibilidad/            ← WCAG 2.2 AA (perceptible, operable, comprensible, robusto)
├── 10-observabilidad/           ← Logs, métricas RED/USE, tracing, SLOs, alertas
├── 11-cicd-devops/              ← Pipelines, quality gates, releases, rollback
├── 12-arquitectura/             ← Principios de diseño, resiliencia, fronteras
├── 13-base-datos/               ← Esquema, migraciones, índices, transacciones
├── 14-documentacion/            ← Código, API, ADRs, documentación operacional
│
├── reports/                     ← Reportes generados (un subfolder por run)
└── repos/                       ← Repos de ejemplo para validar el kit
```

Cada categoría contiene 2–4 archivos `.md`, cada uno con entre 10 y 30 controles agrupados.

---

## Convención de IDs

Formato: `<CATEGORÍA>-<SUBCATEGORÍA>-<NNN>`

| ID | Categoría | Subcategoría |
|---|---|---|
| `SEC-AUTH-001` | Seguridad | Autenticación |
| `SEC-INPUT-014` | Seguridad | Validación entrada |
| `API-REST-007` | API | Diseño REST |
| `PERF-DB-003` | Performance | Base de datos |
| `A11Y-KBD-005` | Accesibilidad | Teclado |
| `LLM-PROMPT-002` | IA/LLM | Prompts |
| `DATA-RET-004` | Protección datos | Retención |

Los IDs son **estables** — no se reutilizan ni renumeran cuando se eliminan controles.

---

## Niveles de severidad

| Severidad | Cuándo usarla | `merge_action` |
|---|---|---|
| `critical` | Riesgo directo de brecha, pérdida de datos, vulnerabilidad explotable | `block_merge` |
| `high` | Bug funcional serio, impacto en producción probable | `request_changes` |
| `medium` | Mejora importante de mantenibilidad/performance, sin riesgo inmediato | `comment` (fuerte) |
| `low` | Mejora de estilo o consistencia | `comment` (nit) |
| `info` | Buenas prácticas, no obligatorio | `comment` (info) |

---

## Formato de cada control

```markdown
#### `SEC-AUTH-001` — Hash de contraseñas con algoritmo moderno
**Severidad:** critical · **Tags:** `owasp-a07`, `cwe-256` · **Aplica a:** backend

Descripción breve del comportamiento esperado.

**Dónde buscar:** `**/*.{ts,js,py}`, `**/auth/**`, `**/users/**`
**Patrones:**
- `hashlib\.(md5|sha1|sha256)\([^)]*password`   # KDF débil
- `==.*password`                                # comparación no time-constant
**Señal de N/A:** ningún módulo de gestión de usuarios/passwords en el repo.

**Verificar:**
- [ ] Las contraseñas no aparecen jamás en texto plano.
- [ ] El algoritmo es bcrypt, argon2id, scrypt o PBKDF2.
- [ ] La comparación de hashes es de tiempo constante.

**Banderas rojas:**
- Funciones de hash rápidas aplicadas a passwords.
- Comparaciones con `==` de hashes de contraseña.

**Referencias:** OWASP ASVS 2.4 · NIST SP 800-63B §5.1.1.2 · CWE-256.
```

Los tres campos en negrita (`Dónde buscar`, `Patrones`, `Señal de N/A`) son **opcionales
pero recomendados** — sin ellos el agente debe inventar la estrategia de búsqueda y
los falsos positivos suben.

---

## Cómo lo usa un **agente de code review**

Resumen muy corto (el detalle está en [`EXECUTION_GUIDE.md`](EXECUTION_GUIDE.md)):

1. Lee `EXECUTION_GUIDE.md`, `REPORTING_GUIDE.md`, `index.yaml`.
2. Detecta el stack del repo (`package.json`, `pyproject.toml`, `Dockerfile`, etc.).
3. Filtra los controles aplicables según `applies_to` y stack.
4. Por cada control: ejecuta sus `Glob` + `Grep` declarados, decide veredicto.
5. Emite tres artefactos:
   - **`findings.json`** — fuente de verdad machine-readable.
   - **`REPORT.md`** — síntesis humana.
   - **`FIX_PLAN.md`** — plan de fixes agrupado por archivo, para agente desarrollador.

Para empezar, copia el system prompt de [`_prompts/agent-auditor.md`](_prompts/agent-auditor.md)
e indica el repo a auditar.

---

## Cómo lo usa un **revisor humano**

1. Identifica las categorías relevantes al cambio en revisión.
2. Lee el `.md` correspondiente.
3. Marca cada control con uno de:
   - `[x]` verificado, sin problemas
   - `[!]` problema detectado (dejar comentario en el PR referenciando el ID)
   - `[~]` no aplica
4. Prioriza los `critical` y `high` primero.

---

## Cómo agregar un **nuevo control**

1. Copiar [`_templates/control-template.md`](_templates/control-template.md).
2. Asignar un ID siguiendo la convención. Verificar que no esté ya tomado en `index.yaml`.
3. Completar **incluyendo** los nuevos campos `Dónde buscar` / `Patrones` / `Señal de N/A`.
4. Añadir el control al archivo `.md` apropiado.
5. Añadir una entrada en `index.yaml`.
6. Si creas una categoría nueva, documentarla aquí y en el índice.

---

## Cómo agregar una **nueva categoría**

1. Crear carpeta `NN-nombre/`.
2. Elegir un prefijo de 2–5 letras para los IDs (ej: `OBS` para observabilidad).
3. Agregar la categoría en `index.yaml` bajo `categories:`.
4. Documentarla en la sección **Estructura** de este README.

---

## Fuentes y estándares de referencia

- **Seguridad:** OWASP API Security Top 10 (2023), OWASP Web Top 10 (2021), OWASP ASVS 4.0, CWE Top 25, SANS Top 25
- **API:** Richardson Maturity Model, JSON:API, OpenAPI 3.1, RFC 7231, RFC 7807, Google API Design Guide, Microsoft REST API Guidelines
- **Código:** Clean Code (R.C. Martin), SOLID, Effective Software Testing, Refactoring (Fowler)
- **Privacidad:** GDPR (UE), CCPA (EE.UU.), LGPD (Brasil), Ley 19.628 y Ley 21.719 (Chile)
- **Accesibilidad:** WCAG 2.2 AA (W3C), ARIA 1.2
- **UX:** Nielsen Norman Group 10 heurísticas
- **Observabilidad:** Google SRE book (SLOs), OpenTelemetry, RED/USE methods
- **Testing:** Testing Trophy (Kent C. Dodds), FIRST, AAA
- **IA/LLM:** OWASP Top 10 for LLM Applications, NIST AI RMF, Anthropic/OpenAI safety guidelines

---

## Versionado del propio catálogo

Versionado semántico:

- `MAJOR`: cambios breaking (eliminación de controles, cambio de estructura de IDs).
- `MINOR`: nuevos controles o categorías; **adición de metadata opcional** (como los campos de búsqueda).
- `PATCH`: correcciones de redacción, nuevas referencias.

Versión actual: **2.1.0** — añadidos campos de metadata de búsqueda + guías de ejecución y reporte (ver `index.yaml`).
