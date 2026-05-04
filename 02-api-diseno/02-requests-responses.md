# 02 · API · Requests, responses y errores

> Estructura del cuerpo de request/response, formato de errores, headers.
>
> **Marcos de referencia:** RFC 7807 (Problem Details) · RFC 9457 · JSON:API · OpenAPI 3.1.

---

## A. Cuerpo del request

#### `API-REQ-001` — JSON como formato por defecto
**Severidad:** low · **Aplica a:** api

El formato estándar para datos estructurados es JSON con charset UTF-8. Otros
formatos solo cuando son requeridos (uploads binarios, CSV de export, etc.).

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `openapi*.{yaml,json}`
**Patrones:**
- `application/x-www-form-urlencoded`     # uso de form-urlencoded en API moderna
- `bodyParser\.urlencoded\(`     # Express acepta urlencoded
- `consumes:\s*\[?\s*['"]application/x-www-form-urlencoded['"]`     # OpenAPI declara form
- `text/xml|application/xml`     # XML como formato principal
**Señal de N/A:** no hay endpoints de API expuestos en el repo.

**Verificar:**
- [ ] POST/PUT/PATCH con datos estructurados usan `application/json`.
- [ ] `multipart/form-data` solo para uploads de archivos.
- [ ] `application/x-www-form-urlencoded` se evita para APIs modernas.

---

#### `API-REQ-002` — Convención consistente de naming en campos
**Severidad:** low · **Aplica a:** api

Todos los campos de request/response siguen una convención: `snake_case` o
`camelCase`, pero no ambos.

**Dónde buscar:** `**/dto/**`, `**/schemas/**`, `**/models/**`, `openapi*.{yaml,json}`, `**/serializers/**`, `**/responses/**`
**Patrones:**
- `['"][a-z]+_[a-z]+['"]\s*:\s*[a-z]`     # snake_case en JSON (key)
- `['"][a-z]+[A-Z][a-zA-Z]*['"]\s*:\s*[a-z]`     # camelCase en JSON (key)
- `@JsonProperty\(['"][a-z]+_[a-z]+['"]\)`     # mezcla snake en Jackson
- `alias\s*=\s*['"][a-z]+_[a-z]+['"]`     # Pydantic alias snake
**Señal de N/A:** no hay DTOs/schemas ni `openapi*` en el repo.

**Verificar:**
- [ ] Todos los campos expuestos siguen la misma convención.
- [ ] Documentada la decisión y enforced por schema.

---

#### `API-REQ-003` — Tipos y formatos estables en campos comunes
**Severidad:** medium · **Aplica a:** api

Fechas, horas, IDs, enums, monedas, cantidades se representan de forma
consistente en toda la API.

**Dónde buscar:** `**/dto/**`, `**/schemas/**`, `**/models/**`, `**/serializers/**`, `openapi*.{yaml,json}`
**Patrones:**
- `\b(amount|price|total|cost|balance)\s*:\s*(float|number|Float|Decimal\.from_float)`     # monedas como float
- `format:\s*['"]?(date|date-time)['"]?[\s\S]{0,300}format:\s*['"]?(date)['"]?`     # mezcla date / date-time
- `toLocaleString\(\)|strftime\(['"]%d/%m`     # fechas formateadas con locale (no ISO)
- `\bstatus\s*:\s*(0|1|2|3)\b`     # enums como números mágicos
- `(?:'|")(true|false|0|1)(?:'|")\s*:\s*[a-zA-Z]`     # booleanos como string
**Señal de N/A:** no hay DTOs/schemas ni `openapi*` en el repo.

**Verificar:**
- [ ] Fechas/timestamps en ISO 8601 con offset: `"2026-03-12T10:30:00Z"` o `"2026-03-12T10:30:00-03:00"`.
- [ ] IDs como UUID en string: `"550e8400-e29b-41d4-a716-446655440000"`.
- [ ] Enums como strings descriptivos: `"pending"`, `"high"`, no números mágicos `1`, `2`.
- [ ] Monedas: enteros en subunidad (céntimos) + código de moneda (`"amount": 1099, "currency": "USD"`).
- [ ] Booleanos como `true`/`false`, no `"true"`/`"1"`.

