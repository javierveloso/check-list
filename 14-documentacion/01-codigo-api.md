# 14 · Documentación · Código y API

> Docstrings, README, API docs, changelog.

---

## A. Documentación en el código

#### `DOC-CODE-001` — API pública documentada
**Severidad:** medium · **Aplica a:** all

Cada símbolo público (función, clase, módulo) tiene docstring que explica qué
hace y por qué.

(Ver `CODE-DOC-001`.)

**Dónde buscar:** `**/*.{ts,js,py,go,java}`, `**/src/**`, `**/lib/**`
**Patrones:**
- `^export\s+(async\s+)?function\s+\w+\s*\(`     # funciones exportadas TS/JS sin JSDoc previo
- `^export\s+class\s+\w+`     # clases exportadas (chequear JSDoc encima)
- `^def\s+[a-z_][a-z0-9_]*\s*\(`     # funciones públicas Python (sin underscore)
- `^class\s+[A-Z]\w+`     # clases Python públicas
- `^func\s+[A-Z]\w+\s*\(`     # funciones exportadas Go
- `^\s*public\s+(static\s+)?[\w<>\[\]]+\s+\w+\s*\(`     # métodos públicos Java
- `/\*\*[\s\S]*?\*/`     # JSDoc presente (multilínea — verificar proporción)
**Señal de N/A:** repo sin código fuente (solo docs/config) o todo el código es privado (sin API exportable).

---

#### `DOC-CODE-002` — Tipos y contratos explícitos
**Severidad:** medium · **Aplica a:** all

Type hints / tipos estáticos son la primera línea de documentación.

(Ver `CODE-TYPE-001`.)

**Dónde buscar:** `**/*.{ts,py}`, `tsconfig.json`, `pyproject.toml`, `mypy.ini`
**Patrones:**
- `:\s*any\b`     # uso de any en TS
- `"strict"\s*:\s*false`     # tsconfig sin strict mode
- `^def\s+\w+\([^)]*\)\s*:`     # def Python sin -> return type
- `# type:\s*ignore`     # supresión de tipo
- `\bObject\b|\bDictionary<string,\s*object>`     # tipos genéricos sin contrato
**Señal de N/A:** lenguaje sin sistema de tipos opcional (Ruby/Lua puro) o repo sin código fuente.

---

#### `DOC-CODE-003` — Comentarios explican el "por qué"
**Severidad:** low · **Aplica a:** all

(Ver `CODE-DOC-002`.)

**Dónde buscar:** `**/*.{ts,js,py,go,java}`
**Patrones:**
- `(TODO|FIXME|XXX|HACK)\b(?!\s*[\(:#])`     # marcadores sin issue ID asociado
- `//\s*(increment|set|return|loop)`     # comentarios que repiten el código
- `@deprecated(?!\s*[-:])`     # @deprecated sin razón ni alternativa
- `/\*\s*\*/|//\s*$`     # comentarios vacíos
**Señal de N/A:** repo sin código fuente.

---

## B. README y docs del repo

#### `DOC-README-001` — README con lo mínimo imprescindible
**Severidad:** high · **Aplica a:** all

El README permite a alguien nuevo entender qué es el proyecto, cómo correrlo,
y dónde encontrar más.

**Dónde buscar:** `README*`, `readme*`, `docs/index.md`
**Patrones:**
- `^#\s+(Project Name|TODO|My Project)\b`     # README con título de template
- `<!--\s*(placeholder|TODO|description)`     # placeholders sin reemplazar
- `lorem ipsum`     # contenido dummy
- `^##\s+(Installation|Usage|Getting Started)`     # presencia de secciones clave
- `npm (install|run|start)|yarn|pnpm|pip install|poetry|make`     # instrucciones de setup
- `## (License|Licencia)|MIT|Apache`     # sección de licencia
**Señal de N/A:** no existe README ni `docs/index.md` (repo sin punto de entrada — el control falla, no es N/A) o repo es un mirror/fork sin docs propias declaradas.

**Verificar:**
- [ ] Título y descripción corta del propósito.
- [ ] Requisitos (versiones, servicios externos).
- [ ] Cómo correr local (1-command idealmente).
- [ ] Cómo correr tests.
- [ ] Cómo desplegar / link a docs de deploy.
- [ ] Link a documentación más extensa si existe.
- [ ] Licencia y cómo contribuir.

---

#### `DOC-README-002` — .env.example y configuración documentada
**Severidad:** high · **Aplica a:** all

Las variables de entorno están listadas con descripción.

**Dónde buscar:** `.env.example`, `.env.sample`, `.env.template`, `**/*.{ts,js,py,go}`, `README*`, `docs/**`
**Patrones:**
- `process\.env\.[A-Z_]+`     # vars usadas en TS/JS (cruzar con .env.example)
- `os\.environ(\.get)?\[?["']([A-Z_]+)`     # vars usadas en Python
- `os\.Getenv\("([A-Z_]+)`     # vars usadas en Go
- `^[A-Z][A-Z0-9_]+=`     # entradas en .env.example
- `^#\s*\w+`     # comentarios encima de cada variable (descripción)
**Señal de N/A:** la app no consume variables de entorno (todas las configs son code-defaults o constantes en archivos de config commiteados sin secretos).

