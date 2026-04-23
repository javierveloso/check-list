# 01 · Seguridad · Validación de entrada

> Controles sobre validación de datos de entrada, inyecciones (SQL, comandos, XSS),
> deserialización insegura y SSRF.
>
> **Marcos de referencia:** OWASP A03:2021 · OWASP API3:2023 · CWE-20, CWE-89, CWE-77, CWE-78, CWE-79, CWE-91, CWE-918, CWE-1321, CWE-502.

---

## A. Validación general de entrada

#### `SEC-INPUT-001` — Todo input externo se valida contra un schema
**Severidad:** critical · **Tags:** `owasp-a04`, `cwe-20` · **Aplica a:** backend · api

Los datos que llegan del exterior (request body, query params, headers que se
usan en lógica, mensajes de colas, webhooks) se validan contra un schema declarativo
antes de entrar en el resto del código.

**Verificar:**
- [ ] Cada endpoint/handler declara el schema de entrada (body, params, headers relevantes).
- [ ] El schema valida tipo, rango, longitud, formato y pertenencia a un enum cuando aplique.
- [ ] El modo es "strict": campos no declarados se rechazan (no se silencian).
- [ ] Los errores de validación se mapean a una respuesta controlada (400/422) sin filtrar internals.

**Banderas rojas:**
- Handlers que leen directamente `request.json()` y pasan el resultado a funciones sin validar.
- Tipos laxos (`any`, `Dict[str, Any]`) usados como entrada sin filtrado.
- Campos derivados del cliente (`is_admin`, `price`, `owner_id`) aceptados tal cual.

---

#### `SEC-INPUT-002` — Validación de tipos semánticos, no solo sintácticos
**Severidad:** high · **Aplica a:** backend

Los identificadores, URLs, emails, fechas, etc., se validan a su tipo real,
no como strings arbitrarios.

**Verificar:**
- [ ] Los UUID se validan como UUID antes de interpolarse en queries.
- [ ] Las URLs se validan (esquema permitido: `http`/`https`, nunca `file`, `javascript`, `data`).
- [ ] Las fechas se validan en formato (ISO 8601) y en rango lógico (no año 9999, no fechas pasadas en un flujo "futuro").
- [ ] Los emails pasan por validación, no solo regex casera.
- [ ] Los enums se casan contra el set cerrado; nunca `cast(Any, value)`.

**Banderas rojas:**
- `uuid = request.params["id"]; db.query(f"... WHERE id = '{uuid}'")`.
- Aceptar `tel:`, `mailto:`, `javascript:` en campos URL sin validación.
- Validación de email que reposa solo en `.includes("@")`.

---

#### `SEC-INPUT-003` — Límites de tamaño en toda entrada
**Severidad:** high · **Tags:** `dos`, `cwe-400` · **Aplica a:** backend · api

Cada campo y el body entero tienen un tamaño máximo razonable. El límite se
aplica **antes** de cargar el contenido completo en memoria.

**Verificar:**
- [ ] Existe límite global de tamaño de request body (ej: 1 MB para JSON, mayor para uploads).
- [ ] Campos de texto tienen `max_length` en el schema.
- [ ] Listas tienen tamaño máximo (ej: 100 items en batch operations).
- [ ] Tamaño máximo de archivos se verifica mediante `Content-Length` y durante el streaming.

**Banderas rojas:**
- Endpoints que leen todo el body a memoria sin límite.
- Campos `string` sin `max_length` ni `maxlength`.
- Deserialización de JSON anidado sin profundidad máxima.

---

## B. Inyección SQL y NoSQL

#### `SEC-INPUT-010` — Queries siempre parametrizadas
**Severidad:** critical · **Tags:** `owasp-a03`, `cwe-89` · **Aplica a:** backend

Todas las consultas a BD usan parámetros/prepared statements. Nunca se construye
SQL por concatenación o f-string con input externo.

**Verificar:**
- [ ] No hay concatenación de strings SQL con variables provenientes del cliente.
- [ ] Las queries raw (cuando son necesarias) usan la API de parámetros del driver.
- [ ] El ORM/query builder está configurado para usar parámetros por defecto.
- [ ] Se usan funciones de escape/quote explícitas solo cuando no hay alternativa, con justificación.