**Banderas rojas:**
- Campo `status` que a veces es número, a veces string.
- Fechas en formatos inconsistentes (`"2026-03-12"` en un endpoint, `"12/03/2026"` en otro).
- Amounts en floats (pierde precisión).

---

#### `API-REQ-004` — Campos opcionales: omitir vs null documentado
**Severidad:** low · **Aplica a:** api

La API tiene una regla clara para campos ausentes/nulos y la sigue.

**Dónde buscar:** `**/dto/**`, `**/schemas/**`, `**/models/**`, `openapi*.{yaml,json}`, `**/services/**`
**Patrones:**
- `if\s+\w+\s+is\s+None`     # Python: chequeo None (verificar semántica vs ausente)
- `Object\.keys\([^)]+\)\.includes\(`     # JS: distinción ausente / null
- `if\s*\(\s*['"]?[a-zA-Z_]+['"]?\s+in\s+(req\.body|payload)\s*\)`     # JS: chequeo "in" (semántica diferente a undefined)
- `nullable:\s*true`     # OpenAPI nullable (verificar que esté documentado)
**Señal de N/A:** no hay endpoints PATCH ni DTOs en el repo.

**Verificar:**
- [ ] Se documenta qué significa campo ausente vs `null` (ej: "ausente = no se actualiza" en PATCH).
- [ ] La regla es consistente en toda la API.
- [ ] Arrays vacíos se serializan como `[]`, no se omiten.

**Banderas rojas:**
- PATCH donde `{ "field": null }` y omitir `field` tienen el mismo efecto sin aclararlo.

---

#### `API-REQ-005` — Query parameters con convenciones claras
**Severidad:** medium · **Aplica a:** api

Los filtros, paginación, ordenamiento y expansión usan parámetros con nombres
consistentes en toda la API.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `openapi*.{yaml,json}`
**Patrones:**
- `req\.query\.(page|per_page|limit|offset|cursor|pageSize|page_size)\b`     # mezcla de paginadores en el repo
- `req\.query\.(sort|order|sortBy|sort_by|orderBy|order_by)\b`     # mezcla de orden
- `req\.query\.(q|query|search|term|keyword)\b`     # mezcla de búsqueda
- `name:\s*['"](page|per_page|limit|offset|cursor|pageSize)['"]`     # OpenAPI: paginadores múltiples
**Señal de N/A:** no hay endpoints con query params en el repo.

**Verificar:**
- [ ] Paginación uniforme: `page`/`per_page` o `limit`/`offset` o `cursor` — pero uno elegido.
- [ ] Ordenamiento: `sort=-created_at,name` o `sort_by=created_at&order=desc` — consistente.
- [ ] Filtros: `?status=active&type=foo`.
- [ ] Búsqueda: `?q=texto` con longitud mínima documentada.
- [ ] Parámetros desconocidos se ignoran o se rechazan consistentemente (documentado).

---

## B. Cuerpo de la respuesta

#### `API-RES-001` — Estructura predecible y versionable
**Severidad:** medium · **Aplica a:** api

