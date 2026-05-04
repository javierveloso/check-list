# 03 · Calidad de código · Estilo y naming

> Formato, estilo, y convenciones de nombres. Agnóstico: se asume que el proyecto
> ha elegido un linter/formatter y lo aplica.
>
> **Marcos de referencia:** Clean Code (R. C. Martin) · Code Complete (S. McConnell) · Guía de estilo del lenguaje correspondiente (PEP 8, Google Style Guides, Airbnb JS, etc.).

---

## A. Formato y estilo

#### `CODE-STYLE-001` — Formatter/linter automático en el pipeline
**Severidad:** high · **Aplica a:** all

El proyecto tiene formatter y linter configurados y aplicados automáticamente.

**Dónde buscar:** `**/.prettierrc*`, `**/.eslintrc*`, `**/eslint.config.*`, `**/pyproject.toml`, `**/.flake8`, `**/ruff.toml`, `**/.editorconfig`, `**/rustfmt.toml`, `**/.golangci.{yml,yaml}`, `**/.pre-commit-config.yaml`, `.github/workflows/**`
**Patrones:**
- `eslint-disable(?!-next-line)`     # disable global de ESLint sin justificación
- `#\s*noqa(?!:)`                    # noqa Python sin código específico
- `@ts-(ignore|nocheck)`             # silenciar TS sin razón
- `prettier-ignore`                  # bypass de formatter
- `lint`                             # presencia de scripts/jobs de lint en CI
**Señal de N/A:** repo solo tiene archivos de configuración / documentación (sin código fuente que linter pueda procesar).

**Verificar:**
- [ ] Existe configuración de formatter (ej: Black/Prettier/gofmt/rustfmt/ktlint).
- [ ] Existe configuración de linter (ej: ruff/flake8, ESLint, Clippy, golangci-lint).
- [ ] Ambos corren en pre-commit y en CI.
- [ ] El PR no se puede mergear con errores de lint.
- [ ] Los warnings no se silencian sin comentario justificativo.

**Banderas rojas:**
- Archivos con formatos inconsistentes (tabs/espacios mezclados, indentación distinta).
- Lint desactivado globalmente (`// eslint-disable`, `# noqa`) sin explicación.
- Estilos distintos entre archivos del mismo proyecto.

---

#### `CODE-STYLE-002` — Indentación, ancho de línea y trailing commas consistentes
**Severidad:** low · **Aplica a:** all

Los valores están definidos por el formatter y se respetan. El revisor no
debería tener que comentarlos — son automáticos.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt,swift}` (excluir `node_modules`, `dist`, `build`, `.venv`, `target`)
**Patrones:**
- `^( {2,}\t|\t+ {2,})`              # mezcla tabs/espacios al inicio de línea
- `.{121,}$`                          # líneas que exceden 120 chars
- `[^\n]\Z`                           # archivo sin newline final
- `\s+$`                              # trailing whitespace
**Señal de N/A:** no hay código fuente en el repo (solo docs/configs).

**Verificar:**
- [ ] Indentación uniforme según el estilo del lenguaje.
- [ ] Ancho de línea razonable (ej: 88/100/120 caracteres).
- [ ] Trailing commas donde el lenguaje lo permite y el formatter lo impone.
- [ ] Archivos terminan con newline.

---

#### `CODE-STYLE-003` — Imports ordenados y sin basura
**Severidad:** medium · **Aplica a:** all

Los imports siguen una regla consistente: agrupados (stdlib, terceros, locales)
y sin imports no usados.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,java,rs,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `from\s+\S+\s+import\s+\*`         # wildcard import Python
- `import\s+\*\s+as\s+\w+`           # wildcard import JS/TS
- `^//\s*import\s+`                  # imports comentados JS/TS
- `^#\s*import\s+`                   # imports comentados Python
- `from\s+\.{2,}`                    # imports relativos profundos
**Señal de N/A:** lenguaje sin sistema de imports declarativos (ej: shell, SQL puro).

**Verificar:**
- [ ] Agrupación en bloques claros separados.
- [ ] Orden alfabético dentro de cada grupo (si el linter lo enforce).
- [ ] No hay imports wildcard (`import *`, `from x import *`) en código productivo.
- [ ] No hay imports no usados.
- [ ] Imports relativos controlados (absolutos por defecto en paquetes compartidos).

**Banderas rojas:**
- `from utils import *` en módulos reutilizables.
- Imports comentados sin explicación.
- Cientos de imports no ordenados al inicio de un archivo grande.

---

#### `CODE-STYLE-004` — No código muerto ni TODOs huérfanos
**Severidad:** medium · **Aplica a:** all