**Banderas rojas:**
- `f"SELECT * FROM u WHERE id = {user_id}"`.
- `"... WHERE name = '" + name + "'"`.
- `db.raw(query_string, [])` con `query_string` construido con input.
- Uso de `ORDER BY ${col}` con `col` del cliente (ver SEC-INPUT-012).

**Referencias:** CWE-89 · OWASP SQL Injection Prevention Cheat Sheet.

---

#### `SEC-INPUT-011` — Metadatos de query (tablas/columnas) nunca vienen del cliente
**Severidad:** high · **Tags:** `cwe-89` · **Aplica a:** backend

Nombres de tablas, columnas, esquemas no pueden provenir de input. Si el cliente
elige entre opciones, se hace contra una allowlist server-side.

**Verificar:**
- [ ] `ORDER BY`, `SELECT <col>`, `FROM <table>` nunca toman valores directos del cliente.
- [ ] Las opciones válidas están en una constante/enum server-side.
- [ ] El input del cliente es un string simple que mapea a la opción, no el SQL mismo.

**Banderas rojas:**
- `order_by = request.query["sort"]; query.order_by(order_by)` sin filtrar.
- Permitir al cliente seleccionar el schema / tabla por parámetro.

---

#### `SEC-INPUT-012` — Búsqueda full-text sanitizada
**Severidad:** medium · **Aplica a:** backend

Los operadores de búsqueda full-text (`to_tsquery`, `MATCH`, etc.) se escapan
o se generan desde syntax segura; nunca se pasan al motor tal como llegan.

**Verificar:**
- [ ] El query full-text se construye desde `plainto_tsquery`/`websearch_to_tsquery` o equivalente.
- [ ] Los caracteres reservados del motor se escapan.
- [ ] Los comodines (`%`, `_`, `*`) se sanitizan si la búsqueda es por prefijo.

---

#### `SEC-INPUT-013` — Anti-inyección NoSQL y de queries especializadas
**Severidad:** high · **Aplica a:** backend

Bases NoSQL, motores de búsqueda, y sistemas de reglas son vulnerables a
inyección si aceptan documentos/objetos arbitrarios del cliente.

**Verificar:**
- [ ] Los filtros NoSQL no aceptan objetos complejos del cliente (ej: `{$ne: null}` como bypass).
- [ ] Antes de pasar a la BD, se castea a tipos esperados.
- [ ] Los query DSLs (Elasticsearch, MongoDB query) se construyen server-side.

**Banderas rojas:**
- `db.users.find(req.query)` (Mongo sin saneo).
- Permitir operadores (`$where`, `$regex`) en filtros de usuario.
- Expresiones LDAP construidas por concatenación.

**Referencias:** CWE-943 · CWE-90 (LDAP) · CWE-91 (XPath).

---

## C. Inyección de comandos

#### `SEC-INPUT-020` — Cero shell con input del usuario
**Severidad:** critical · **Tags:** `owasp-a03`, `cwe-78` · **Aplica a:** backend

Los subprocesos se invocan con argumentos en array, nunca mediante shell con
interpolación.

**Verificar:**
- [ ] Las ejecuciones externas usan `spawn`/`exec` con array de argumentos, no string concatenada.
- [ ] En Python: `subprocess.run([...], shell=False)` — nunca `shell=True` con input del usuario.
- [ ] Si se debe pasar input, va como argumento separado, no embebido.
- [ ] Los paths de ejecutables son absolutos o vienen de whitelist.

**Banderas rojas:**
- `subprocess.run(f"pdftotext {path}", shell=True)`.
- `exec(f"convert {file}.pdf out.png")`.
- Comandos construidos por `+` o f-string con input.

---

#### `SEC-INPUT-021` — No `eval`/`exec` sobre input del usuario
**Severidad:** critical · **Tags:** `cwe-94` · **Aplica a:** backend · frontend

La evaluación dinámica de código con input externo es una RCE garantizada.

**Verificar:**
- [ ] No se usa `eval`, `Function()`, `new Function(code)`, `exec`, `compile` sobre strings derivados de input.
- [ ] Plantillas dinámicas (Jinja, EJS, etc.) tienen autoescape y no se renderizan strings construidos con input.
- [ ] `JSON.parse` (o equivalente) se usa para JSON; nunca `eval`.

