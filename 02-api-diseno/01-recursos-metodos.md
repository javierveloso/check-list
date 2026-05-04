# 02 · API · Diseño de recursos, URLs y métodos HTTP

> Diseño REST: nomenclatura de URLs, métodos HTTP, status codes.
>
> **Marcos de referencia:** Richardson Maturity Model · RFC 7231 · RFC 9110 · Google API Design Guide · Microsoft REST API Guidelines · JSON:API.

---

## A. URLs y recursos

#### `API-REST-001` — Recursos como sustantivos plurales
**Severidad:** medium · **Aplica a:** api

Las URLs identifican **recursos** (sustantivos), no acciones. Las acciones se
modelan con el método HTTP o con sub-recursos.

**Dónde buscar:** `**/routes/**/*.{ts,js,py,go,java}`, `**/controllers/**/*.{ts,js,py,go,java}`, `**/handlers/**/*.{ts,js,py,go}`, `**/api/**/*.{ts,js,py,go}`, `openapi*.{yaml,json}`, `swagger*.{yaml,json}`
**Patrones:**
- `app\.(get|post|put|delete|patch)\(['"]/[a-zA-Z]+/(get|create|update|delete|fetch|do|send|make)[A-Z]`     # verbo en path tras prefijo
- `(get|post|put|delete|patch)\(['"][^'"]*\b(getUser|createUser|deleteUser|sendEmail|doStuff|doAction|fetchAll|listAll)\b`     # endpoints con verbos comunes
- `@(Get|Post|Put|Delete|Patch)Mapping\(['"][^'"]*/(get|create|update|delete)[A-Z]`     # Spring con verbos en path
- `(path|route)\s*=\s*['"][^'"]*/(create|delete|update|fetch|get|do)[A-Z]`     # rutas declarativas con verbos
- `@(app|router)\.(get|post|put|delete|patch)\(['"][^'"]*/(get|create|delete|update)[A-Z]`     # Flask/FastAPI con verbos
**Señal de N/A:** no hay archivos en `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**` y no existe `openapi*`/`swagger*` en el repo.

**Verificar:**
- [ ] Recursos son sustantivos plurales: `/orders`, `/users`, `/documents`.
- [ ] Evitar verbos en el path: `POST /createUser` → `POST /users`.
- [ ] Las acciones que no encajan en CRUD se modelan como sub-recurso o estado: `POST /orders/{id}/cancellations` o `PATCH /orders/{id}` con `status: "cancelled"`.
- [ ] Consistencia singular/plural en toda la API.

**Banderas rojas:**
- `GET /getUserById/{id}`, `POST /sendEmail`, `POST /doStuff`.
- Mezcla inconsistente: `/user/{id}` y `/orders`.

---

#### `API-REST-002` — Nomenclatura consistente (kebab-case o snake_case)
**Severidad:** low · **Aplica a:** api

Se elige una convención para segmentos del path y se mantiene.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `openapi*.{yaml,json}`, `swagger*.{yaml,json}`
**Patrones:**
- `['"]/[a-z]+[A-Z][a-zA-Z]*['"/]`     # camelCase en path
- `['"]/[a-z]+_[a-z]+['"/]`     # snake_case en path
- `['"]/[a-z]+-[a-z]+['"/]`     # kebab-case en path (si conviven dos formas, hay inconsistencia)
- `(get|post|put|delete|patch)\(['"]/[A-Z]`     # paths con segmentos PascalCase
**Señal de N/A:** no hay archivos en `**/routes/**`/`**/controllers/**`/`**/handlers/**` ni `openapi*` en el repo.

**Verificar:**
- [ ] Todos los paths siguen la misma convención (kebab-case `/order-items` o snake_case `/order_items`).
- [ ] Query parameters siguen una convención consistente.
- [ ] Se documenta la convención.

**Banderas rojas:**
- `/orderItems`, `/order-items`, `/order_items` coexistiendo.

---

#### `API-REST-003` — Anidamiento limitado (≤ 2 niveles)
**Severidad:** medium · **Aplica a:** api

