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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/controllers/**`, `**/handlers/**`, `**/routes/**`, `**/dto/**`, `**/schemas/**`, `**/validators/**`
**Patrones:**
- `(request|req)\.(body|json|data)(?!\.\w+\s*\?)`                             # uso directo del body sin validación visible
- `:\s*any\b|Dict\[str,\s*Any\]|interface\s*\{\s*\}`                          # tipos laxos en DTO
- `JSON\.parse\(\s*req\.body|json\.loads\(\s*request\.body`                   # parse crudo sin schema
- `\bextra\s*=\s*['"]allow['"]|additionalProperties:\s*true`                  # schema permisivo
- `\@Body\(\)\s+\w+\s*:\s*any|body:\s*Record<string`                          # NestJS body sin DTO
**Señal de N/A:** repo sin entrada externa (lib pura, sin endpoints, sin consumers de cola/webhook).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/dto/**`, `**/schemas/**`, `**/validators/**`, `**/models/**`
**Patrones:**
- `:\s*string;\s*//\s*(uuid|email|url|date)`                                  # campo string con tipo semántico no enforced
- `\.includes\(['"]@['"]\)`                                                    # validación de email casera
- `re\.match\(['"][^'"]*@[^'"]*['"]`                                          # regex casera de email
- `new\s+Date\(\s*req(uest)?\.|Date\.parse\(req(uest)?\.`                     # fecha sin validar formato
- `URL\(\s*req(uest)?\.|new\s+URL\(\s*req\.`                                  # URL sin validar esquema
**Señal de N/A:** la app no maneja tipos semánticos (solo strings/números planos sin formato específico).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/main.{ts,js,py}`, `**/app.{ts,js,py}`, `**/middleware/**`, `**/nginx.conf`, `**/*.conf`, `**/dto/**`, `**/schemas/**`
**Patrones:**
- `bodyParser\.(json|urlencoded)\(\s*\)`                                       # body-parser sin limit
- `express\.json\(\s*\)`                                                      # Express json sin opts
- `client_max_body_size\s+\d+[gG]`                                            # nginx con límite alto
- `(?i)max[_-]?length|maxLength|max_size`                                     # buscar y verificar valores razonables
- `await\s+request\.(text|json|body|read)\(\s*\)`                             # leer body completo sin límite
- `request\.stream`                                                           # streaming — verificar abort en exceso
**Señal de N/A:** repo sin endpoints HTTP que reciban bodies (solo GETs con query args triviales).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,php,cs}`, `**/repositories/**`, `**/dao/**`, `**/services/**`, `**/models/**`, `**/*.{sql}`
**Patrones:**
- `(?i)f["']\s*SELECT[\s\S]*?\{[^}]+\}`                                       # f-string SQL Python
- `["']\s*SELECT[^"']*["']\s*\+\s*\w+`                                        # SQL por concatenación
- `\$\{[^}]+\}\s*[\s\S]*?(FROM|WHERE|VALUES)`                                 # template literal SQL JS
- `\.raw\([^,)]*\$\{|\.raw\([^,)]*\+`                                         # raw query interpolada
- `query\s*=\s*['"][\s\S]*?['"]\s*%\s*\(`                                     # %-formatting Python SQL
- `executeQuery\(\s*['"][^'"]*['"]\s*\+\s*\w+`                                # JDBC concatenado
**Señal de N/A:** repo sin acceso a BD relacional (solo NoSQL puro, ver SEC-INPUT-013).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/repositories/**`, `**/services/**`, `**/dao/**`
**Patrones:**
- `ORDER\s+BY\s+\$\{|ORDER\s+BY\s+["']\s*\+`                                  # ORDER BY interpolado
- `orderBy\(\s*req(uest)?\.|order_by\(\s*request\.`                          # ORDER BY desde input
- `FROM\s+\$\{|FROM\s+["']\s*\+\s*\w+`                                        # tabla interpolada
- `query\.sort\(\s*req(uest)?\.query`                                         # sort dinámico desde cliente
- `\bcolumn\s*=\s*req(uest)?\.|column_name\s*=\s*req`                         # columna desde input
**Señal de N/A:** consultas siempre construidas con tablas/columnas literales (sin sort dinámico ni queries genéricas).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/search/**`, `**/repositories/**`, `**/*.sql`
**Patrones:**
- `to_tsquery\(\s*[^)]*req(uest)?\.|to_tsquery\(\s*\$\{`                      # tsquery desde input
- `MATCH\s*\([^)]*\)\s+AGAINST\s*\(\s*['"]\s*\+`                              # MySQL FT interpolado
- `LIKE\s+['"]?%?\$\{[^}]*\}%?`                                               # LIKE con interpolación
- `LIKE\s+CONCAT\(\s*['"]\s*%['"]\s*,\s*req`                                  # LIKE con input
- `\.search\(\s*req(uest)?\.query\.q\b`                                       # search engine sin escape
**Señal de N/A:** la app no expone búsqueda full-text al cliente (solo igualdades exactas o búsqueda interna).

**Verificar:**
- [ ] El query full-text se construye desde `plainto_tsquery`/`websearch_to_tsquery` o equivalente.
- [ ] Los caracteres reservados del motor se escapan.
- [ ] Los comodines (`%`, `_`, `*`) se sanitizan si la búsqueda es por prefijo.

---

#### `SEC-INPUT-013` — Anti-inyección NoSQL y de queries especializadas
**Severidad:** high · **Aplica a:** backend

Bases NoSQL, motores de búsqueda, y sistemas de reglas son vulnerables a
inyección si aceptan documentos/objetos arbitrarios del cliente.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/repositories/**`, `**/services/**`, `**/dao/**`
**Patrones:**
- `\.find\(\s*req(uest)?\.(body|query)\s*\)`                                  # Mongo find con body crudo
- `\$where|\$regex|\$function`                                                # operadores Mongo peligrosos
- `\{\s*\$ne:\s*null\s*\}|\{\s*\$gt:\s*['"]?['"]?\s*\}`                       # bypass típicos NoSQL
- `ldap\.search\([^,)]*\+\s*\w+|ldap.*\(\s*['"][^'"]*['"]\s*\+`               # LDAP filter por concat
- `xpath\([^,)]*\+|XPathExpression.*\+\s*req`                                 # XPath por concat
- `ElasticClient.*body:\s*req(uest)?\.body`                                   # ES query body crudo
**Señal de N/A:** repo solo usa BD relacional con queries parametrizadas (sin Mongo/Elastic/LDAP/XPath).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/services/**`, `**/utils/**`, `**/workers/**`
**Patrones:**
- `child_process\.exec\(\s*[^,)]*\$\{|child_process\.exec\(\s*[^,)]*\+\s*\w+` # Node exec interpolado
- `subprocess\.\w+\([^,)]*shell\s*=\s*True`                                   # Python shell=True
- `os\.system\(|os\.popen\(`                                                  # Python shell legacy
- `Runtime\.getRuntime\(\)\.exec\(\s*['"]\s*[^'"]*['"]\s*\+`                  # Java exec concatenado
- `\bexec\s*\(\s*['"][\s\S]*?\$\{`                                            # exec con template literal
- `\`[^`]*\$\{[^}]+\}[^`]*\`\s*[\s\S]{0,50}(exec|spawn|sh\b)`                 # backticks shell con interpolación
**Señal de N/A:** la app no invoca procesos del sistema (sin spawn/exec/system en el código).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`
**Patrones:**
- `\beval\s*\(`                                                               # eval — siempre revisar
- `new\s+Function\s*\(`                                                       # JS Function constructor
- `vm\.(runInNewContext|runInThisContext|runInContext)\s*\(`                  # Node vm con input
- `\bexec\s*\(\s*[^,)]*req(uest)?\.|compile\s*\([^,)]*req`                    # Python exec/compile sobre input
- `Function::createFromString|create_function`                                # PHP create_function
- `setTimeout\(\s*['"]|setInterval\(\s*['"]`                                  # setTimeout con string
**Señal de N/A:** búsqueda de los patrones devuelve cero matches en todo el repo.

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/controllers/**`, `**/services/**`, `**/handlers/**`
**Patrones:**
- `path\.join\([^,)]*req(uest)?\.|os\.path\.join\([^,)]*request\.`            # join con input sin verificación
- `open\(\s*[^,)]*req(uest)?\.|fs\.readFile\([^,)]*req\.`                     # open sobre input
- `send_file\(\s*[^,)]*req|sendFile\([^,)]*req`                               # serve file con input
- `\.\.[/\\]|%2e%2e[/\\]`                                                     # secuencia traversal literal
- `Path\.resolve\(|realpath\(`                                                 # uso esperado de canonicalización
- `(?i)filename\s*=\s*req(uest)?\.|originalname`                              # filename del cliente usado en disco
**Señal de N/A:** la app no abre archivos basados en input (solo accesos a paths fijos del propio binario).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/services/**`, `**/clients/**`, `**/integrations/**`, `**/webhooks/**`
**Patrones:**
- `(requests|httpx|aiohttp)\.(get|post|put)\(\s*[^,)]*req(uest)?\.`           # request HTTP con URL del cliente
- `fetch\(\s*req(uest)?\.body\.|axios\.(get|post)\([^,)]*req\.`               # fetch/axios con URL de input
- `urllib(2)?\.urlopen\(|urllib\.request\.urlopen\(`                          # Python con URL — verificar validación
- `(file|gopher|dict|ftp|jar)://`                                             # esquemas peligrosos
- `169\.254\.169\.254|metadata\.google\.internal|metadata\.azure`             # cloud metadata endpoints
- `127\.0\.0\.1|localhost|0\.0\.0\.0|::1`                                     # loopback — verificar bloqueo
**Señal de N/A:** la app no hace requests salientes a URLs derivadas del cliente.

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

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte,html,ejs,pug,hbs,jinja,j2}`, `**/templates/**`, `**/views/**`, `**/components/**`
**Patrones:**
- `dangerouslySetInnerHTML\s*=\s*\{\s*\{\s*__html`                            # React HTML crudo
- `\bv-html\s*=`                                                              # Vue HTML crudo
- `\{@html\s+`                                                                # Svelte HTML crudo
- `\.innerHTML\s*=|\.outerHTML\s*=`                                           # asignación directa de HTML
- `\{\{\{[^}]+\}\}\}|<%-\s*[^%]+%>|safe\|`                                    # Mustache/EJS/Jinja sin escape
- `<a\s+href\s*=\s*\{[^}]*\}|<a\s+href\s*=\s*['"]\$\{`                        # href dinámico — verificar esquema
**Señal de N/A:** la app no genera HTML (solo API JSON, no SSR ni templating).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`
**Patrones:**
- `Content-Security-Policy[^\n]*\*`                                           # CSP con comodín
- `script-src[^;]*['"]?unsafe-inline['"]?`                                    # CSP con unsafe-inline
- `script-src[^;]*['"]?unsafe-eval['"]?`                                      # CSP con unsafe-eval
- `default-src\s+\*`                                                          # CSP base abierto
- `helmet\(\s*\{[\s\S]*?contentSecurityPolicy:\s*false`                        # helmet con CSP desactivado
**Señal de N/A:** API que solo retorna JSON sin HTML (sin riesgo XSS — CSP irrelevante en respuestas no-HTML).

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

**Dónde buscar:** `**/*.{py,java,rb,php,cs,ts,js}`
**Patrones:**
- `pickle\.loads?\(|cPickle\.loads?\(`                                        # Python pickle
- `marshal\.loads?\(|shelve\.open`                                            # Python marshal
- `yaml\.load\([^,)]*\)(?!.*Loader\s*=\s*(yaml\.)?SafeLoader)`                # YAML load inseguro
- `ObjectInputStream|XMLDecoder`                                              # Java unsafe deserialization
- `\bunserialize\s*\(|Marshal\.load\(`                                        # PHP unserialize / Ruby Marshal
- `node-serialize|funcster\.deepDeserialize`                                  # libs JS unsafe
**Señal de N/A:** repo no deserializa formatos no-data (solo JSON con schema).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/validators/**`, `**/services/**`, `**/auth/**`
**Patrones:**
- `\.normalize\(['"]NF[CDKM]['"]?\)`                                          # uso esperado de normalize
- `unicodedata\.normalize`                                                    # Python normalize esperado
- `[​-‏﻿‪-‮]`                                        # zero-width / RTL en código (sospechoso)
- `==\s*['"][^'"]*[À-￿]`                                            # comparación con caracteres no ASCII (revisar normalización)
**Señal de N/A:** la app solo maneja identifiers ASCII server-generados (sin nombres de usuario libres ni búsquedas por texto).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/validators/**`, `**/utils/**`, `**/services/**`
**Patrones:**
- `\([^)]*\+\)\+|\([^)]*\*\)\+|\([^)]*\+\)\*`                                 # quantificador anidado clásico ReDoS
- `\(.*\|.*\)\+`                                                              # alternancia bajo cuantificador
- `re\.match\(\s*[^,)]*,\s*req(uest)?\.`                                      # regex aplicada a input
- `new\s+RegExp\(\s*req(uest)?\.|RegExp\(\s*req\.`                            # regex construida desde input
- `\.match\(\s*\/[^/]*\([^)]*\+[^)]*\)\+`                                     # patrón inline sospechoso
**Señal de N/A:** código no aplica regex sobre input externo no acotado.

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
