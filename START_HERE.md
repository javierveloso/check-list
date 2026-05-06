# Code Review Agent — Guía rápida

Agente LLM que audita repositorios contra **614 controles** en 14 categorías: seguridad, API, calidad de código, testing, rendimiento, privacidad, IA/LLM, accesibilidad, observabilidad y más.

---

## Prerequisitos

- [Claude Code](https://docs.anthropic.com/en/claude-code) instalado
- Cuenta Anthropic activa

```bash
npm i -g @anthropic-ai/claude-code
```

---

## Cómo usar — 3 pasos

### 1. Abre esta carpeta en Claude Code

```bash
# Opción A — CLI
claude /ruta/a/checklist-v2

# Opción B — desde el directorio
cd checklist-v2
claude .

# Opción C — VS Code
# Abre esta carpeta en VS Code con la extensión Claude Code activa
```

El agente se activa automáticamente: `CLAUDE.md` le da contexto completo al abrirse.

### 2. Lanza la revisión

```
/revisar /ruta/absoluta/a/tu/repo
```

Con URL de GitHub:

```
/revisar https://github.com/org/repo
```

Sin argumento (te preguntará):

```
/revisar
```

### 3. Responde las preguntas del agente

El agente te preguntará qué tipo de revisión quieres:

```
1  Completa         → todos los controles aplicables al stack detectado
2  Críticos/Altos   → solo severity: critical + high (más rápido, enfocado en riesgos)
3  Por categorías   → tú eliges qué áreas revisar (menú de 14 opciones)
4  PR específico    → solo los archivos modificados en un Pull Request
```

Escribe el número y el agente arranca solo.

---

## Output

Los reportes se guardan en `reports/<nombre-repo>/<YYYY-MM-DD>/`:

| Archivo | Contenido |
|---|---|
| `findings.json` | Todos los hallazgos en JSON (fuente de verdad, schema validado) |
| `REPORT.md` | Resumen ejecutivo legible: severidades, veredicto, top issues |
| `FIX_PLAN.md` | Plan de correcciones ordenado por prioridad y archivo |

El veredicto final puede ser: `approve` / `comment` / `request_changes` / `block_merge`.

---

## Modos disponibles

| Modo | Cuándo usarlo |
|---|---|
| Completa | Auditoría inicial de un repo |
| Críticos/Altos | Revisión rápida antes de un deploy |
| Por categorías | Audit temático (ej: solo seguridad antes de go-live) |
| PR específico | Revisión continua en cada Pull Request |
| Multi-agente | Repos grandes (>500 archivos) — ver `_prompts/agent-coordinator.md` |

---

## Categorías del catálogo

```
 1  Seguridad (SEC)         7  IA/LLM (LLM)
 2  API REST (API)          8  Usabilidad/UX (UX)
 3  Calidad código (CODE)   9  Accesibilidad (A11Y)
 4  Testing (TEST)         10  Observabilidad (OBS)
 5  Rendimiento (PERF)     11  CI/CD y DevOps (CICD)
 6  Protección datos (DATA) 12  Arquitectura (ARCH)
                           13  Base de datos (DB)
                           14  Documentación (DOC)
```

---

## Para saber más

| Archivo | Contenido |
|---|---|
| `EXECUTION_GUIDE.md` | Workflow completo del agente (7 pasos, modos, árbol de decisión) |
| `REPORTING_GUIDE.md` | Especificación del formato de reportes y schema JSON |
| `README.md` | Visión general, estructura, versionado del catálogo |
| `_prompts/` | Prompts reutilizables para auditor, PR reviewer, fixer y coordinador |