Recursos anidados reflejan pertenencia, pero no más de 2 niveles. Lo demás usa
filtros.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `openapi*.{yaml,json}`, `swagger*.{yaml,json}`
**Patrones:**
- `['"]/[a-z-]+/:?[a-zA-Z_]+/[a-z-]+/:?[a-zA-Z_]+/[a-z-]+/:?[a-zA-Z_]+`     # >=3 niveles de anidamiento con params
- `['"]/[a-z-]+/\{[a-zA-Z_]+\}/[a-z-]+/\{[a-zA-Z_]+\}/[a-z-]+/\{`     # >=3 niveles estilo OpenAPI
- `['"]/[a-z-]+/\$\{[a-zA-Z_]+\}/[a-z-]+/\$\{[a-zA-Z_]+\}/[a-z-]+`     # >=3 niveles con interpolación
**Señal de N/A:** no existen archivos en `**/routes/**`, `**/controllers/**`, `**/handlers/**` ni `openapi*` en el repo.

**Verificar:**
- [ ] Máximo 2 niveles de anidamiento: `/orgs/{org}/projects/{proj}` OK; `/orgs/{org}/projects/{proj}/tasks/{task}/comments/{c}` no.
- [ ] Para relaciones cruzadas se usa filtro/query: `GET /comments?task_id=...`.
- [ ] Los recursos tienen también una ruta "canónica" por ID (ej: `/tasks/{id}` además de `/projects/{p}/tasks/{id}`).

---

#### `API-REST-004` — IDs opacos y no-enumerables en URLs
**Severidad:** medium · **Tags:** `security`, `idor` · **Aplica a:** api

