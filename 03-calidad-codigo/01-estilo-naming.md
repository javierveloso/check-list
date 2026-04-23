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

**Verificar:**
- [ ] No hay variables con nombres distintos para el mismo concepto: `user_id`, `userId`, `uid`, `user`.
- [ ] Los términos del dominio son consistentes: si se usa "invoice", no mezclar con "bill" en otro módulo.
- [ ] Los booleanos negativos se evitan cuando es posible: preferir `is_enabled` a `is_not_disabled`.

---

#### `CODE-NAME-004` — Prefijos y sufijos uniformes
**Severidad:** low · **Aplica a:** all

Si el proyecto usa prefijos (`get_`, `fetch_`, `create_`, `build_`), los usa con
una semántica clara y consistente.

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
