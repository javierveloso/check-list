<!--
  Plantilla del reporte humano. Variables entre {{ }} las completa el agente
  desde findings.json. Mantener la estructura — el orden de secciones es parte
  del contrato de salida.

  Severidades: 🔴 critical · 🟠 high · 🟡 medium · ⚪ low · ℹ️ info
-->

# Code Review Report — {{ metadata.repo }}

**Stack:** {{ stack_summary }}
**Commit:** `{{ metadata.commit }}` · **Branch:** `{{ metadata.branch }}`
**Fecha:** {{ metadata.generated_at }} · **Checklist:** v{{ metadata.checklist_version }}
**Modo:** `{{ metadata.mode }}` · **Controles:** {{ metadata.controls_evaluated }} / {{ metadata.controls_total }} (en scope: {{ metadata.controls_in_scope }})
**Agentes:** {{ metadata.agents | join(", ") }}

> **Artefactos relacionados:**
> - [`findings.json`](./findings.json) — fuente machine-readable de este reporte.
> - [`FIX_PLAN.md`](./FIX_PLAN.md) — guía de fixes agrupada por archivo, para agente desarrollador.

---

## Executive Summary

| Veredicto | Controles |
|---|---|
| ✅ PASSED | {{ summary.by_verdict.passed }} |
| ❌ FAILED | {{ summary.by_verdict.failed }} |
| ⏭️ N/A | {{ summary.by_verdict.na }} |
| 🤔 NEEDS_HUMAN | {{ summary.by_verdict.needs_human }} |
| **Total evaluados** | **{{ metadata.controls_evaluated }}** |

| Severidad (fallos) | Acción requerida | Controles |
|---|---|---|
| 🔴 Critical | **BLOCK_MERGE** | {{ summary.by_severity_failed.critical }} |
| 🟠 High | REQUEST_CHANGES | {{ summary.by_severity_failed.high }} |
| 🟡 Medium | COMMENT_STRONG | {{ summary.by_severity_failed.medium }} |
| ⚪ Low | COMMENT_NIT | {{ summary.by_severity_failed.low }} |
| ℹ️ Info | COMMENT_INFO | {{ summary.by_severity_failed.info }} |

> **Veredicto general: {{ verdict_icon }} {{ summary.merge_action | upper }}**
>
> {{ verdict_paragraph }}

---

## Top Findings — BLOCK_MERGE

| ID | Título | Archivo(s) |
|---|---|---|
{{ for f in top_critical_findings }}
| `{{ f.control_id }}` | {{ f.short_title }} | {{ f.files_summary }} |
{{ end }}

---

## 🔴 BLOCK_MERGE — Fallos Críticos

{{ for f in findings_critical }}

### `{{ f.control_id }}` — {{ f.short_title }}

**Archivo:** [`{{ f.file }}`]({{ f.file }}{{ "#L" + f.line if f.line else "" }}){{ " · **Línea:** " + f.line if f.line else "" }}
**Confidence:** {{ f.confidence }} · **Fix:** {{ f.fix_complexity }} ({{ f.fix_kind }})

**Evidencia:**
```{{ f.lang or "" }}
{{ f.evidence_snippet }}
```

**Explicación:** {{ f.explanation }}

**Sugerencia:**
{{ f.suggestion }}

{{ if f.diff_suggestion }}
**Patch sugerido:**
```diff
{{ f.diff_suggestion.patch }}
```
{{ end }}

{{ if f.related_findings }}
**Relacionados:** {{ f.related_findings | join(", ") }}
{{ end }}

---
{{ end }}

## 🟠 REQUEST_CHANGES — Fallos de Severidad Alta

{{ for category in findings_high_by_category }}

### {{ category.name }}

{{ for f in category.findings }}
#### `{{ f.control_id }}` — {{ f.short_title }}
**Archivo:** [`{{ f.file }}`]({{ f.file }}{{ "#L" + f.line if f.line else "" }})
**Evidencia:** {{ f.evidence_snippet | inline }}
**Sugerencia:** {{ f.suggestion }}

{{ end }}
{{ end }}

---

## 🟡 COMMENT_STRONG — Observaciones de Severidad Media