**Banderas rojas:**
- `eval(req.body.formula)`.
- Template strings ejecutados con `vm.runInNewContext` y input.
- `pickle.loads(bytes_from_client)` — ver SEC-INPUT-040.

---

## D. Path traversal y SSRF

#### `SEC-INPUT-030` — Rutas de archivo validadas contra path traversal
**Severidad:** critical · **Tags:** `cwe-22`, `cwe-73` · **Aplica a:** backend

Los nombres de archivo o paths derivados del usuario se resuelven contra un
directorio base y se verifica que el resultado esté dentro.

**Verificar:**
- [ ] Se resuelve el path (equivalente a `Path.resolve()` / `realpath()`) y se compara con el base.
- [ ] Se rechazan entradas con `..`, `~`, nulos (`%00`), rutas absolutas.
- [ ] Los symlinks se siguen antes de la verificación o se prohíben.
- [ ] Los nombres de archivo de upload se reemplazan por identificadores server-side (UUID).

**Banderas rojas:**
- `open(os.path.join(base, user_input))` sin resolución y verificación.
- Servir archivos por `send_file(user_path)`.
- Aceptar `filename` del cliente como nombre final en disco.

**Referencias:** CWE-22 · OWASP File Upload Cheat Sheet.

---

#### `SEC-INPUT-031` — Protección contra SSRF en fetchers de URL
**Severidad:** critical · **Tags:** `cwe-918`, `owasp-a10` · **Aplica a:** backend

Si el servidor hace requests a URLs provistas por el cliente (image proxy,
webhook tester, oEmbed, fetch de favicon), debe prevenir SSRF a redes internas.

**Verificar:**
- [ ] Las URLs se resuelven a IP y se bloquea el acceso a rangos internos (RFC1918, link-local, loopback, cloud metadata 169.254.169.254).
- [ ] Solo se permiten esquemas `http`/`https`.
- [ ] Se siguen redirecciones limitadas, revalidando la URL destino en cada hop.
- [ ] Hay timeout y tamaño máximo de respuesta.
- [ ] Se usa una DNS resolver/librería que no revele la IP al backend sin validar.

**Banderas rojas:**
- `requests.get(user_url)` sin lista de bloqueo.
- Seguir redirects sin revalidar.
- Permitir `file://`, `gopher://`, `dict://`.

**Referencias:** OWASP SSRF Cheat Sheet · CWE-918.

---

## E. Cross-site scripting

#### `SEC-INPUT-040` — Salida HTML escapada por defecto
**Severidad:** critical · **Tags:** `owasp-a03`, `cwe-79` · **Aplica a:** frontend · backend

El framework de presentación debe escapar HTML por defecto. Cualquier uso de
HTML crudo debe pasar por un sanitizador de allowlist.

**Verificar:**
- [ ] El framework (React, Vue, Angular, Jinja con autoescape, etc.) escapa por defecto.
- [ ] Los usos de `dangerouslySetInnerHTML`, `v-html`, `{{{...}}}` vienen sanitizados (DOMPurify, bleach, ammonia, OWASP Java HTML Sanitizer).
- [ ] Los atributos con input del usuario están correctamente escapados (`href`, `src`, inline event handlers prohibidos).
- [ ] URLs en `href`/`src` se validan a `http:`/`https:` (bloqueo de `javascript:`, `data:`).

**Banderas rojas:**
- `element.innerHTML = userContent`.
- `dangerouslySetInnerHTML={{__html: content}}` sin sanitización.
- Concatenación directa en templates sin autoescape.
- `<a href={user_url}>` sin validar esquema.

---

#### `SEC-INPUT-041` — Content Security Policy efectivo
**Severidad:** high · **Tags:** `csp`, `defense-in-depth` · **Aplica a:** frontend · backend

CSP restrictivo como defensa en profundidad: si un XSS se escapa, el CSP limita
el daño.

**Verificar:**
- [ ] Existe header `Content-Security-Policy` en respuestas HTML (ver `05-headers-http.md` para detalle).
- [ ] `script-src` sin `unsafe-inline` ni `unsafe-eval` (usa nonces/hashes).
- [ ] Hay reporting (`report-uri`/`report-to`).

(Detalle completo en `05-headers-http.md` `SEC-HEADERS-010`.)

---

## F. Deserialización

