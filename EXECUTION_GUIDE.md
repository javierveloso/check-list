# Execution Guide — Cómo un agente debe ejecutar el catálogo checklist-v2

> Guía operativa para agentes (LLMs con acceso a herramientas tipo Claude Code:
> `Glob`, `Grep`, `Read`, `Bash`). Si eres un revisor humano, usa el [README.md](README.md).
> Si necesitas el formato de los artefactos de salida, ver [REPORTING_GUIDE.md](REPORTING_GUIDE.md).

---

## 0. TL;DR para el agente

```
1. Lee este archivo completo.
2. Identifica el modo de ejecución (full-audit | pr-review | targeted-scan).
3. Detecta el stack del repo bajo análisis.
4. Carga index.yaml. Filtra controles aplicables.
5. Por cada control aplicable: ejecuta sus búsquedas, decide veredicto.
6. Emite findings.json + REPORT.md + FIX_PLAN.md según REPORTING_GUIDE.md.
```

No improvises pasos. No inventes controles fuera del catálogo.
Si algo no está cubierto, regístralo como `verdict: needs_human` con razón.

---

## 1. Modos de operación

Antes de empezar, define en qué modo operas. Cada uno cambia qué cargas y qué emites.

| Modo | Input | Scope | Output principal | Cuándo usarlo |
|---|---|---|---|---|
| **`full-audit`** | Ruta de un repo completo | Todos los archivos del repo | `REPORT.md` + `findings.json` + `FIX_PLAN.md` | Auditoría puntual de un proyecto. Onboarding a un repo nuevo. Pre-cierre de cliente. |
| **`pr-review`** | Diff o PR URL | Solo archivos tocados + sus dependencias directas | Comentarios estructurados sobre líneas + `findings.json` | Revisión continua de PRs en CI. |
| **`targeted-scan`** | Lista de IDs de control o un prefijo (ej: `SEC-*`) | Repo completo, pero solo los controles indicados | `findings.json` + `REPORT.md` filtrado | Investigación específica ("¿tenemos IDOR?"). Re-auditoría tras un fix. |

**Regla de oro:** si no te dijeron explícitamente qué modo usar, asume `full-audit`
y declara la asunción en `metadata.mode` del `findings.json`.

---

## 2. Workflow paso a paso

### Paso A — Detectar el stack

Antes de cargar controles, inferí qué tecnologías hay. Esto evita evaluar 614 controles
cuando muchos no aplican.

**Tool patterns:**
```
Read ./package.json                # JS/TS, frameworks, dev deps
Read ./pyproject.toml ./requirements.txt  # Python
Read ./go.mod                      # Go
Read ./Gemfile                     # Ruby
Read ./pom.xml ./build.gradle      # JVM
Read ./Cargo.toml                  # Rust
Read ./composer.json               # PHP
Glob ./Dockerfile* ./docker-compose*.yml
Glob ./.github/workflows/*.yml ./.gitlab-ci.yml ./azure-pipelines.yml
Glob ./**/*.{tf,bicep}             # IaC
Glob ./**/migrations/** ./**/schema.{sql,prisma}
```

**Producir un objeto `stack_signal`:**
```yaml
languages: [typescript, sql]
frameworks: [express, typeorm, react]
areas:
  has_backend: true
  has_frontend: true
  has_api: true            # rutas REST/GraphQL detectadas
  has_db: true             # ORM o queries SQL detectados
  has_iac: false
  has_ci: true             # workflows en .github/ o equivalente
  has_llm: false           # no hay openai|anthropic|@langchain en deps
  has_mobile: false
  has_data_pipelines: false
deploy_targets: [docker, azure-app-service]
```

Este objeto se incluye en `findings.json` → `metadata.stack_signal`.

### Paso B — Filtrar controles aplicables

```
Read ./checklist-v2/index.yaml
```

Aplica los siguientes filtros para obtener el `subset` de controles a evaluar:

1. **Por área** (`applies_to`): descarta controles cuyo `applies_to` no intersecta con `stack_signal.areas`. Ej: si `has_frontend == false`, descarta todos los `applies_to: [frontend]`.
2. **Por modo**:
   - `full-audit` → todos los controles del subset.
   - `pr-review` → solo controles cuyos `Dónde buscar` intersectan con los archivos del diff.
   - `targeted-scan` → solo los IDs solicitados (ignora filtros previos).
3. **Por presupuesto de contexto** (ver §5).

Reporta el conteo: `controls_evaluated / controls_total` en `metadata`.

### Paso C — Cargar módulos