No hay código comentado, funciones no usadas, o TODOs sin contexto ni owner.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt,swift}` (excluir `node_modules`, `dist`, `build`, `.venv`, `tests/**`)
**Patrones:**
- `TODO\b(?![\(:])`                  # TODO sin owner/issue entre paréntesis o dos puntos
- `FIXME\b(?![\(:])`                 # FIXME sin contexto
- `XXX\b|HACK\b`                     # marcadores de hack sin justificación
- `^\s*//\s*[a-zA-Z].{40,}`          # comentarios largos parecidos a código JS/TS
- `^\s*#\s*(def |class |if |for |return )` # código Python comentado
**Señal de N/A:** repo nuevo (<1 mes) sin deuda acumulada todavía.

**Verificar:**
- [ ] Los TODO/FIXME tienen contexto: fecha, autor, issue enlazado.
- [ ] No hay código comentado "por si acaso".
- [ ] No hay funciones/clases/variables sin referencias.
- [ ] Existe herramienta (ej: vulture, ts-prune, knip) detectando dead code.

**Banderas rojas:**
- `# TODO: fix this` sin contexto.
- Bloques de 50 líneas comentadas.
- Funciones públicas nunca invocadas.

---

## B. Naming

#### `CODE-NAME-001` — Nombres descriptivos y sin abreviaciones crípticas
**Severidad:** medium · **Aplica a:** all