**Verificar:**
- [ ] `.env.example` con todas las variables necesarias.
- [ ] Cada variable tiene comentario de para qué sirve y ejemplo de valor.
- [ ] Se separan las obligatorias de las opcionales.
- [ ] Se indica qué secretos deben venir del vault.

---

#### `DOC-README-003` — Estructura del repo explicada
**Severidad:** medium · **Aplica a:** all

El repo tiene sección que explica la estructura de carpetas a alto nivel.

**Dónde buscar:** `README*`, `CONTRIBUTING*`, `docs/structure*`, `docs/architecture*`
**Patrones:**
- `^##?\s*(Estructura|Structure|Project Layout|Folder|Directory)`     # sección dedicada
- `^\s*[├└│─]`     # diagrama de árbol ASCII de carpetas
- `^\s*[-*]\s+\`?(src|lib|app|packages)/`     # listado de carpetas con descripción
- `packages/\*|workspaces`     # monorepo declarado (cada paquete debería tener README)
**Señal de N/A:** repo de un solo archivo o estructura trivial (`<10` archivos top-level sin subcarpetas).

**Verificar:**
- [ ] Mapa de carpetas principales con explicación de 1 línea.
- [ ] Si hay monorepo, cada paquete tiene su propio README.

---

## C. API docs

#### `DOC-API-001` — OpenAPI / schema fuente de verdad
**Severidad:** high · **Aplica a:** api

(Ver `API-DOC-001`.)

**Dónde buscar:** `**/openapi*.{yaml,json}`, `**/swagger*.{yaml,json}`, `**/api-spec*`, `**/*.{ts,js,py,go}`
**Patrones:**
- `openapi:\s*3\.|swagger:\s*"?2\.0`     # versión del spec
- `@(Get|Post|Put|Delete|Patch)\s*\(|app\.(get|post|put|delete)\(|router\.(get|post|put|delete)\(`     # rutas REST en código
- `@(api|swagger|openapi)\b`     # decoradores de generación de spec
- `paths:\s*$`     # sección paths del spec
**Señal de N/A:** no hay endpoints públicos documentables (no es servicio API / es CLI / es lib / es worker puro sin HTTP).

---

#### `DOC-API-002` — Ejemplos completos por endpoint
**Severidad:** medium · **Aplica a:** api

(Ver `API-DOC-002`.)

**Dónde buscar:** `**/openapi*.{yaml,json}`, `**/swagger*.{yaml,json}`, `docs/api/**`
**Patrones:**
- `examples?:\s*$`     # claves examples en spec
- `requestBody:\s*[\s\S]*?example`     # ejemplo en request
- `200:\s*[\s\S]*?example`     # ejemplo en response
- `curl\s+(-X\s+)?(GET|POST|PUT|DELETE)`     # ejemplos curl en docs
**Señal de N/A:** no hay endpoints públicos (no es servicio API).

---

#### `DOC-API-003` — Errores comunes documentados con ejemplos
**Severidad:** medium · **Aplica a:** api

Cada endpoint documenta los errores 4xx y 5xx que puede devolver, con ejemplo.

**Dónde buscar:** `**/openapi*.{yaml,json}`, `docs/errors*`, `docs/api/**`
**Patrones:**
- `"4\d\d":|"5\d\d":|^\s*4\d\d:|^\s*5\d\d:`     # responses 4xx/5xx en spec
- `\$ref:.*error|ErrorResponse|ProblemDetails`     # schema de error reusado
- `application/problem\+json`     # RFC 7807
- `error_code|errorCode|code:\s*["']?[A-Z_]+`     # catálogo de códigos
**Señal de N/A:** no hay endpoints públicos (no es servicio API).

**Verificar:**
- [ ] `responses` en OpenAPI incluyen los errores relevantes.
- [ ] Estructura de error documentada en un solo lugar, referenciada desde cada endpoint.
- [ ] Relación código de error → razón → acción documentada.

---

#### `DOC-API-004` — Guías de uso más allá de la referencia
**Severidad:** medium · **Aplica a:** api

Además de la referencia (qué hace cada endpoint), hay guías (cómo hacer X).

**Dónde buscar:** `docs/guides/**`, `docs/tutorials/**`, `docs/how-to/**`, `docs/quickstart*`, `**/*.md`
**Patrones:**
- `^#\s+(Quickstart|Tutorial|Hello World|Getting Started|Guía|Guide)`     # secciones de tutorial
- `^##?\s+How\s+to\s+`     # guías how-to
- `\`\`\`(bash|curl|js|ts|python|go|java)`     # snippets multi-lenguaje
**Señal de N/A:** API interna sin integradores externos / no es servicio API público.

**Verificar:**
- [ ] Guías para casos de uso comunes (autenticarse, subir archivo, manejar async).
- [ ] Tutorial "hello world" para un integrador nuevo.
- [ ] Ejemplos en múltiples lenguajes si el proyecto lo amerita.