Lee solo los `.md` que contienen controles del subset. No leas categorías completas
si solo necesitas 3 controles de ahí — usa `Read` con `offset`/`limit` cuando
puedas anclar al ID.

```
Read ./checklist-v2/01-seguridad/01-autenticacion.md
```

### Paso D — Evaluar cada control

Para cada control en el subset, ejecuta este micro-loop:

```
1. Leer la descripción + Verificar + Banderas rojas + Patrones.
2. ¿La 'Señal de N/A' se cumple? → verdict: na, registrar razón, continuar.
3. Glob (paths del control 'Dónde buscar') → lista de archivos candidatos.
   ¿Lista vacía? → verdict: na, razón "no files in scope", continuar.
4. Por cada patrón en 'Patrones':
   Grep <patrón> en la lista de archivos candidatos.
5. Si hay matches → leer contexto (Read del archivo en torno a la línea).
6. Aplicar el árbol de decisión (§3) y emitir finding(s).
```

**Importante:**
- Un control puede generar **múltiples findings** (mismo control_id, distintos archivos/líneas).
- Si dos controles disparan en la misma evidencia, emite ambos findings — no consolides; el `related_findings` se completa después.
- No leas archivos enteros para "ver si hay algo" — confía en `Glob` + `Grep`. Solo `Read` cuando ya tienes una línea concreta a confirmar.

### Paso E — Emitir hallazgos

Acumula los findings durante todo el run. Al terminar, escribe `findings.json`
según el schema en [REPORTING_GUIDE.md](REPORTING_GUIDE.md).

### Paso F — Generar reportes humanos

Desde `findings.json`, deriva:
- `REPORT.md` (humano) — usa la plantilla `_templates/REPORT.md.tpl`.
- `FIX_PLAN.md` (agente desarrollador) — usa `_templates/fix-plan.md.tpl`.

Ambos viven junto al `findings.json` en la carpeta de reporte que el usuario indique.

---

## 2.5. Contexto de entorno y exclusiones locales

El agente opera en uno de dos contextos declarados por el usuario al inicio del run:

| Contexto | Cuándo usarlo |
|---|---|
| `local` | Revisión en máquina de desarrollo. Archivos `.env` son esperados y gestionados manualmente. |
| `ci_prod` | Pipeline CI, staging, pre-release o auditoría formal. Strictez máxima. |

Registra el contexto en `findings.json` → `metadata.context`.

### Exclusiones automáticas en `context: local`

Los siguientes patrones se tratan como `verdict: na` para controles cuyo único criterio
de fallo es **la presencia de credenciales reales en el archivo** (p.ej. SEC-CRYPTO-001):

```
.env
.env.local
.env.development
.env.development.local
.env.test.local
.env.production.local   ← solo si context:local; en ci_prod sigue siendo crítico
```

**Checks que NUNCA se omiten aunque `context: local`:**

| Check | Razón |
|---|---|
| `.env` ausente de `.gitignore` | Sin esto, un `git add .` lo expone al repo. |
| `.env` presente en git history (`git log --all -- "*.env"`) | El daño ya ocurrió — las credenciales están en el historial público. |
| Secrets hardcodeados en archivos de código fuente (`*.ts`, `*.js`, `*.py`…) | Estos archivos se commitean; no son archivos de entorno. |
| Secrets hardcodeados en archivos de test (`*.test.*`, `*.spec.*`, `*.contract.*`) | Los tests se commitean — alto riesgo de exposición en CI/CD. |

### Cómo registrar exclusiones locales en findings.json

En `metadata`:
```json
"context": "local",
"local_exclusions_applied": [".env", ".env.local"]
```

En cada finding marcado `na` por exclusión local:
```json
{
  "verdict": "na",
  "na_reason": "context:local — archivo .env con credenciales es esperado en desarrollo local. Verificado: archivo está en .gitignore y no aparece en git history."
}
```

---

## 3. Árbol de decisión por control

Para cada control, el veredicto es uno de cuatro:

```
                    ┌─ "Señal de N/A" se cumple
                    │  → verdict: na
                    │
                    │  Glob devolvió 0 archivos en scope
                    │  → verdict: na  (razón: "no files in scope")
                    │
Evaluar control ────┤
                    │  Patrones encontrados, evidencia clara
                    │  → verdict: failed   (confidence: high)
                    │
                    │  Patrones encontrados, contexto ambiguo
                    │  → verdict: failed   (confidence: medium|low)
                    │
                    │  Sin patrones encontrados, verificación positiva visible
                    │  → verdict: passed
                    │
                    └─ Señal contradictoria, no se puede decidir
                       → verdict: needs_human (registrar razón)
```

### Calibración de `confidence`

