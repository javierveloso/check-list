# Reporting Guide — Formato de salida del agente

> Define qué archivos genera el agente, su estructura, y las reglas para
> derivar unos de otros. Para el flujo de ejecución, ver [EXECUTION_GUIDE.md](EXECUTION_GUIDE.md).

---

## 1. Artefactos de salida

Por cada run de auditoría, el agente produce:

| Archivo | Audiencia | Propósito | Plantilla |
|---|---|---|---|
| **`findings.json`** | Máquina (otros agentes) | Fuente única de verdad. Schema estable. | [_templates/findings.schema.json](_templates/findings.schema.json) |
| **`REPORT.md`** | Humano (revisor / lead) | Síntesis ejecutiva + detalle navegable. | [_templates/REPORT.md.tpl](_templates/REPORT.md.tpl) |
| **`FIX_PLAN.md`** | Agente desarrollador | Cambios accionables agrupados por archivo. | [_templates/fix-plan.md.tpl](_templates/fix-plan.md.tpl) |

**Carpeta sugerida:** `reports/<repo-name>/<YYYY-MM-DD>/` con los 3 archivos juntos.

**Multi-agente:** cada agente emite `fragments/<agent-id>.json`. El coordinador
consolida los fragments en el `findings.json` final y genera `REPORT.md` +
`FIX_PLAN.md`.

---

## 2. `findings.json` — schema

El archivo completo es JSON. Validar contra
[_templates/findings.schema.json](_templates/findings.schema.json) (JSON Schema 2020-12).

### 2.1 Estructura

```jsonc
{
  "$schema": "../../_templates/findings.schema.json",
  "metadata": { /* §2.2 */ },
  "summary":  { /* §2.3 */ },
  "findings": [ /* §2.4 — array de Finding */ ],
  "passed_controls":   [ /* §2.5 */ ],
  "na_controls":       [ /* §2.6 */ ],
  "needs_human":       [ /* §2.7 */ ],
  "other_findings":    [ /* §2.8 — opcional */ ]
}
```

### 2.2 `metadata`

```json
{
  "repo": "Grant-Thornton-Chile/control-gestion-gt-backend-express",
  "commit": "a1b2c3d",
  "branch": "main",
  "checklist_version": "2.1.0",
  "generated_at": "2026-05-03T12:34:56Z",
  "mode": "full-audit",
  "stack_signal": {
    "languages": ["typescript"],
    "frameworks": ["express", "typeorm"],
    "areas": {
      "has_backend": true, "has_frontend": false, "has_api": true,
      "has_db": true, "has_iac": false, "has_ci": true,
      "has_llm": false, "has_mobile": false, "has_data_pipelines": false
    },
    "deploy_targets": ["docker", "azure-app-service"]
  },
  "controls_total": 614,
  "controls_in_scope": 388,
  "controls_evaluated": 388,
  "controls_skipped": [],
  "agents": ["BE-1", "BE-2", "BE-3"]
}
```

**Reglas:**
- `mode` ∈ `{full-audit, pr-review, targeted-scan}`.
- `controls_in_scope`: conteo tras filtrar por `applies_to` y `stack_signal`.
- `controls_evaluated`: cuántos efectivamente se ejecutaron (pueden saltarse por presupuesto).
- `controls_skipped`: lista de IDs no evaluados, con razón si conviene.

### 2.3 `summary`

```json
{
  "by_verdict":  { "passed": 133, "failed": 166, "na": 89 },
  "by_severity_failed": {
    "critical": 16, "high": 57, "medium": 64, "low": 29, "info": 0
  },
  "by_category_failed": {
    "SEC": 37, "API": 12, "ARCH": 8, "DB": 19, "PERF": 9,
    "CODE": 11, "TEST": 6, "DATA": 22, "OBS": 14, "CICD": 18,
    "DOC": 10, "LLM": 0, "UX": 0, "A11Y": 0
  },
  "merge_action": "block_merge"
}
```

**Cómo derivar `merge_action`:**

| Condición | `merge_action` |
|---|---|
| ≥1 finding con `severity: critical, verdict: failed` | `block_merge` |
| ≥1 finding con `severity: high, verdict: failed` | `request_changes` |
| Solo `medium`/`low`/`info` | `comment` |
| Cero findings failed | `approve` |

### 2.4 `findings[]` — un Finding