Los nombres comunican intención. Se prefiere un nombre largo y claro a uno corto
y opaco.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`, `**/*test*`)
**Patrones:**
- `\b(temp|tmp|foo|bar|baz|asdf|qwerty|test123)\b` # nombres placeholder en código productivo
- `\b(?:def|function|fn|func)\s+(?:do|handle|process|stuff|things)\b` # verbos vagos
- `\b(let|var|const)\s+[a-z]\s*=`    # variables de 1 letra fuera de loops
- `\b(data|info|item|obj|val)\d*\s*[:=]` # nombres genéricos numerados
**Patrones:**
- *(nombres descriptivos — revisión LLM-judge complementa los regex)*
**Señal de N/A:** no hay código fuente en lenguajes soportados.

**Verificar:**
- [ ] Funciones con nombre de verbo que describe qué hacen: `calculate_risk()`, `extract_text()`.
- [ ] Variables con sustantivos descriptivos: `contract_section`, `user_age_years`.
- [ ] Evitar abreviaciones que no sean convenciones establecidas (`ctx`, `err`, `idx`, `i/j/k` en loops cortos, sí).
- [ ] No usar un solo carácter excepto en comprehensions cortas o índices de loop.
- [ ] Booleanos con prefijo que los identifique: `is_valid`, `has_access`, `can_edit`, `should_retry`.

**Banderas rojas:**
- Variables `a`, `b`, `x`, `temp`, `data` sin contexto.
- Funciones llamadas `handleStuff`, `doThings`, `process`.
- Abreviaciones internas de la empresa no documentadas (`sprp`, `dgkpo`).

---

#### `CODE-NAME-002` — Convenciones del lenguaje respetadas
**Severidad:** low · **Aplica a:** all

Cada lenguaje tiene su convención de capitalización. Se respeta.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt,swift}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `class\s+[a-z]\w*`                 # clase no PascalCase
- `def\s+[A-Z]\w*\s*\(`              # función Python con PascalCase
- `(let|const|var)\s+[A-Z][A-Z_]+\s*=\s*[^A-Z]` # const-like sin caps en JS/TS
- `func\s+[a-z]\w*\(.*\).*\{`        # función Go en minúscula exportada como pública (revisar contexto)
**Señal de N/A:** repo monolingüe simple con < 100 LOC.

**Verificar:**
- [ ] Clases/tipos: `PascalCase` en casi todos los lenguajes.
- [ ] Constantes: `UPPER_SNAKE_CASE` (Python, JS) o `kCamelCase`/`PascalCase` (Go, C++).
- [ ] Variables/funciones: según el lenguaje (`snake_case` en Python/Ruby/Rust, `camelCase` en JS/Java/Swift, `PascalCase` en Go público, `camelCase` Go interno).
- [ ] Módulos/paquetes: según el lenguaje.
- [ ] No mezclar estilos en el mismo archivo.

---

#### `CODE-NAME-003` — Nombres consistentes en toda la base de código
**Severidad:** low · **Aplica a:** all

El mismo concepto se llama igual en todas partes. Evitar sinónimos que
confunden.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `\b(user_id|userId|uid|userID)\b` # variantes de un mismo concepto (ejemplo)
- `\bis_not_\w+|isNot[A-Z]\w+`       # booleanos negativos
- *(consistencia inter-archivo — revisión LLM-judge cubre los matices)*
**Señal de N/A:** base de código pequeña (< 1k LOC) o monolingüe trivial.

**Verificar:**
- [ ] No hay variables con nombres distintos para el mismo concepto: `user_id`, `userId`, `uid`, `user`.
- [ ] Los términos del dominio son consistentes: si se usa "invoice", no mezclar con "bill" en otro módulo.
- [ ] Los booleanos negativos se evitan cuando es posible: preferir `is_enabled` a `is_not_disabled`.

---

#### `CODE-NAME-004` — Prefijos y sufijos uniformes
**Severidad:** low · **Aplica a:** all

Si el proyecto usa prefijos (`get_`, `fetch_`, `create_`, `build_`), los usa con
una semántica clara y consistente.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `\b(get|fetch|load|retrieve|find)[A-Z_]\w+\(` # múltiples prefijos sinónimos
- `\bon[A-Z]\w+\s*[:=]\s*\([^)]*\)\s*=>` # callbacks `on*` en componentes
- `\bhandle[A-Z]\w+\s*[:=]`          # handlers `handle*`
- *(coherencia semántica — revisión LLM-judge)*
**Señal de N/A:** proyecto sin convención explícita o sin componentes UI.

**Verificar:**
- [ ] `get_` para acceso rápido, `fetch_` para I/O, `build_` para construir un valor → diferencia documentada si hay más de uno.
- [ ] Callback props en componentes UI: convención `on*` (ej: `onClick`, `onSubmit`).
- [ ] Event handlers internos: convención `handle*` (ej: `handleClick`).

---

## C. Comentarios y documentación de símbolos

#### `CODE-DOC-001` — Docstrings en API pública
**Severidad:** medium · **Aplica a:** all

Las funciones, clases y módulos expuestos tienen docstring o comentario
equivalente. Las privadas, cuando sean no triviales.

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go,rs,java,cs,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `^export\s+(function|class|const)\s+\w+`  # símbolos exportados (revisar si tienen JSDoc encima)
- `^def\s+[a-z_][\w]*\(`             # funciones Python sin `_` privado
- `"""[\s\S]{0,40}"""`               # docstrings triviales (<40 chars)
- `^func\s+[A-Z]\w+\(`               # funciones Go públicas (deben tener godoc encima)
**Señal de N/A:** repo es app monolítica interna sin API pública / paquete consumible.

**Verificar:**
- [ ] Todo símbolo público tiene descripción: qué hace, parámetros, retorno, errores.
- [ ] El formato es consistente con el ecosistema (Google/NumPy/Sphinx en Python, JSDoc/TSDoc en JS, godoc, rustdoc, etc.).
- [ ] Los docstrings describen el **qué** y **por qué**, no el **cómo** (eso es el código).

**Banderas rojas:**
- Funciones públicas sin docs en paquetes reutilizables.
- Docstrings que repiten el nombre: `def save_user():` / `"""Saves a user."""` sin info adicional.

---

#### `CODE-DOC-002` — Comentarios explican "por qué", no "qué"
**Severidad:** low · **Aplica a:** all

Los comentarios agregan información que el código no da: razones, trade-offs,
referencias a tickets, bugs o RFCs.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `//\s*incremento|//\s*increment\b` # comentario redundante clásico
- `#\s*(incrementa|set|get|return)\b` # comentarios redundantes Python
- *(calidad semántica del comentario — revisión LLM-judge)*
**Señal de N/A:** código sin comentarios (otro problema, pero no aplica este control).

**Verificar:**
- [ ] No hay comentarios redundantes (`i = i + 1 # incrementar i`).
- [ ] Los hacks/workarounds están comentados con el motivo y link a issue.
- [ ] Las decisiones no obvias están justificadas.

**Banderas rojas:**
- Comentarios que repiten el código literalmente.
- Comentarios obsoletos que describen algo que el código ya no hace.

---

#### `CODE-DOC-003` — Referencias a estándares o tickets
**Severidad:** low · **Aplica a:** all

Cuando se implementa un estándar, cumplimiento, o parche de seguridad, se
referencia.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `RFC\s?\d{3,5}`                    # referencias RFC
- `CVE-\d{4}-\d{4,7}`                # referencias CVE
- `(GDPR|HIPAA|PCI[-\s]?DSS|SOC\s?2)` # cumplimiento normativo
- `(?:JIRA|TICKET|ISSUE|GH)-\d+`     # IDs de ticket
**Señal de N/A:** dominio sin requerimientos regulatorios ni cumplimiento de estándares.

**Verificar:**
- [ ] `// Per RFC 7231 §4.3.2`, `// GDPR Art. 17 — right to erasure`, `// CVE-2024-xxxx mitigation`.
- [ ] Los números de ticket en commits/comentarios enlazan al tracker.

---

## D. Tipos estáticos y contratos

#### `CODE-TYPE-001` — Type hints / tipos estáticos obligatorios en API pública
**Severidad:** high · **Aplica a:** all

Lenguajes tipados: se evita `any`, `object` como fallback.
Lenguajes con tipos opcionales (Python, TS, Ruby con sorbet): la API pública
tiene tipos completos y hay type checker en CI.

**Dónde buscar:** `**/*.{ts,tsx}`, `**/*.py`, `**/tsconfig*.json`, `**/mypy.ini`, `**/pyproject.toml`, `.github/workflows/**`
**Patrones:**
- `:\s*any\b`                        # uso de `any` en TS
- `\bas\s+any\b`                     # cast a any
- `@ts-ignore`                       # silenciar TS
- `#\s*type:\s*ignore`               # silenciar mypy
- `def\s+\w+\([^)]*\)\s*:`           # firma Python sin `->` retorno
- `"strict"\s*:\s*false`             # tsconfig strict desactivado
**Señal de N/A:** lenguaje sin sistema de tipos opcional ni estático (ej: Lua, Bash).

**Verificar:**
- [ ] Todas las firmas públicas tienen tipos (parámetros y retorno).
- [ ] Se evita el tipo "any" / `Any` como escape hatch sin justificación.
- [ ] Type checker (mypy, pyright, TypeScript strict, sorbet) corre en CI.
- [ ] Los errores del type checker se tratan como errores, no warnings.

**Banderas rojas:**
- `any` / `Any` proliferado.
- `@ts-ignore`, `# type: ignore` sin razón.
- Casts innecesarios (`as any`) para callar al compilador.

---

#### `CODE-TYPE-002` — Tipos explícitos para valores del dominio
**Severidad:** medium · **Aplica a:** all

Se prefieren tipos del dominio (`UserId`, `Money`, `EmailAddress`) a tipos
primitivos anónimos (`str`, `int`).

**Dónde buscar:** `**/*.{ts,tsx,py,go,rs,java,cs,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `\bamount\s*:\s*float\b|\bprice\s*:\s*float\b` # dinero como float
- `\b(id|user_id|account_id)\s*:\s*(str|string|int)\b` # IDs como primitivos
- `==\s*"(pending|active|inactive|done)"`        # strings mágicos en vez de enum
- `NewType\(`                        # uso de NewType Python (señal positiva)
- `as\s+\w+Id\b`                     # branded types TS (señal positiva)
**Señal de N/A:** prototipo sin reglas de dominio formalizadas o sin valores sensibles tipo dinero/IDs.

**Verificar:**
- [ ] Identificadores sensibles usan wrapper/alias (TypeScript branded types, NewType en Python, newtype en Rust).
- [ ] Amounts / monedas no son `float` sin justificación.
- [ ] Enums cerrados en vez de strings mágicos.

**Banderas rojas:**
- `def transfer(from: str, to: str, amount: float)` — fácil de confundir argumentos.
- `if status == "pending"` repartido por el código (debería ser enum).

---

## Checklist resumen

| ID              | Control                                              | Severidad |
| --------------- | ---------------------------------------------------- | --------- |
| CODE-STYLE-001  | Formatter/linter automático                          | high      |
| CODE-STYLE-002  | Indentación/línea/trailing comma                     | low       |
| CODE-STYLE-003  | Imports ordenados                                    | medium    |
| CODE-STYLE-004  | Sin código muerto ni TODOs huérfanos                 | medium    |
| CODE-NAME-001   | Nombres descriptivos                                 | medium    |
| CODE-NAME-002   | Convenciones del lenguaje                            | low       |
| CODE-NAME-003   | Consistencia en toda la base                         | low       |
| CODE-NAME-004   | Prefijos/sufijos uniformes                           | low       |
| CODE-DOC-001    | Docstrings en API pública                            | medium    |
| CODE-DOC-002    | Comentarios explican por qué                         | low       |
| CODE-DOC-003    | Referencias a estándares/tickets                     | low       |
| CODE-TYPE-001   | Type hints en API pública                            | high      |
| CODE-TYPE-002   | Tipos del dominio                                    | medium    |