Los IDs expuestos en URLs son UUID, ULID, o identificadores opacos, no
autoincrementales, para evitar enumeración.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/models/**`, `**/entities/**`, `**/migrations/**`, `openapi*.{yaml,json}`
**Patrones:**
- `['"]/[a-z-]+/:id\b`     # parámetro ":id" expuesto (puede ser autoincremental)
- `\b(autoIncrement|AUTO_INCREMENT|SERIAL|BIGSERIAL|@GeneratedValue\(strategy\s*=\s*GenerationType\.IDENTITY\))`     # PK autoincremental detectada
- `id\s*:\s*(Int|Integer|number|bigint|Long)\b.*@Id`     # ID numérico como PK en ORM
- `parseInt\(\s*req\.params\.id`     # handler trata id como número (probable autoincremental)
- `type:\s*['"]?(integer|number)['"]?[^,]*format:\s*['"]?(int32|int64)['"]?.*name:\s*['"]?id`     # OpenAPI: id integer como path param
**Señal de N/A:** no hay rutas con `:id`/`{id}` en el repo y no hay modelos/migraciones que expongan PKs por API.

**Verificar:**
- [ ] IDs externos son UUID/ULID/opacos.
- [ ] Si se expone ID autoincremental, hay razón documentada (ej: recursos públicos tipo blog post).

(Ver también `SEC-AUTHZ-011`.)

---

#### `API-REST-005` — Trailing slash consistente
**Severidad:** low · **Aplica a:** api

Se elige una política (con o sin trailing slash) y se mantiene. Las rutas no
coincidentes redirigen o se alinean.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `openapi*.{yaml,json}`, configuración del framework (`app.{ts,js,py}`, `main.{ts,py}`)
**Patrones:**
- `(get|post|put|delete|patch)\(['"]/[a-z][a-z0-9/-]+/['"]`     # rutas con trailing slash
- `(get|post|put|delete|patch)\(['"]/[a-z][a-z0-9/-]+[a-z0-9]['"]`     # rutas sin trailing slash (comparar coexistencia)
- `strict_slashes\s*=\s*(True|False|true|false)`     # política Flask explícita
- `app\.set\(['"]strict routing['"]`     # política Express explícita
**Señal de N/A:** no hay archivos en `**/routes/**`, `**/controllers/**`, `**/handlers/**` ni `openapi*` en el repo.

**Verificar:**
- [ ] Todas las rutas siguen la misma regla.
- [ ] Hay redirección 308 si se acepta ambas o error claro si solo una.

---

## B. Métodos HTTP

#### `API-REST-010` — Método correcto según semántica
**Severidad:** high · **Aplica a:** api

Cada operación usa el verbo HTTP que corresponde a su semántica (safety,
idempotencia, presencia de body).

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `openapi*.{yaml,json}`, `swagger*.{yaml,json}`
**Patrones:**
- `\.post\(['"][^'"]*/(delete|remove|destroy)\b`     # POST usado para borrar
- `\.get\(['"][^'"]*/(create|update|delete|set|save|add|remove|send)\b`     # GET con verbo de mutación
- `\.get\([^)]*\)[\s\S]{0,400}\b(INSERT|UPDATE|DELETE|save\(|update\(|delete\(|create\()`     # handler GET con escritura (multilínea)
- `@(Get|GET)\([^)]*\)[\s\S]{0,400}\b(save|delete|update|insert)\(`     # decorator GET con mutación
- `\.post\(['"][^'"]*/search\b`     # POST /search sin justificación documentada
**Señal de N/A:** no hay archivos en `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**` ni `openapi*` en el repo.

**Verificar:**
- [ ] `GET`: lectura, safe, idempotente, sin body de request.
- [ ] `POST`: creación o acción no idempotente.
- [ ] `PUT`: reemplazo total del recurso, idempotente.
- [ ] `PATCH`: actualización parcial.
- [ ] `DELETE`: eliminación, idempotente (segunda llamada retorna 404 o 204).
- [ ] `HEAD`: como GET sin body (para metadata).
- [ ] `OPTIONS`: preflight / introspección.

**Banderas rojas:**
- `POST` usado para lecturas con "body de query" complejo sin justificación (debería ser GET con query string o recurso `/search`).
- `GET` con efectos secundarios (modifica estado) — peligroso, los prefetchers lo invocan.
- `PUT` usado como PATCH (se sobrescriben campos no enviados).

---

#### `API-REST-011` — Idempotencia garantizada en verbos idempotentes
**Severidad:** high · **Tags:** `idempotency` · **Aplica a:** backend · api

`GET`, `PUT`, `DELETE`, `HEAD`, `OPTIONS` son idempotentes: llamarlos N veces
produce el mismo estado final.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`
**Patrones:**
- `\.delete\([^)]*\)[\s\S]{0,400}\b(throw|raise)\b[^;\n]*\b(NotFound|404)\b`     # DELETE que lanza NotFound (debería ser 204 idempotente)
- `\.put\([^)]*\)[\s\S]{0,500}\b(\$set|\.assign|spread)\b`     # PUT que hace merge parcial (no reemplazo total)
- `(DELETE|delete)[^\n]*\n[^\n]*throw\s+new\s+\w*NotFoundException`     # NestJS: DELETE lanzando NotFound
- `def\s+delete[\s\S]{0,200}raise\s+\w*NotFound`     # Python: delete que falla en re-delete
**Señal de N/A:** no hay handlers de PUT/DELETE/GET en el repo.

**Verificar:**
- [ ] `PUT` con los mismos datos deja el recurso en el mismo estado.
- [ ] `DELETE` de recurso ya borrado no falla con 500 (retorna 404 o 204).
- [ ] `GET` no mutua estado.

(Ver `02-api-diseno/05-idempotencia-async.md` `API-IDEM-001` para `Idempotency-Key` en POST.)

---

#### `API-REST-012` — Safety: `GET`/`HEAD`/`OPTIONS` sin side effects
**Severidad:** critical · **Tags:** `cwe-352` · **Aplica a:** backend · api

Los métodos safe nunca modifican estado del servidor. Violarlo causa CSRF
trivial y comportamiento inesperado de prefetchers.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`
**Patrones:**
- `(\.get|@Get|@app\.get|@router\.get)\([^)]*\)[\s\S]{0,500}\b(INSERT|UPDATE|DELETE|save\(|delete\(|update\(|create\()`     # handler GET con escritura
- `(\.get|@Get)\([^)]*\)[\s\S]{0,500}\b(sendMail|sendEmail|emit\(|publish\(|enqueue\()`     # GET dispara side effect externo
- `(\.head|@Head)\([^)]*\)[\s\S]{0,300}\b(save|delete|update|insert)\b`     # HEAD con mutación
- `(get|GET)\(['"][^'"]*/(confirm|verify|unsubscribe|activate)\b`     # GET con efecto típico (CSRF-vulnerable)
- `(get|GET)\(['"][^'"]*/(redirect|callback)\b[\s\S]{0,400}\b(save|update|create)\(`     # callback GET muta estado
**Señal de N/A:** no hay handlers GET/HEAD/OPTIONS en el repo.