---

## D. Changelog y release notes

#### `DOC-CHANGE-001` — Changelog mantenido
**Severidad:** medium · **Aplica a:** all

Cada release tiene entrada en el changelog con cambios, breaking y migración.

**Dónde buscar:** `CHANGELOG*`, `HISTORY*`, `RELEASES*`, `docs/changelog*`
**Patrones:**
- `^##?\s*\[?\d+\.\d+\.\d+\]?`     # entradas SemVer
- `^###\s*(Added|Changed|Fixed|Removed|Deprecated|Security|Breaking)`     # secciones Keep a Changelog
- `BREAKING\s*CHANGE|⚠|breaking:`     # breaking destacados
- `#\d+|PR\s*#\d+|\(#\d+\)`     # links a PRs/issues
- `\[Unreleased\]`     # sección Unreleased
**Señal de N/A:** proyecto sin releases versionados (siempre HEAD, app interna sin versionado) y sin changelog declarado en convenciones del equipo.

**Verificar:**
- [ ] `CHANGELOG.md` estilo Keep a Changelog o similar.
- [ ] Versiones siguen SemVer.
- [ ] Breaking changes destacados.
- [ ] Links a PRs/issues para contexto.

---

#### `DOC-CHANGE-002` — Release notes para usuarios
**Severidad:** medium · **Aplica a:** product · content

Además del changelog técnico, hay comunicación al usuario final.

**Dónde buscar:** `docs/releases/**`, `docs/whats-new*`, `**/*.md`
**Patrones:**
- *(sin patrones mecánicos — revisión humana / contenido)*
**Señal de N/A:** producto sin usuarios finales (lib interna, infra) o sin frontend con UI de "What's new".

**Verificar:**
- [ ] "What's new" accesible en el producto.
- [ ] Breaking changes comunicados con anticipación.
- [ ] Feature flags comunicados cuando se lanzan en GA.

---

## E. Onboarding y docs operacionales

#### `DOC-ON-001` — Onboarding para devs nuevos
**Severidad:** medium · **Aplica a:** process

Existe docs/checklist para que un dev nuevo sea productivo en < 1 semana.

**Dónde buscar:** `docs/onboarding*`, `CONTRIBUTING*`, `docs/dev*`, `docs/getting-started*`
**Patrones:**
- `^#\s+(Onboarding|Getting Started|Welcome|Contributing)`     # secciones dedicadas
- `^\s*-\s*\[\s*\]`     # checklists markdown
- `good\s*first\s*issue|help\s*wanted`     # labels para nuevos
- `slack|discord|teams|buddy|mentor`     # canal de apoyo
**Señal de N/A:** equipo de 1 persona o repo sin proceso de incorporación de devs externos.

**Verificar:**
- [ ] Checklist de setup (acceso, cuentas, herramientas).
- [ ] Código guía donde empezar a leer.
- [ ] "Good first issues" etiquetados.
- [ ] Canal de apoyo / buddy.

---

#### `DOC-ON-002` — Docs operacionales accesibles
**Severidad:** medium · **Aplica a:** infra · process

(Ver `OBS-RUN-001` para runbooks.)

**Dónde buscar:** `RUNBOOK*`, `OPERATIONS*`, `docs/ops/**`, `docs/release*`, `docs/deploy*`
**Patrones:**
- `^##?\s*(Release|Deploy|Rollback|Scaling|Escalation)`     # secciones operacionales
- `\brollback\b|\brevert\b`     # procedimiento de rollback
- `kubectl\s+scale|terraform|helm\s+upgrade`     # comandos de operación
- `oncall|on-call|pager|escalation`     # contactos / escalamiento
**Señal de N/A:** app que no se despliega (lib publicada en registry, CLI distribuida vía package manager).

**Verificar:**
- [ ] Cómo hacer un release.
- [ ] Cómo rollback.
- [ ] Cómo escalar / shrink.
- [ ] Contactos de emergencia.

---

## Checklist resumen

| ID                | Control                                          | Severidad |
| ----------------- | ------------------------------------------------ | --------- |
| DOC-CODE-001      | API pública con docstring                        | medium    |
| DOC-CODE-002      | Tipos explícitos                                 | medium    |
| DOC-CODE-003      | Comentarios explican por qué                     | low       |
| DOC-README-001    | README mínimo                                    | high      |
| DOC-README-002    | .env.example documentado                         | high      |
| DOC-README-003    | Estructura del repo explicada                    | medium    |
| DOC-API-001       | OpenAPI fuente de verdad                         | high      |
| DOC-API-002       | Ejemplos por endpoint                            | medium    |
| DOC-API-003       | Errores documentados                             | medium    |
| DOC-API-004       | Guías de uso                                     | medium    |
| DOC-CHANGE-001    | Changelog                                        | medium    |
| DOC-CHANGE-002    | Release notes al usuario                         | medium    |
| DOC-ON-001        | Onboarding para devs                             | medium    |
| DOC-ON-002        | Docs operacionales                               | medium    |
