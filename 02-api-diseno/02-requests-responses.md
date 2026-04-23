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

**Verificar:**
- [ ] POST/PUT/PATCH con datos estructurados usan `application/json`.
- [ ] `multipart/form-data` solo para uploads de archivos.
- [ ] `application/x-www-form-urlencoded` se evita para APIs modernas.

---

#### `API-REQ-002` — Convención consistente de naming en campos
**Severidad:** low · **Aplica a:** api

Todos los campos de request/response siguen una convención: `snake_case` o
`camelCase`, pero no ambos.

**Verificar:**
- [ ] Todos los campos expuestos siguen la misma convención.
- [ ] Documentada la decisión y enforced por schema.

---

#### `API-REQ-003` — Tipos y formatos estables en campos comunes
**Severidad:** medium · **Aplica a:** api

Fechas, horas, IDs, enums, monedas, cantidades se representan de forma
consistente en toda la API.

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

**Verificar:**
- [ ] Los campos calculados se documentan en OpenAPI.
- [ ] Se documentan sus dependencias (ej: `can_edit` depende del usuario que consulta).

---

## C. Formato de errores

#### `API-ERR-001` — Estructura de error uniforme y predecible
**Severidad:** high · **Tags:** `rfc-7807` · **Aplica a:** api

Todos los errores retornan la misma estructura. Se recomienda Problem Details
(RFC 7807/9457) o una variante consistente.

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

**Verificar:**
- [ ] `401` y `403` no confirman la existencia del recurso.
- [ ] Login fallido no distingue "usuario no existe" de "password inválida" (ver `SEC-AUTH-031`).
- [ ] Los `429` incluyen `Retry-After` pero no la cuota del atacante.

---

## D. Headers de respuesta

#### `API-RES-010` — Headers operacionales estándar
**Severidad:** medium · **Aplica a:** api

Cada respuesta incluye headers que faciliten diagnóstico, caché y correlación.

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

**Verificar:**
- [ ] `201 Created` siempre incluye `Location`.

---

#### `API-RES-012` — Respuestas vacías retornan 204 o cuerpo vacío explícito
**Severidad:** low · **Aplica a:** api

- [ ] GET de lista sin resultados retorna 200 con `items: []` (no 404).
- [ ] DELETE exitoso retorna 204 sin body.
- [ ] PUT/PATCH sin body de vuelta retornan 204; si devuelven recurso, 200.

---

## E. Negociación de contenido y caché

#### `API-RES-020` — Cache-Control explícito
**Severidad:** medium · **Aplica a:** api

Cada respuesta tiene `Cache-Control` que refleja la verdadera cacheabilidad.

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
