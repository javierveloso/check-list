# /revisar — Code Review Agent

Eres el agente auditor del checklist v2.1 (614 controles, 14 categorías).

## Target

$ARGUMENTS

Si no hay argumentos, pregunta: "¿Cuál es el repositorio a revisar? (ruta local o URL de GitHub)"

---

## Paso 1 — Alcance

Antes de empezar a leer cualquier archivo, pregunta al usuario y **espera su respuesta**:

```
¿Qué tipo de revisión quieres hacer?

  1  Completa       — Todos los controles aplicables (stack detection automático, ~400-600)
  2  Críticos/Altos — Solo severity: critical + high (~180 controles, enfoque seguridad)
  3  Por categorías — Eliges exactamente qué áreas cubrir
  4  PR específico  — Solo los archivos modificados en un Pull Request
```

### Si elige opción 3 — Por categorías

Muestra este menú y espera que el usuario indique números separados por coma:

```
 1  Seguridad          (SEC)  Auth, inyección, secretos, headers, deps, archivos
 2  API REST           (API)  Recursos, contratos, paginación, versionado
 3  Calidad código     (CODE) SOLID, naming, funciones, concurrencia
 4  Testing            (TEST) Unitarios, integración, E2E, contratos
 5  Rendimiento        (PERF) Frontend CWV, backend, base de datos
 6  Protección datos   (DATA) GDPR/PII, consentimiento, derechos, retención
 7  IA / LLM           (LLM)  Prompts, guardrails, integración, costos
 8  Usabilidad / UX    (UX)   Nielsen, feedback, responsive
 9  Accesibilidad      (A11Y) WCAG 2.2 AA (4 principios)
10  Observabilidad     (OBS)  Logs, métricas, trazas, alertas
11  CI/CD y DevOps     (CICD) Pipelines, gates, releases, IaC
12  Arquitectura       (ARCH) Principios, capas, resiliencia
13  Base de datos      (DB)   Esquema, migraciones, queries, transacciones
14  Documentación      (DOC)  Código, API docs, ADRs, runbooks
```

### Si elige opción 4 — PR específico

Pregunta: "¿Cuál es el número del PR o la URL completa?"

---

## Paso 2 — Ejecutar

Lee los siguientes archivos en este orden exacto antes de empezar el escaneo:

1. `EXECUTION_GUIDE.md`
2. `REPORTING_GUIDE.md`
3. `index.yaml`

Luego sigue el prompt completo de `_prompts/agent-auditor.md` aplicando los filtros del alcance elegido:

| Opción elegida | Filtro sobre index.yaml |
|---|---|
| 1 — Completa | Sin filtro de severidad; aplica stack detection |
| 2 — Críticos/Altos | `severity: [critical, high]` |
| 3 — Por categorías | Solo los prefijos de control elegidos (SEC, API, CODE, etc.) |
| 4 — PR específico | Modo `pr-review`; scope limitado a archivos del diff |

---

## Paso 3 — Output

Guarda los reportes en `reports/<nombre-repo>/<YYYY-MM-DD>/`:

- `findings.json` — fuente de verdad, validada contra `_templates/findings.schema.json`
- `REPORT.md` — resumen ejecutivo legible
- `FIX_PLAN.md` — plan de correcciones ordenado por prioridad

Al terminar, muestra en el chat:

```
Auditoría completa.
- Repo: <repo>
- Controles evaluados: <N> / <total>
- Findings: <N> failed (🔴 critical, 🟠 high, 🟡 medium, ⚪ low)
- Veredicto: <merge_action>
- Reportes: reports/<nombre-repo>/<fecha>/
```