{{ for category in findings_medium_by_category }}

### {{ category.name }}

{{ for f in category.findings }}
- **`{{ f.control_id }}`** — {{ f.short_title }}. {{ f.suggestion | inline }}
{{ end }}
{{ end }}

---

## ⚪ COMMENT_NIT — Mejoras Menores

{{ for f in findings_low }}
- **`{{ f.control_id }}`** ([`{{ f.file }}`]({{ f.file }})) — {{ f.short_title }}. {{ f.suggestion | inline }}
{{ end }}

---

## Hallazgos por archivo

| Archivo | Hallazgos | Severidad máxima |
|---|---|---|
{{ for entry in findings_by_file }}
| [`{{ entry.file }}`]({{ entry.file }}) | {{ entry.control_ids | join(", ") }} | {{ entry.max_severity_icon }} {{ entry.max_severity }} |
{{ end }}

> **Tip:** para fixes, ver [`FIX_PLAN.md`](./FIX_PLAN.md) — está agrupado por este mismo eje.

---

## ✅ Controls Passed

| ID | Título | Verificación |
|---|---|---|
{{ for p in passed_controls }}
| [`{{ p.control_id }}`]({{ p.control_link }}) | {{ p.title }} | {{ p.evidence }} |
{{ end }}

---

## ⏭️ Controls N/A

| ID | Título | Razón |
|---|---|---|
{{ for n in na_controls }}
| `{{ n.control_id }}` | {{ n.title }} | {{ n.reason }} |
{{ end }}

---

## 🤔 Needs Human Review

| ID | Archivo | Razón |
|---|---|---|
{{ for h in needs_human }}
| `{{ h.control_id }}` | {{ h.file or "—" }} | {{ h.reason }} |
{{ end }}

---

## Category Summary

| Categoría | Evaluados | Pasados | Fallados | N/A | Needs Human | Pass% |
|---|---|---|---|---|---|---|
{{ for cat in category_summary }}
| {{ cat.name }} | {{ cat.evaluated }} | {{ cat.passed }} | {{ cat.failed }} | {{ cat.na }} | {{ cat.needs_human }} | {{ cat.pass_pct }}% |
{{ end }}
| **TOTAL** | **{{ summary.totals.evaluated }}** | **{{ summary.totals.passed }}** | **{{ summary.totals.failed }}** | **{{ summary.totals.na }}** | **{{ summary.totals.needs_human }}** | **{{ summary.totals.pass_pct }}%** |

{{ if other_findings }}
---

## 🆕 Other Findings — Fuera del catálogo

> Hallazgos reales detectados por el agente que **no corresponden** a ningún control existente.
> Considerar crear los controles propuestos en una próxima versión del catálogo.

{{ for o in other_findings }}
### {{ o.title }}
- **Archivo:** {{ o.file or "—" }}{{ " · **Línea:** " + o.line if o.line else "" }}
- **Severidad sugerida:** {{ o.severity_suggested }}
- **Control propuesto:** `{{ o.proposed_control_id or "TBD" }}`
- **Evidencia:** `{{ o.evidence_snippet | inline }}`
- **Razón:** {{ o.rationale }}

{{ end }}
{{ end }}

---

## Roadmap

Para el plan de remediación detallado **por archivo**, ver [`FIX_PLAN.md`](./FIX_PLAN.md).

Resumen del orden recomendado:
1. **Sprint 1** — todos los `🔴 critical` ({{ summary.by_severity_failed.critical }} controles).
2. **Sprint 2** — todos los `🟠 high` ({{ summary.by_severity_failed.high }} controles).
3. **Sprint 3** — `🟡 medium` ({{ summary.by_severity_failed.medium }}) priorizando los que comparten archivo con sprint 1/2.
4. **Backlog** — `⚪ low` ({{ summary.by_severity_failed.low }}) en limpieza continua.

---

*Reporte generado por checklist-v2 v{{ metadata.checklist_version }} · {{ metadata.generated_at }}*
*Fuente: [`findings.json`](./findings.json) · Plan de fixes: [`FIX_PLAN.md`](./FIX_PLAN.md)*