**Verificar:**
- [ ] Ningún handler GET escribe en BD, envía emails, o llama a APIs con side effect.
- [ ] `HEAD` y `OPTIONS` tampoco.
- [ ] Los contadores de visita, tracking, etc. se hacen de forma que no afecten al recurso lógico.

**Banderas rojas:**
- `GET /confirm-email/{token}` que marca como confirmado y redirige.
- `GET /unsubscribe/{token}` que borra la suscripción sin confirmación.

---

## C. Códigos de estado HTTP

#### `API-REST-020` — Códigos 2xx correctos
**Severidad:** medium · **Aplica a:** api

Cada respuesta exitosa tiene el código más específico que aplica.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`
**Patrones:**
- `\.post\([^)]*\)[\s\S]{0,500}\.status\(200\)`     # POST de creación retorna 200 (debería ser 201)
- `\.status\(201\)[\s\S]{0,200}(?!.*Location)`     # 201 sin header Location (heurística aproximada)
- `res\.json\(\s*\{\s*['"]?success['"]?\s*:\s*true`     # body universal {success:true}
- `\.delete\([^)]*\)[\s\S]{0,300}\.status\(200\)\.(json|send)\(`     # DELETE retorna 200 con body en lugar de 204
- `return\s+\{['"]?status['"]?\s*:\s*['"]?ok['"]?`     # status hardcoded "ok" en respuestas
**Señal de N/A:** no hay handlers HTTP en el repo.

**Verificar:**
- [ ] `200 OK`: GET, PUT, PATCH con body de respuesta.
- [ ] `201 Created`: POST que crea recurso (con header `Location: /resource/{id}`).
- [ ] `202 Accepted`: operación asíncrona aceptada (sin resultado final).
- [ ] `204 No Content`: DELETE exitoso o mutaciones sin body.
- [ ] No se usa `200` para todo — distinguir creación, aceptación, vacío.

**Banderas rojas:**
- `200 OK` para creación sin header Location.
- `200 OK` con `{"success": true}` como body universal.

---

#### `API-REST-021` — Códigos 4xx específicos
**Severidad:** medium · **Aplica a:** api

Los errores del cliente se reportan con el código más preciso.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/middleware/**`, `**/errors/**`
**Patrones:**
- `\.status\(500\)[\s\S]{0,300}\b(validation|invalid|missing|required)\b`     # 500 para validación
- `\.status\(200\)[\s\S]{0,200}\{\s*['"]?error['"]?\s*:`     # 200 con {error:...}
- `\.status\(400\)[\s\S]{0,400}\b(not\s*found|unauthorized|forbidden|conflict)\b`     # 400 usado como cajón de sastre
- `throw\s+new\s+HttpException\([^,]+,\s*400\)[\s\S]{0,200}\b(unauthorized|forbidden|not.?found)\b`     # NestJS: 400 en lugar de 401/403/404
- `return\s+\{[^}]*['"]?error['"]?[^}]*\}[\s\S]{0,100}status:\s*200`     # error en cuerpo con status 200
**Señal de N/A:** no hay handlers HTTP ni middleware de errores en el repo.

**Verificar:**
- [ ] `400 Bad Request`: request malformado (JSON inválido, parámetros faltantes).
- [ ] `401 Unauthorized`: sin autenticación o token inválido/expirado.
- [ ] `403 Forbidden`: autenticado pero sin permiso.
- [ ] `404 Not Found`: recurso no existe (o no se revela que existe por razones de seguridad).
- [ ] `405 Method Not Allowed`: método no soportado en esa ruta. Debe incluir header `Allow`.
- [ ] `406 Not Acceptable`: negociación de contenido falló.
- [ ] `409 Conflict`: conflicto de estado (concurrency, uniqueness).
- [ ] `410 Gone`: recurso removido permanentemente.
- [ ] `412 Precondition Failed`: `If-Match`/`If-Unmodified-Since` falló.
- [ ] `413 Content Too Large`: body excede límite.
- [ ] `415 Unsupported Media Type`: Content-Type no soportado.
- [ ] `422 Unprocessable Entity`: body válido sintácticamente pero semánticamente inválido.
- [ ] `429 Too Many Requests`: rate limit (con `Retry-After`).

**Banderas rojas:**
- `400` usado como "algo falló".
- `200 OK` con `{"error": "..."}`.
- `500` para errores de validación.

---

#### `API-REST-022` — Códigos 5xx no exponen internals
**Severidad:** critical · **Tags:** `cwe-209` · **Aplica a:** backend · api

Los errores del servidor no revelan stack traces, paths internos, queries SQL,
ni nombres de clases.

**Dónde buscar:** `**/middleware/**`, `**/errors/**`, `**/handlers/**`, `**/controllers/**`, `**/exception*`, `**/error*.{ts,js,py,go}`
**Patrones:**
- `stack\s*:\s*err\.stack\b`     # filtra stack en respuesta
- `res\.(json|send)\([^)]*\b(err|error)\.(stack|message|toString|name)\b`     # respuesta con campos de error completos
- `traceback\.format_exc\(\)[\s\S]{0,200}(return|jsonify|response)`     # Python: traceback en respuesta
- `JSON\.stringify\(\s*err(or)?\s*\)`     # serialización completa del error
- `app\.use\(\s*errorhandler\(\)\s*\)`     # express errorhandler (verbose en prod)
- `DEBUG\s*=\s*True[\s\S]{0,200}(production|prod)`     # DEBUG=True en prod
**Señal de N/A:** no hay middleware de errores ni handlers HTTP en el repo.

**Verificar:**
- [ ] `500 Internal Server Error`: error inesperado — body genérico, con `request_id` correlacionado al log.
- [ ] `502 Bad Gateway`: proxy/upstream falló.
- [ ] `503 Service Unavailable`: mantenimiento / sobrecarga (con `Retry-After`).
- [ ] `504 Gateway Timeout`: upstream timeout.
- [ ] Ningún 500 expone detalle interno.

**Banderas rojas:**
- `{"error": "AttributeError: ..."}` en el body de un 500.
- Stack trace en el response.

---

#### `API-REST-023` — Consistencia de códigos entre endpoints similares
**Severidad:** medium · **Aplica a:** api

Los mismos tipos de error retornan los mismos códigos en toda la API.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/errors/**`
**Patrones:**
- *(sin patrones mecánicos — revisión humana de coherencia entre endpoints)*
**Señal de N/A:** no hay handlers HTTP en el repo o solo existe un endpoint.

**Verificar:**
- [ ] "Recurso no encontrado" siempre es 404 (no mezcla con 400).
- [ ] "Payload inválido" es 422 (o 400 si lo definiste, pero uniforme).
- [ ] La decisión se documenta en una guía de estilo.

---

## D. Content negotiation y encoding

#### `API-REST-030` — Content-Type correcto
**Severidad:** medium · **Aplica a:** api

Cada request/response declara `Content-Type` correcto, incluido `charset` si
es texto.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/middleware/**`, `openapi*.{yaml,json}`
**Patrones:**
- `setHeader\(['"]Content-Type['"]\s*,\s*['"]text/plain['"]\)[\s\S]{0,200}json`     # Content-Type text/plain con body JSON
- `Content-Type['"]\s*,\s*['"]application/json['"](?!\s*;\s*charset)`     # JSON sin charset
- `res\.send\(\s*JSON\.stringify`     # send con JSON manual (sin Content-Type apropiado)
- `(?<!app\.|router\.)json\s*=\s*['"][^'"]+['"][\s\S]{0,200}return\s+Response\(`     # Python Response con string json sin mimetype
**Señal de N/A:** no hay handlers HTTP en el repo.

**Verificar:**
- [ ] `application/json; charset=utf-8` para JSON.
- [ ] `multipart/form-data` para uploads.
- [ ] Rechazar `Content-Type` no esperado con `415`.
- [ ] Response body declara su tipo.

**Banderas rojas:**
- `text/plain` para respuestas JSON.
- Aceptar cualquier Content-Type sin validación.

---

#### `API-REST-031` — Accept header respetado cuando hay múltiples formatos
**Severidad:** low · **Aplica a:** api

Si la API sirve múltiples formatos (JSON, CSV, XML), se respeta el `Accept`
header del cliente.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `openapi*.{yaml,json}`
**Patrones:**
- `req\.(headers|get)\(['"]?accept['"]?\)`     # se inspecciona Accept (comprobar que dispatchea)
- `res\.format\(\s*\{`     # express res.format (multiformat OK)
- `produces:\s*\[?\s*['"](application/json|text/csv|application/xml)`     # OpenAPI declara múltiples formatos
**Señal de N/A:** la API solo expone un formato (búsqueda de `text/csv|application/xml|text/xml` en handlers no devuelve nada).

**Verificar:**
- [ ] `Accept: application/json` vs `Accept: text/csv` sirven el formato correcto.
- [ ] Si no hay match, retorna 406.

---

## E. Métodos no soportados y endpoints de dev

#### `API-REST-040` — Métodos no soportados retornan 405 con Allow
**Severidad:** low · **Aplica a:** api

Un método HTTP no soportado para la ruta retorna 405 con el header `Allow`
listando los métodos válidos.

**Dónde buscar:** `**/routes/**`, `**/middleware/**`, `**/handlers/**`, `**/api/**`, configuración del framework
**Patrones:**
- `\.status\(405\)[\s\S]{0,200}setHeader\(['"]Allow['"]`     # 405 con Allow (correcto)
- `\.status\(405\)(?![\s\S]{0,200}Allow)`     # 405 sin Allow
- `MethodNotAllowed[\s\S]{0,200}(?!Allow)`     # excepción sin header Allow
**Señal de N/A:** no hay handlers HTTP en el repo (frameworks como Express devuelven 404 por defecto, no 405).

---

#### `API-REST-041` — No hay endpoints de debug/dev en producción
**Severidad:** critical · **Aplica a:** backend

Las rutas `/debug`, `/reset`, `/admin-hidden`, `/dev`, `/_internal` no están
accesibles en producción.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/main.{ts,js,py,go}`, `**/app.{ts,js,py,go}`, `openapi*.{yaml,json}`
**Patrones:**
- `(get|post|put|delete|patch)\(['"]/_?(debug|admin-hidden|dev|internal|reset|test|tmp)\b`     # rutas peligrosas expuestas
- `app\.use\(['"]/(swagger|api-docs|docs)['"](?![\s\S]{0,200}(NODE_ENV|production|auth))`     # Swagger UI sin guard de entorno
- `SwaggerModule\.setup\([^)]*\)(?![\s\S]{0,300}(NODE_ENV|production))`     # NestJS Swagger sin guard
- `app\.config\['DEBUG'\]\s*=\s*True`     # Flask debug habilitado
- `gin\.SetMode\(gin\.DebugMode\)`     # Gin en modo debug
**Señal de N/A:** no hay handlers HTTP ni configuración de framework expuesto.

**Verificar:**
- [ ] No hay rutas de este tipo expuestas o, si existen, están tras red privada y autenticación fuerte.
- [ ] Los docs interactivos (Swagger UI) se protegen o deshabilitan en prod (si revelan endpoints privados).

---

## Checklist resumen

| ID              | Control                                          | Severidad |
| --------------- | ------------------------------------------------ | --------- |
| API-REST-001    | Recursos como sustantivos plurales               | medium    |
| API-REST-002    | Nomenclatura consistente                         | low       |
| API-REST-003    | Anidamiento limitado                             | medium    |
| API-REST-004    | IDs opacos                                       | medium    |
| API-REST-005    | Trailing slash consistente                       | low       |
| API-REST-010    | Método HTTP según semántica                      | high      |
| API-REST-011    | Idempotencia en verbos idempotentes              | high      |
| API-REST-012    | Safety en GET/HEAD/OPTIONS                       | critical  |
| API-REST-020    | Códigos 2xx correctos                            | medium    |
| API-REST-021    | Códigos 4xx específicos                          | medium    |
| API-REST-022    | 5xx no expone internals                          | critical  |
| API-REST-023    | Consistencia de códigos                          | medium    |
| API-REST-030    | Content-Type correcto                            | medium    |
| API-REST-031    | Accept respetado                                 | low       |
| API-REST-040    | 405 con Allow                                    | low       |
| API-REST-041    | No debug endpoints en prod                       | critical  |