```jsonc
{
  // Hash estable: sha256(control_id + file + line + first 80 chars de evidence_snippet)
  "finding_id": "f1a2b3c4d5e6...",
  "control_id": "SEC-AUTH-002",
  "severity": "critical",                 // del catálogo, no editable
  "verdict": "failed",                    // failed | needs_human
  "confidence": "high",                   // high | medium | low
  "file": "docker-compose.yml",
  "line": 7,
  "line_end": 7,                          // opcional, para rangos multi-línea
  "evidence_snippet": "SECRET_KEY=secret",
  "explanation": "El secreto JWT 'secret' aparece literalmente en el repositorio. Cualquier token puede forjarse con este valor.",
  "suggestion": "Generar un secreto aleatorio: `openssl rand -base64 32`. Mover a Azure Key Vault y referenciar via Managed Identity.",
  "fix_complexity": "small",              // trivial | small | medium | large
  "fix_kind": "config",                   // config | code | dependency | infra | docs | process
  "diff_suggestion": null,                // opcional, ver §2.4.1
  "related_findings": [],                 // otros finding_id agrupables
  "tags": ["cwe-798", "supply-chain"],
  "owners": []                            // opcional: paths/CODEOWNERS-style
}
```

#### 2.4.1 `diff_suggestion` (opcional pero recomendado cuando aplica)

```jsonc
{
  "format": "unified",
  "patch": "--- a/docker-compose.yml\n+++ b/docker-compose.yml\n@@ -7 +7 @@\n-      - SECRET_KEY=secret\n+      - SECRET_KEY=${SECRET_KEY}\n"
}
```

Reglas:
- Solo emitir si el agente está razonablemente seguro de que el patch es correcto.
- El patch debe ser sintácticamente válido y aplicable con `git apply`.
- Para fixes que requieren contexto que no se vio (refactors grandes), dejar `diff_suggestion: null` y describir en `suggestion`.

#### 2.4.2 Reglas de severidad y verdict

- `severity` se hereda **inmutable** del catálogo. El agente no puede subirla ni bajarla.
- `verdict: failed` ⟹ pertenece a `findings[]`.
- `verdict: passed` ⟹ pertenece a `passed_controls[]` (no a `findings[]`).
- `verdict: na` ⟹ pertenece a `na_controls[]`.
- `verdict: needs_human` ⟹ pertenece a `needs_human[]`.

### 2.5 `passed_controls[]`

```json
[
  {
    "control_id": "AUTH-AUTHN-010",
    "evidence": "bcrypt.hash() con salt rounds configurado en src/users/users.service.ts:45"
  }
]
```

Solo registrar passes que tengan evidencia comprobable. No inflar con "asumimos OK".

### 2.6 `na_controls[]`

```json
[
  {
    "control_id": "LLM-PROMPT-001",
    "reason": "stack_signal.has_llm == false (ningún SDK de LLM en package.json)"
  }
]
```

### 2.7 `needs_human[]`

```json
[
  {
    "control_id": "ARCH-LAYER-002",
    "file": "src/orders/order.service.ts",
    "reason": "El control requiere juicio sobre cohesión semántica que el agente no puede determinar mecánicamente. El archivo tiene 600 líneas y mezcla lógica de checkout, fulfillment y notificaciones — recomendado revisión humana."
  }
]
```

### 2.8 `other_findings[]` (opcional)

Para hallazgos reales que el agente detectó pero **no están** en el catálogo.
Sugerir crear un control nuevo.

```json
[
  {
    "title": "Uso de `child_process.exec` con string interpolado en tarea cron",
    "file": "src/cron/cleanup.job.ts",
    "line": 23,
    "evidence_snippet": "exec(`rm -rf /tmp/${userInput}`)",
    "severity_suggested": "critical",
    "rationale": "Inyección de comando vía cron job. Posible control nuevo: SEC-INPUT-022 (shell injection en jobs background).",
    "proposed_control_id": "SEC-INPUT-022"
  }
]
```

---

## 3. `REPORT.md` — formato humano

Generado a partir de `findings.json`. Reusa el patrón ya validado en
[reports/backend/REPORT_BACKEND.md](reports/backend/REPORT_BACKEND.md).

**Secciones obligatorias** (en este orden):