#### `SEC-INPUT-050` — Deserialización segura de formatos confiables
**Severidad:** critical · **Tags:** `owasp-a08`, `cwe-502` · **Aplica a:** backend

La deserialización de formatos que permiten objetos arbitrarios (pickle, Java
serialization, YAML `!!python/object`, PHP `unserialize`) está prohibida sobre
input externo. Se prefieren formatos de datos (JSON, MessagePack).

**Verificar:**
- [ ] Ningún endpoint deserializa `pickle` / `marshal` / Java Object / `yaml.load` sin `SafeLoader` sobre input del cliente.
- [ ] Si se usa YAML, se usa `safe_load` / `Load` con `SafeLoader`.
- [ ] El JSON deserializado se valida contra schema antes de usarse.
- [ ] Los objetos recuperados de colas (SQS, Kafka) también validan.

**Banderas rojas:**
- `pickle.loads(body)`, `marshal.loads(body)`.
- `yaml.load(data)` sin `Loader=SafeLoader`.
- Confiar en tipos/propiedades del objeto deserializado sin validación.

---

## G. Sanitización de caracteres de control y unicode

#### `SEC-INPUT-060` — Protección contra caracteres de control y homoglifos
**Severidad:** medium · **Aplica a:** backend · frontend

Los inputs que se muestran o se usan en decisiones (nombres de usuario,
emails) se normalizan para evitar spoofing con caracteres invisibles o
variantes Unicode.

**Verificar:**
- [ ] Se rechazan (o normalizan) caracteres de control (`\x00`–`\x1F`), zero-width (`\u200B`, `\uFEFF`), RTL overrides.
- [ ] Los strings se normalizan a NFC antes de compararlos o almacenarlos.
- [ ] Hay bloqueo de homoglifos en nombres críticos (dominios, usernames sensibles), si aplica.

**Banderas rojas:**
- Aceptar nombres de usuario con caracteres invisibles.
- Comparar strings unicode sin normalizar (`"café" != "café"` por forma NFC vs NFD).

---

#### `SEC-INPUT-061` — Protección contra ReDoS
**Severidad:** high · **Tags:** `cwe-1333`, `redos` · **Aplica a:** backend · frontend

Las expresiones regulares aplicadas a input del usuario no tienen complejidad
catastrófica (backtracking exponencial).

**Verificar:**
- [ ] Las regex se analizan estáticamente (ej: `safe-regex`, `rat`, auditoría manual) o se usan engines lineales (RE2).
- [ ] Hay timeout al ejecutar regex sobre input.
- [ ] Alternativamente, se limita drásticamente la longitud del input antes de matchear.

**Banderas rojas:**
- Regex tipo `(a+)+b` evaluada contra input largo.
- Motor de regex que retrocede (Python/JS/Java) con patrones anidados sobre 10 KB+.

**Referencias:** CWE-1333 · OWASP ReDoS Cheat Sheet.

---

## Checklist resumen

| ID               | Control                                                  | Severidad |
| ---------------- | -------------------------------------------------------- | --------- |
| SEC-INPUT-001    | Input externo contra schema                              | critical  |
| SEC-INPUT-002    | Validación de tipos semánticos                           | high      |
| SEC-INPUT-003    | Límites de tamaño en entrada                             | high      |
| SEC-INPUT-010    | Queries parametrizadas                                   | critical  |
| SEC-INPUT-011    | Metadatos de query no del cliente                        | high      |
| SEC-INPUT-012    | Full-text sanitizado                                     | medium    |
| SEC-INPUT-013    | Anti-inyección NoSQL/LDAP/XPath                          | high      |
| SEC-INPUT-020    | Cero shell con input                                     | critical  |
| SEC-INPUT-021    | No eval sobre input                                      | critical  |
| SEC-INPUT-030    | Path traversal bloqueado                                 | critical  |
| SEC-INPUT-031    | SSRF prevenido                                           | critical  |
| SEC-INPUT-040    | Salida HTML escapada                                     | critical  |
| SEC-INPUT-041    | CSP efectivo (→ headers)                                 | high      |
| SEC-INPUT-050    | Deserialización segura                                   | critical  |
| SEC-INPUT-060    | Control caracteres y unicode                             | medium    |
| SEC-INPUT-061    | Anti-ReDoS                                               | high      |
