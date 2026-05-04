<!--
  Plantilla del FIX_PLAN. Generada desde findings.json y diseñada para que un
  agente desarrollador la consuma archivo por archivo.

  Reglas de orden:
    1. Severidad máxima del archivo (critical > high > medium > low).
    2. Cantidad de findings (más findings juntos = mejor batching).
    3. Dependencias entre fixes (depende de → primero).

  Convención: cada fix tiene un `finding_id` que mapea 1:1 a findings.json.
  Severidades: 🔴 critical · 🟠 high · 🟡 medium · ⚪ low · ℹ️ info
-->

# Fix Plan — {{ metadata.repo }} @ `{{ metadata.commit }}`

**Generado:** {{ metadata.generated_at }} · **Checklist:** v{{ metadata.checklist_version }}
**Total de fixes:** {{ total_fixes }} en {{ total_files }} archivo(s)
**Fuente:** [`findings.json`](./findings.json) · **Reporte humano:** [`REPORT.md`](./REPORT.md)

---

## Cómo consumir este documento (para agente desarrollador)

1. Trabajar **un archivo a la vez**, en el orden listado en "Orden recomendado".
2. Dentro de cada archivo, aplicar fixes en el orden dado (resuelve dependencias internas).
3. Antes de aplicar un fix, comprobar que sus `Depende de` están aplicados.
4. Tras cada archivo: ejecutar la **Verificación** de cada fix antes de pasar al siguiente.
5. Si un patch sugerido no aplica limpio, leer el `evidence_snippet` en `findings.json` y reescribir manualmente; no improvisar fuera del cambio descrito.
6. Crear un commit por archivo (o por fix si son grandes) con mensaje:
   `fix({{ category }}): <short_title> [<finding_id>]`

---

## Orden recomendado

| # | Archivo | Findings | Severidad máxima | Esfuerzo estimado |
|---|---|---|---|---|
{{ for f in file_order }}
| {{ f.idx }} | [`{{ f.path }}`](#{{ f.anchor }}) | {{ f.count }} ({{ f.severity_breakdown }}) | {{ f.max_severity_icon }} {{ f.max_severity }} | {{ f.estimate }} |
{{ end }}

---

{{ for file in files }}

## `{{ file.path }}` {#{{ file.anchor }}}

**Findings en este archivo:** {{ file.count }} · **Severidad máxima:** {{ file.max_severity_icon }} {{ file.max_severity }}

{{ for fix in file.fixes }}

### Fix {{ fix.idx }} — `{{ fix.control_id }}` {{ fix.severity_icon }} {{ fix.severity }}

**`finding_id`:** `{{ fix.finding_id }}`
**Línea(s):** {{ fix.line }}{{ "–" + fix.line_end if fix.line_end and fix.line_end != fix.line else "" }}
**Complejidad:** {{ fix.fix_complexity }} · **Tipo:** {{ fix.fix_kind }}
{{ if fix.depends_on }}**Depende de:** {{ fix.depends_on | join(", ") }}{{ end }}

**Problema:**
```{{ fix.lang or "" }}
{{ fix.evidence_snippet }}
```

{{ fix.explanation }}

**Cambio propuesto:**

{{ if fix.diff_suggestion }}
```diff
{{ fix.diff_suggestion.patch }}
```
{{ else }}
{{ fix.suggestion }}
{{ end }}

**Verificación:** {{ fix.verification }}

---
{{ end }}

{{ end }}

{{ if cross_file_fixes }}

## Fixes cross-file

> Cambios que tocan múltiples archivos como una unidad lógica (ej: añadir una middleware
> y registrarlo en N rutas). Aplicar como un solo commit.

{{ for cross in cross_file_fixes }}

### `{{ cross.theme_id }}` — {{ cross.title }}

**Archivos afectados:** {{ cross.files | join(", ") }}
**Findings agrupados:** {{ cross.finding_ids | join(", ") }}
**Severidad:** {{ cross.severity_icon }} {{ cross.severity }} · **Complejidad:** {{ cross.fix_complexity }}

**Descripción del cambio:**
{{ cross.description }}

**Pasos:**
{{ for step in cross.steps }}
{{ step.idx }}. {{ step.text }}
{{ end }}

**Verificación:** {{ cross.verification }}

---
{{ end }}
{{ end }}

## Resumen post-aplicación

Tras aplicar todos los fixes de este plan:

- Findings esperados resueltos: {{ total_fixes }}
- Re-correr el agente auditor en modo `targeted-scan` con los IDs:
  ```
  {{ all_control_ids | join(", ") }}
  ```
  para verificar que el nuevo `findings.json` no contiene los `finding_id` originales (estado: `fixed`).

---

*Plan generado desde [`findings.json`](./findings.json) · checklist-v2 v{{ metadata.checklist_version }}*