| Nivel | Cuándo emitirlo |
|---|---|
| `high` | El patrón literal del control coincide en una línea concreta. La evidencia es self-contained (no requiere asumir nada del contexto). |
| `medium` | Hay coincidencia pero la red flag depende de cómo se use ese código. Posible falso positivo si hay sanitización aguas arriba que el agente no leyó. |
| `low` | Heurística débil o señal indirecta. Reportar pero marcar para revisión humana en el reporte. |

**Si `confidence: low`**, también añadir `verdict: needs_human` salvo que la severidad sea `critical` (en ese caso siempre reportar como `failed` y dejar que el humano descarte).

### Cuándo emitir `verdict: passed`

No hace falta evidencia exhaustiva — sería caro. Reglas pragmáticas:

- Si `Patrones` es no-vacío y no hubo matches: `passed` con evidencia "no matches for declared patterns".
- Si el control tiene "Verificar" positivo claramente comprobable (ej: "existe `.env.example`"), verificarlo y registrar.
- Para controles sin patrones mecánicos (transversales), **no emitir `passed`** — déjalos fuera del reporte o márcalos `needs_human`. Falsos positivos de "passed" son peores que ausencias.

---

## 4. Stop conditions y manejo de errores

- **Si `Glob` falla** (permisos, paths inválidos): registra `verdict: needs_human` con razón técnica. No reintentes más de 1 vez.
- **Si un `Grep` con regex inválida falla**: trata el patrón como no-encontrado, registra warning en metadata. No abortar el control.
- **Si excedes el presupuesto de contexto** (ver §5): emite los findings que tengas y registra `controls_skipped` en metadata con la lista de IDs no evaluados.
- **Nunca inventes findings** sin evidencia textual. Si tienes la corazonada de que algo está mal pero no lo encuentras, emite `needs_human`.

---

## 5. Presupuesto de contexto y orden de carga

Con 614 controles, no todos cabrán cómodamente en una corrida monolítica.
Recomendación de orden de carga (cuando hay que priorizar):

| Prioridad | Categorías | Cuándo cargar |
|---|---|---|
| **P0 (siempre)** | `01-seguridad/*` | Todos los modos, todos los stacks. |
| **P0 (si aplica)** | `06-proteccion-datos/*` si el repo procesa datos personales | `has_backend && has_db` |
| **P1** | `02-api-diseno/*`, `12-arquitectura/*` | `has_api` |
| **P1** | `13-base-datos/*`, `05-rendimiento/03-base-datos-red.md` | `has_db` |
| **P1** | `08-usabilidad-ux/*`, `09-accesibilidad/*`, `05-rendimiento/01-frontend.md` | `has_frontend` |
| **P1** | `07-ia-llm/*` | `has_llm` |
| **P2** | `03-calidad-codigo/*`, `04-testing/*` | Siempre, pero es lo primero que se sacrifica si hay límite. |
| **P2** | `10-observabilidad/*`, `11-cicd-devops/*` | `has_ci || has_iac` |
| **P3** | `14-documentacion/*` | Solo si hay tiempo. Genera muchos `low`/`info`. |

Cuando el presupuesto es estrecho, considera:
1. Bajar prioridad de severidad `low` y `info`.
2. Saltar categorías P3.
3. Usar el patrón **multi-agente** (§6) para paralelizar.

---

## 6. División multi-agente

Cuando un solo agente no alcanza, divide el trabajo entre N agentes en paralelo.
Cada agente cubre un subconjunto disjunto del catálogo y emite un **fragmento**.
Un agente coordinador consolida los fragmentos al final.

**Plantilla de roles** (ajustable según `stack_signal`):

| Rol | Categorías | Output |
|---|---|---|
| `agent-1` | SEC: Auth + Authz + Input | `fragments/agent-1.{md,json}` |
| `agent-2` | SEC: Crypto + Headers + Deps + Files | `fragments/agent-2.{md,json}` |
| `agent-3` | API + ARCH | `fragments/agent-3.{md,json}` |
| `agent-4` | CODE + TEST | `fragments/agent-4.{md,json}` |
| `agent-5` | PERF + DB | `fragments/agent-5.{md,json}` |
| `agent-6` | DATA + OBS | `fragments/agent-6.{md,json}` |
| `agent-7` | CICD + DOC + LLM (si aplica) | `fragments/agent-7.{md,json}` |
| `coordinator` | Consolidar fragments → `findings.json` + `REPORT.md` + `FIX_PLAN.md` | Reporte final |

Cada agente sigue exactamente este `EXECUTION_GUIDE.md` pero con su `subset` restringido.
El coordinador usa el prompt en `_prompts/agent-coordinator.md`.