1. **Header** — repo, stack, fecha, versión del checklist, modo, **enlaces a `findings.json` y `FIX_PLAN.md`**.
2. **Executive Summary** — tabla de `by_verdict` + tabla de `by_severity_failed` + veredicto general (`merge_action`) con 1 párrafo de contexto.
3. **Top Findings — BLOCK_MERGE** — tabla resumen con 5–12 críticos.
4. **Detail por severidad** (BLOCK_MERGE → REQUEST_CHANGES → COMMENT_STRONG → COMMENT_NIT) — cada finding con: ID, archivo(s), evidencia, explicación, sugerencia.
5. **Hallazgos por archivo** — tabla `archivo → [control_ids con severidad]`. Facilita revisión por archivo.
6. **Controls Passed** — tabla compacta.
7. **Controls N/A** — tabla compacta con razón.
8. **Needs Human** — tabla compacta con razón.
9. **Category Summary** — agregado por categoría (passed/failed/na/pass%).
10. **Roadmap resumido** — referencia al `FIX_PLAN.md`. No duplicar contenido aquí.

**Reglas:**
- Severidades con icono visual: 🔴 critical · 🟠 high · 🟡 medium · ⚪ low · ℹ️ info.
- Cada `control_id` es un link al archivo del catálogo.
- Cada `file:line` en evidencia se renderiza como link markdown a la ruta relativa.

---

## 4. `FIX_PLAN.md` — formato para agente desarrollador

Generado a partir de `findings.json`. Diseñado para que un agente codificador
pueda iterar archivo por archivo.

**Estructura:**

1. **Header** — repo, commit, total de fixes, link al `findings.json`.
2. **Orden recomendado** — lista numerada de archivos, ordenada por:
   - Severidad máxima en el archivo (critical antes que high).
   - Cantidad de findings (más findings juntos primero, mejor batching).
   - Dependencias entre fixes (si fix B depende de fix A, archivo de A primero).
3. **Una sección por archivo:**
   - Path del archivo como header.
   - Lista de fixes; por cada fix:
     - `finding_id` + `control_id` + severity + `fix_complexity`.
     - Línea(s).
     - Patch sugerido (si `diff_suggestion` existe) o descripción del cambio.
     - Dependencias (otros `finding_id` que deben aplicarse antes).
     - Verificación: cómo validar (test a correr, comando, observación).

**Reglas:**
- Si un finding no tiene patch concreto, describir el cambio en prosa imperativa.
- Agrupar findings del mismo control en el mismo archivo si son aplicaciones del mismo fix (ej: 5 endpoints con falta de auth → un solo bloque con la lista de líneas).
- No repetir información ya en `REPORT.md` — este archivo es **acción**, no diagnóstico.

---

## 5. Reglas de derivación entre artefactos

```
                    ┌──────────────────┐
                    │  findings.json   │  ← single source of truth
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐   ┌──────────┐   ┌────────────┐
        │REPORT.md │   │FIX_PLAN  │   │PR comments │
        │(humano)  │   │(dev agt) │   │(pr-review) │
        └──────────┘   └──────────┘   └────────────┘
```

- **`findings.json` es la fuente.** Si los `.md` divergen del JSON, gana el JSON.
- **Re-runs:** comparar el `findings.json` nuevo con el anterior por `finding_id` para detectar:
  - `fixed` (existía antes, no aparece ahora).
  - `reopened` (existía, fue fixed, vuelve a aparecer).
  - `new` (aparece por primera vez).
- **`finding_id` es estable** por construcción (hash del control_id + file + line + 80 chars de evidence). Si cambia el archivo o la línea, es un finding nuevo.

---

## 6. Reglas para `pr-review` mode

En lugar de `REPORT.md` global, el agente puede emitir **comentarios por línea**:

```yaml
- file: src/auth/jwt.service.ts
  line: 42
  side: RIGHT          # GitHub PR convention
  control_id: SEC-AUTH-010
  severity: critical
  body: |
    🔴 **SEC-AUTH-010 — JWT decode sin verificar firma**

    `jwt.decode(token)` no valida la firma del token, solo decodifica el payload.
    Cualquier atacante puede falsificar tokens cambiando el payload.

    **Fix sugerido:**
    ```ts
    jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] })
    ```

    Ver catálogo: [SEC-AUTH-010](checklist-v2/01-seguridad/01-autenticacion.md#sec-auth-010)
```

El `findings.json` también se emite en este modo, con `metadata.mode: pr-review`.

---

## 7. Validación

Antes de cerrar un run, el agente DEBE:

1. Validar `findings.json` contra `_templates/findings.schema.json` (usar `ajv` o `jsonschema` por línea de comandos en hooks de CI, o un check estructural inline).
2. Verificar que cada `finding_id` es único en el archivo.
3. Verificar que cada `control_id` referenciado existe en `index.yaml`.
4. Verificar que `summary` se deriva correctamente de `findings[]`.
5. Verificar que `merge_action` es coherente con la peor severidad failed.

Si alguna validación falla, registrar el error en metadata y NO publicar el reporte.