Las respuestas tienen forma consistente. Decisión documentada: o se retorna el
recurso "plano", o envuelto en `data`/`meta`.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/responses/**`, `openapi*.{yaml,json}`
**Patrones:**
- `res\.json\(\s*\{\s*['"]data['"]\s*:`     # respuestas envueltas en data
- `res\.json\(\s*\{\s*['"]results['"]\s*:`     # respuestas envueltas en results
- `res\.json\(\s*\{\s*['"]items['"]\s*:`     # respuestas envueltas en items
- `res\.json\(\s*\[`     # array directo en lista (no envuelto)
**Señal de N/A:** no hay handlers HTTP en el repo.

**Verificar:**
- [ ] Recursos individuales: estructura estable (plano o con `data`).
- [ ] Listas: objeto con `items` (o `data`) y metadata de paginación.
- [ ] La decisión (envolver o no) es consistente en toda la API.

**Ejemplos:**
```json
// Recurso individual (plano)
{ "id": "...", "name": "Foo", "created_at": "..." }

// Lista paginada (envuelta)
{
  "items": [...],
  "meta": { "page": 1, "per_page": 20, "total": 157, "total_pages": 8 },
  "links": { "self": "...", "next": "...", "prev": null }
}
```

---

#### `API-RES-002` — Campos sensibles excluidos de la respuesta
**Severidad:** critical · **Tags:** `cwe-200`, `owasp-a02` · **Aplica a:** api

El modelo de respuesta nunca incluye hashes de password, tokens, secretos,
campos internos administrativos que no conciernen al usuario.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/serializers/**`, `**/services/**`, `**/repositories/**`
**Patrones:**
- `res\.json\(\s*req\.body\b`     # echo del request al cliente
- `res\.json\(\s*user\b(?![\.\w]*\.(toJSON|toDTO|safe|public))`     # serializa user crudo
- `JSON\.stringify\(.*\b(password|token|secret|apiKey|api_key|private_key)\b`     # serializa campo sensible
- `\bmodel_to_dict\(|\.__dict__\b|\.dict\(\)`     # Python: serialización completa de objeto
- `\.find\(\)\.select\(['"]\+password['"]\)`     # Mongoose select +password
- `prisma\.\w+\.find\w*\([^)]*\)(?![\s\S]{0,200}select)`     # Prisma find sin select (serializa todo)
**Señal de N/A:** no hay handlers HTTP ni serializers en el repo.

**Verificar:**
- [ ] Schema de response declarado (response_model, serializer) con allowlist explícito.
- [ ] No se serializa el modelo completo de BD sin transformación.
- [ ] Campos internos (`password_hash`, `internal_notes`, `stripe_customer_id`) excluidos.

**Banderas rojas:**
- Serialización genérica del objeto de BD.
- `return user.__dict__`, `return model_to_dict(user)` sin filtro.

---

#### `API-RES-003` — Campos calculados documentados
**Severidad:** low · **Aplica a:** api

Los campos derivados/calculados (totals, status computado, booleanos de permiso)
se documentan y son consistentes.

**Dónde buscar:** `**/dto/**`, `**/serializers/**`, `**/responses/**`, `openapi*.{yaml,json}`
**Patrones:**
- `\bcan_(edit|delete|view|update|read)\b`     # campos de permiso calculado
- `\bis_(owner|admin|member|active)\b`     # booleanos derivados
- `\b(total|subtotal|count|sum)_\w+\b`     # totales calculados
- `@computed_field|@property\b`     # decoradores de cálculo
**Señal de N/A:** no hay DTOs, serializers ni `openapi*` en el repo.

**Verificar:**
- [ ] Los campos calculados se documentan en OpenAPI.
- [ ] Se documentan sus dependencias (ej: `can_edit` depende del usuario que consulta).

---

## C. Formato de errores

#### `API-ERR-001` — Estructura de error uniforme y predecible
**Severidad:** high · **Tags:** `rfc-7807` · **Aplica a:** api

Todos los errores retornan la misma estructura. Se recomienda Problem Details
(RFC 7807/9457) o una variante consistente.

**Dónde buscar:** `**/errors/**`, `**/middleware/**`, `**/handlers/**`, `**/exception*`, `**/filters/**`
**Patrones:**
- `res\.json\(\s*\{\s*['"]error['"]\s*:`     # forma {error: ...}
- `res\.json\(\s*\{\s*['"]message['"]\s*:`     # forma {message: ...}
- `res\.json\(\s*\{\s*['"]status['"]\s*:\s*['"]error['"]`     # forma {status:"error", ...}
- `application/problem\+json`     # uso de RFC 7807 (positivo)
- `stack\s*:\s*err\.stack|trace\s*:\s*err`     # incluye stack/trace en respuesta
**Señal de N/A:** no hay middleware de errores ni handlers HTTP en el repo.

**Verificar:**
- [ ] Cada error tiene: código interno, mensaje legible, campo o recurso afectado (si aplica), id del request.
- [ ] La estructura es idéntica para 4xx y 5xx.
- [ ] El `Content-Type` es `application/problem+json` si se sigue RFC 7807.

**Ejemplo (Problem Details):**
```json
{
  "type": "https://api.example.com/errors/resource-not-found",
  "title": "Resource not found",
  "status": 404,
  "detail": "The order with id 'ord_123' does not exist.",
  "instance": "/orders/ord_123",
  "code": "resource_not_found",
  "request_id": "req_01HXX..."
}
```

**Alternativa simple (si no se adopta RFC 7807):**
```json
{
  "error": {
    "code": "resource_not_found",
    "message": "The order with id 'ord_123' does not exist.",
    "request_id": "req_01HXX..."
  }
}
```

**Banderas rojas:**
- Errores con distintas formas en distintos endpoints.
- `{"status": "error", "data": null, "message": "..."}` en uno y `{"error": "..."}` en otro.
- Incluir `stack` o `trace` en producción.

---

#### `API-ERR-002` — Errores de validación detallan el campo y la razón
**Severidad:** high · **Aplica a:** api

Cuando una validación falla, la respuesta indica qué campo(s) y por qué, para
que el cliente pueda ayudar al usuario.

**Dónde buscar:** `**/validators/**`, `**/middleware/**`, `**/dto/**`, `**/schemas/**`, `**/handlers/**`
**Patrones:**
- `\b(zod|joi|yup|class-validator|pydantic|marshmallow|cerberus)\b`     # uso de librerías de validación (positivo)
- `throw\s+new\s+\w*ValidationException\(['"][^'"]+['"]\)(?![\s\S]{0,200}(field|path|errors))`     # validación sin contexto de campo
- `res\.status\(400\)\.json\(\s*\{\s*['"]?message['"]?\s*:\s*['"](Invalid|Validation failed)['"]`     # mensajes de validación genéricos
- `abortEarly:\s*true`     # Joi/Yup detiene en primer error (no reporta todos)
**Señal de N/A:** no hay endpoints con bodies de request validados en el repo.

**Verificar:**
- [ ] Cada error de validación incluye: campo (path), mensaje, código.
- [ ] Se reportan todos los errores a la vez (no uno a uno), cuando es viable.
- [ ] El path al campo usa JSON Pointer o dot notation consistente.

**Ejemplo:**
```json
{
  "code": "validation_failed",
  "message": "Request validation failed",
  "errors": [
    { "path": "/name", "code": "required", "message": "Name is required" },
    { "path": "/email", "code": "invalid_format", "message": "Must be a valid email" },
    { "path": "/items/0/quantity", "code": "min_value", "message": "Must be ≥ 1" }
  ]
}
```

---

#### `API-ERR-003` — No filtrar detalle interno en mensajes de error
**Severidad:** critical · **Tags:** `cwe-209` · **Aplica a:** backend · api

Los mensajes de error no revelan queries SQL, paths del servidor, versiones
internas, nombres de librerías o IPs internas.

**Dónde buscar:** `**/middleware/**`, `**/errors/**`, `**/handlers/**`, `**/exception*`, `**/filters/**`
**Patrones:**
- `stack\s*:\s*(err|error|e)\.stack`     # stack en respuesta
- `traceback\.format_exc\(\)[\s\S]{0,200}return`     # Python: traceback en respuesta
- `(message|detail)\s*:\s*(err|error|e)\.(message|toString)\(\)`     # mensaje de excepción crudo
- `JSON\.stringify\(\s*(err|error)\b`     # serializa error completo
- `app\.use\(\s*errorhandler\(\)`     # express errorhandler verbose
- `DEBUG\s*=\s*True`     # Flask/Django DEBUG=True
**Señal de N/A:** no hay middleware de errores ni handlers HTTP en el repo.

**Verificar:**
- [ ] Excepciones internas se traducen a mensajes genéricos.
- [ ] Los logs conservan el detalle; la respuesta al cliente no.
- [ ] `request_id` permite correlacionar la respuesta con el log completo.

**Banderas rojas:**
- `"message": "null value in column \"tenant_id\" violates not-null constraint"`.
- Respuestas que incluyen `trace` o `stack`.

---

#### `API-ERR-004` — Tasa de error visible pero sin detalle sensible
**Severidad:** medium · **Aplica a:** api

Errores de autenticación y autorización no revelan información innecesaria.

**Dónde buscar:** `**/auth/**`, `**/middleware/**`, `**/handlers/login*`, `**/controllers/auth*`, `**/services/auth*`
**Patrones:**
- `(message|detail)\s*:\s*['"](User\s+not\s+found|No\s+such\s+user|Email\s+not\s+registered)['"]`     # 401 confirma existencia de usuario
- `(message|detail)\s*:\s*['"](Wrong\s+password|Invalid\s+password|Bad\s+password)['"]`     # diferencia password vs usuario
- `\.status\(404\)[\s\S]{0,300}(User|Account|Resource)\.findOne`     # 404 después de findOne (revela existencia)
- `Retry-After[\s\S]{0,200}\b(quota|remaining|limit)\b`     # 429 que revela cuota interna
**Señal de N/A:** no hay endpoints de autenticación/autorización en el repo.

**Verificar:**
- [ ] `401` y `403` no confirman la existencia del recurso.
- [ ] Login fallido no distingue "usuario no existe" de "password inválida" (ver `SEC-AUTH-031`).
- [ ] Los `429` incluyen `Retry-After` pero no la cuota del atacante.

---

## D. Headers de respuesta

#### `API-RES-010` — Headers operacionales estándar
**Severidad:** medium · **Aplica a:** api

Cada respuesta incluye headers que faciliten diagnóstico, caché y correlación.

**Dónde buscar:** `**/middleware/**`, `**/handlers/**`, `**/controllers/**`, `**/api/**`, configuración del framework
**Patrones:**
- `setHeader\(['"]?X-Request-Id['"]?`     # X-Request-Id presente (positivo)
- `setHeader\(['"]?Traceparent['"]?`     # Traceparent (positivo)
- `setHeader\(['"]?(ETag|Last-Modified)['"]?`     # ETag/Last-Modified (positivo)
- `setHeader\(['"]?Cache-Control['"]?`     # Cache-Control explícito (positivo)
- `app\.use\(\s*requestId\(\)|app\.use\(\s*correlationId\(`     # middleware de correlación
**Señal de N/A:** no hay middleware ni handlers HTTP en el repo.

**Verificar:**
- [ ] `Content-Type` preciso.
- [ ] `Content-Length` o `Transfer-Encoding: chunked`.
- [ ] `X-Request-Id` / `Traceparent` para correlación con logs.
- [ ] `Cache-Control` apropiado al tipo de respuesta.
- [ ] `ETag` / `Last-Modified` en recursos cacheables.

---

#### `API-RES-011` — `Location` en 201
**Severidad:** low · **Aplica a:** api

Las creaciones exitosas incluyen `Location` apuntando al recurso nuevo.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`
**Patrones:**
- `\.status\(201\)[\s\S]{0,300}setHeader\(['"]Location['"]`     # 201 con Location (positivo)
- `\.status\(201\)(?![\s\S]{0,300}Location)`     # 201 sin Location
- `HttpStatus\.CREATED[\s\S]{0,300}(?!Location)`     # NestJS CREATED sin Location
- `return\s+\(\)?\s*(jsonify|Response)\([^)]*\)\s*,\s*201(?![\s\S]{0,200}Location)`     # Flask 201 sin Location
**Señal de N/A:** no hay endpoints POST de creación en el repo.

**Verificar:**
- [ ] `201 Created` siempre incluye `Location`.

---

#### `API-RES-012` — Respuestas vacías retornan 204 o cuerpo vacío explícito
**Severidad:** low · **Aplica a:** api

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`
**Patrones:**
- `\.delete\([^)]*\)[\s\S]{0,300}\.status\(200\)\.(json|send)\(\s*\{`     # DELETE retorna 200 con body
- `\.status\(404\)[\s\S]{0,300}(empty|no\s+results|no\s+items)`     # lista vacía como 404
- `return\s+null[\s\S]{0,100}\.json\(`     # retorna null en lugar de []
- `items\s*:\s*null|results\s*:\s*null|data\s*:\s*null`     # arrays como null
**Señal de N/A:** no hay handlers HTTP en el repo.

- [ ] GET de lista sin resultados retorna 200 con `items: []` (no 404).
- [ ] DELETE exitoso retorna 204 sin body.
- [ ] PUT/PATCH sin body de vuelta retornan 204; si devuelven recurso, 200.

---

## E. Negociación de contenido y caché

#### `API-RES-020` — Cache-Control explícito
**Severidad:** medium · **Aplica a:** api

Cada respuesta tiene `Cache-Control` que refleja la verdadera cacheabilidad.

**Dónde buscar:** `**/middleware/**`, `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, configuración de CDN/proxy
**Patrones:**
- `Cache-Control['"]?\s*,\s*['"]public[^'"]*['"]`     # Cache-Control public (¿en endpoint con auth?)
- `Cache-Control['"]?\s*,\s*['"]no-store['"]`     # no-store (positivo en endpoints sensibles)
- `Vary['"]?\s*,\s*['"][^'"]*Authorization`     # Vary con Authorization (positivo)
- `setHeader\(['"]Cache-Control['"]\s*,\s*['"]public[\s\S]{0,500}(req\.user|authenticate|auth\()`     # public + auth
**Señal de N/A:** no hay handlers HTTP ni middleware en el repo.

**Verificar:**
- [ ] Respuestas privadas al usuario: `private, no-store` o `private, max-age=...`.
- [ ] Datos públicos cacheables: `public, max-age=...`.
- [ ] Datos que nunca deben cachearse: `no-store`.
- [ ] Varía correctamente con `Vary: Authorization, Accept-Language`.

**Banderas rojas:**
- `Cache-Control: public` en endpoints con datos de usuario.
- Ausencia de `Vary: Authorization` en respuestas autenticadas que pasan por CDN.

---

#### `API-RES-021` — ETag y revalidación condicional
**Severidad:** medium · **Aplica a:** api

Los recursos cacheables exponen `ETag` (o `Last-Modified`) y el servidor responde
`304` ante `If-None-Match` / `If-Modified-Since`.

**Dónde buscar:** `**/middleware/**`, `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`
**Patrones:**
- `setHeader\(['"]ETag['"]`     # ETag emitido (positivo)
- `setHeader\(['"]Last-Modified['"]`     # Last-Modified (positivo)
- `If-None-Match|if_none_match`     # servidor lee If-None-Match
- `If-Match|if_match`     # servidor lee If-Match (concurrencia optimista)
- `\.status\(304\)`     # respuesta 304 implementada
**Señal de N/A:** no hay handlers de recursos cacheables (GET de entidades) en el repo.

**Verificar:**
- [ ] `ETag` generado determinísticamente del contenido.
- [ ] `304 Not Modified` soportado.
- [ ] `If-Match` soportado en PUT/PATCH para concurrencia optimista (ver `API-IDEM-003`).

---

## Checklist resumen

| ID             | Control                                          | Severidad |
| -------------- | ------------------------------------------------ | --------- |
| API-REQ-001    | JSON por defecto                                 | low       |
| API-REQ-002    | Naming consistente                               | low       |
| API-REQ-003    | Tipos y formatos estables                        | medium    |
| API-REQ-004    | Campos opcionales: regla clara                   | low       |
| API-REQ-005    | Query params con convenciones                    | medium    |
| API-RES-001    | Estructura predecible                            | medium    |
| API-RES-002    | Campos sensibles excluidos                       | critical  |
| API-RES-003    | Campos calculados documentados                   | low       |
| API-ERR-001    | Estructura de error uniforme                     | high      |
| API-ERR-002    | Errores de validación detallados                 | high      |
| API-ERR-003    | Sin filtrar internals                            | critical  |
| API-ERR-004    | No filtrar info en 401/403/429                   | medium    |
| API-RES-010    | Headers operacionales                            | medium    |
| API-RES-011    | Location en 201                                  | low       |
| API-RES-012    | Respuestas vacías correctas                      | low       |
| API-RES-020    | Cache-Control explícito                          | medium    |
| API-RES-021    | ETag + revalidación                              | medium    |