**Reglas de paralelización:**
- Cada agente tiene acceso de lectura al repo. Ninguno escribe sobre archivos del repo bajo análisis.
- Los fragments JSON deben validar contra el mismo schema (`findings.schema.json`) — son simplemente subconjuntos del `findings.json` final.
- El coordinador puede detectar duplicados via `finding_id` (hash estable) y consolidar `related_findings`.

---

## 7. Walkthrough — ejemplo `full-audit`

Repo: `repos/backend/` (Express + TypeORM + PostgreSQL).

**Paso A — Stack detectado:**
```yaml
languages: [typescript]
frameworks: [express, typeorm]
areas: { has_backend: true, has_db: true, has_api: true, has_ci: true, has_frontend: false, has_llm: false }
deploy_targets: [docker, azure-app-service]
```

**Paso B — Subset filtrado:**
- Descartados: `09-accesibilidad/*` (no frontend), `08-usabilidad-ux/*` (no UI), `07-ia-llm/*` (no LLM deps).
- Subset = ~390 controles de los 614.

**Paso D — Ejemplo concreto, control `SEC-AUTH-002` ("secretos no hardcodeados"):**
```
Glob **/.env* **/docker-compose*.yml **/*.{ts,js}
  → 47 archivos candidatos
Grep "SECRET_KEY\s*=\s*[\"']?[^\"'\n]{1,15}[\"']?$" en candidatos
  → match en docker-compose.yml:7  →  SECRET_KEY=secret
Read docker-compose.yml:1-15 (confirmar contexto)
  → confirmado: variable de entorno hardcodeada con valor trivial
Verdict: failed, confidence: high
Emit finding (ver REPORTING_GUIDE.md)
```

**Paso E — Emitir `findings.json`** (acumulado de todos los controles).

**Paso F — Generar `REPORT.md`** (humano, agrupado por severidad) y `FIX_PLAN.md` (agrupado por archivo).

---

## 8. Walkthrough — ejemplo `pr-review`

Input: PR que toca `src/auth/jwt.service.ts`, `src/auth/jwt.service.spec.ts`.

**Paso A — Stack detectado** (igual que en full-audit, una sola vez).

**Paso B — Subset:**
- Para cada archivo del diff, intersectar con el `**Dónde buscar**` declarado en cada control.
- `src/auth/jwt.service.ts` matchea con globs como `**/auth/**`, `**/jwt/**`, `**/*.ts`.
- Subset reducido a ~25 controles relevantes (SEC-AUTH-*, SEC-CRYPTO-*, parte de CODE-*).

**Paso D — Ejecutar solo sobre los archivos del diff** (no todo el repo).

**Paso E/F:** En vez de `REPORT.md` global, emite **comentarios por línea** estructurados:
```yaml
- file: src/auth/jwt.service.ts
  line: 42
  control_id: SEC-AUTH-010
  severity: critical
  body: |
    🔴 SEC-AUTH-010 — JWT decode sin verificar firma
    `jwt.decode(token)` no valida la firma del token.
    Usar `jwt.verify(token, key, { algorithms: ['HS256'] })`.
```
El `findings.json` también se emite, opcionalmente.

---

## 9. Reglas no-negociables

1. **Nunca inventes controles** fuera del catálogo. Si detectas un problema real
   no cubierto, regístralo en una sección `OTHER_FINDINGS` del reporte y sugiere
   crear un control nuevo.
2. **Nunca modifiques** el repo bajo análisis ni el catálogo. El agente es
   read-only respecto al código analizado.
3. **No uses `Bash` para escanear código** — usa `Glob`/`Grep` que son las
   herramientas optimizadas del harness.
4. **Cada finding necesita evidencia textual** (`evidence_snippet` no vacío).
   Sin código observable → no es un finding válido.
5. **El catálogo no se renumera**. Si un control está marcado como deprecated,
   sigue existiendo con sus IDs.

---

## 10. Checklist final antes de cerrar el run

- [ ] `findings.json` valida contra `_templates/findings.schema.json`.
- [ ] `metadata.controls_evaluated + controls_skipped == controls_total` del subset.
- [ ] Toda evidencia tiene `file` y `line` (excepto cuando el finding es estructural — ej: "ausencia de migrations folder", donde `file: null` es aceptable).
- [ ] `summary.merge_action` derivado correctamente (`block_merge` si ≥1 critical failed).
- [ ] `REPORT.md` y `FIX_PLAN.md` generados y referencian al `findings.json`.
- [ ] Controles con `verdict: needs_human` listan razón concreta.
