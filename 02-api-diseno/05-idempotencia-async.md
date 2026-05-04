# 02 · API · Idempotencia, concurrencia y operaciones asíncronas

> Idempotency keys, concurrencia optimista, operaciones batch, long-running
> operations (LRO), webhooks y streams.
>
> **Marcos de referencia:** RFC 7232 (Conditional Requests) · Stripe Idempotency · AEP-151 (LRO).

---

## A. Idempotencia en POST

#### `API-IDEM-001` — `Idempotency-Key` soportado en operaciones críticas
**Severidad:** high · **Tags:** `idempotency`, `billing` · **Aplica a:** api · backend

POST que generan efectos costosos o irreversibles (cobro, envío de email, creación
de recurso único) deben aceptar `Idempotency-Key` para evitar duplicados por
reintento del cliente.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/middleware/**`, `**/services/**`, `**/payments/**`, `**/billing/**`, `openapi*.{yaml,json}`
**Patrones:**
- `[Ii]dempotency-?[Kk]ey`     # uso del header (positivo)
- `req\.headers\[['"]idempotency-key['"]\]`     # lectura explícita
- `\.post\(['"][^'"]*/(charges?|payments?|invoices?|refunds?|transfers?|orders?)\b`     # endpoints críticos (verificar idempotency)
- `(charge|capture|refund|sendEmail|sendNotification|enqueue)[\s\S]{0,300}\.post\(`     # creación crítica
- `stripe\.(charges|paymentIntents|subscriptions)\.create\([^)]*\)(?![\s\S]{0,300}idempotency)`     # Stripe sin idempotencyKey
**Señal de N/A:** no hay endpoints POST de pagos/cobros/envíos críticos (búsqueda de `charge|payment|invoice|refund|sendEmail` en handlers no devuelve nada).

**Verificar:**
- [ ] Los endpoints críticos (pagos, envíos, creaciones únicas) aceptan `Idempotency-Key`.
- [ ] La misma key + mismo body → misma respuesta (cacheada por 24 h como mínimo).
- [ ] Key + body distinto → 409 con indicación clara.
- [ ] Hay sistema de almacenamiento con TTL (Redis, BD) para las keys.
- [ ] Documentado qué endpoints la soportan y por cuánto tiempo.

**Banderas rojas:**
- Endpoint `/charges` sin `Idempotency-Key` y retry del cliente produce doble cargo.
- Key ignorada silenciosamente.

**Referencias:** IETF draft-ietf-httpapi-idempotency-key-header.

---

#### `API-IDEM-002` — Reintentos seguros en clientes
**Severidad:** medium · **Aplica a:** frontend · backend (como cliente)

Los clientes que hacen retries usan la misma `Idempotency-Key` por intento, y
solo reintentan ante fallos recuperables.

**Dónde buscar:** `**/clients/**`, `**/services/**`, `**/api/**`, `**/integrations/**`, `**/http/**`
**Patrones:**
- `for\s*\([^)]*\)\s*\{[\s\S]{0,300}\bfetch\(`     # for loop con fetch (retry sin backoff)
- `while\s*\([^)]*\)[\s\S]{0,300}await\s+fetch\(`     # retry while sin backoff
- `axios-retry|got\.extend\([^)]*retry|p-retry|retry-axios`     # librerías de retry (positivo)
- `setTimeout\(\s*\(\)\s*=>[\s\S]{0,200}fetch\([^)]*\)[\s\S]{0,200}\d{3,}\s*\)`     # retry manual con sleep fijo (sin backoff)
- `expo(nential)?[-_]?backoff|jitter\b`     # backoff exponencial (positivo)
- `Retry-After[\s\S]{0,200}parseInt|response\.headers\.get\(['"]retry-after`     # respeta Retry-After (positivo)
**Señal de N/A:** el repo no actúa como cliente de APIs externas (no hay `fetch|axios|http\.Client|requests\.` en `**/clients/**`/`**/services/**`).

**Verificar:**
- [ ] Reintento genera misma key por lote lógico, no una nueva por cada intento.
- [ ] Se respeta `Retry-After`.
- [ ] Backoff exponencial con jitter.
- [ ] No se reintenta 4xx (excepto 408, 425, 429 cuando sea semánticamente correcto).

---

## B. Concurrencia optimista

#### `API-IDEM-003` — ETag / If-Match para updates
**Severidad:** high · **Tags:** `rfc-7232`, `lost-update` · **Aplica a:** api · backend

Las actualizaciones sobre recursos que pueden modificarse concurrentemente usan
`ETag` + `If-Match` para detectar conflicts.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/middleware/**`, `**/services/**`
**Patrones:**
- `If-Match|if_match`     # lectura de If-Match (positivo)
- `setHeader\(['"]ETag['"]`     # ETag emitido (positivo)
- `\.status\(412\)|HttpStatus\.PRECONDITION_FAILED`     # 412 implementado (positivo)
- `\.put\([^)]*\)[\s\S]{0,500}\.(update|save|set)\([^)]*\)(?![\s\S]{0,500}If-Match)`     # PUT sin chequeo If-Match
- `\.patch\([^)]*\)[\s\S]{0,500}\.(update|save|set)\([^)]*\)(?![\s\S]{0,500}If-Match)`     # PATCH sin If-Match
- `\bversion\s*:\s*\w+\.version\s*\+\s*1\b`     # version field (concurrencia optimista alterna - positivo)
**Señal de N/A:** no hay endpoints de actualización (PUT/PATCH) de recursos compartidos en el repo.

**Verificar:**
- [ ] Recursos mutables exponen `ETag` en GET.
- [ ] PUT/PATCH aceptan `If-Match: <etag>` y retornan 412 si no coincide.
- [ ] Sin `If-Match`, se decide una política (rechazar con 428 o aceptar "last write wins" documentado).

**Banderas rojas:**
- Updates sin control de concurrencia en recursos críticos: el último escribe gana silenciosamente.

---

#### `API-IDEM-004` — Locking pesimista solo cuando sea necesario
**Severidad:** medium · **Aplica a:** backend

Se prefiere concurrencia optimista (ETag); pesimista (SELECT FOR UPDATE, advisory
locks) solo cuando el costo de conflict es alto.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/dao/**`, `**/migrations/**`, `**/*.sql`
**Patrones:**
- `SELECT[\s\S]{0,300}\bFOR\s+UPDATE\b`     # SELECT FOR UPDATE
- `pg_advisory_lock|pg_try_advisory_lock`     # advisory locks Postgres
- `\.transaction\([^)]*\)[\s\S]{0,500}lockMode|LockMode\.Pessimistic`     # locks pesimistas en ORM
- `lock_timeout|innodb_lock_wait_timeout|SET\s+lock_timeout`     # timeout de lock (positivo)
- `\.lock\(\s*['"]?pessimistic`     # API explícita de lock pesimista
**Señal de N/A:** no hay capa de servicios/repositorios con SQL ni transacciones en el repo.

**Verificar:**
- [ ] Los locks pesimistas tienen timeout.
- [ ] No se usan en caminos de lectura.
- [ ] Se documenta el scope (row, table, tenant).

---

## C. Batch operations

#### `API-BATCH-001` — Batch con límite y resultado granular
**Severidad:** high · **Aplica a:** api · backend

Si la API acepta operaciones en lote, cada lote está limitado y la respuesta
refleja el resultado por item.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/services/**`, `**/api/**`, `openapi*.{yaml,json}`
**Patrones:**
- `\.post\(['"][^'"]*/(batch|bulk|import|multi)\b`     # endpoints batch
- `req\.body\.items\b|req\.body\.batch\b`     # body con array
- `\.length\s*>\s*\d{2,4}|len\(\w+\)\s*>\s*\d{2,4}`     # validación de tamaño de batch
- `\.status\(207\)|HttpStatus\.MULTI_STATUS`     # 207 Multi-Status (positivo)
- `Promise\.all\(\s*req\.body\.(items|batch)`     # procesa todo en paralelo sin límite (riesgo)
- `for\s*\([^)]*\)\s*\{[\s\S]{0,500}await[\s\S]{0,300}\}(?![\s\S]{0,200}MAX_BATCH)`     # bucle sin límite máximo
**Señal de N/A:** la API no expone endpoints batch/bulk (búsqueda de `/batch|/bulk|/import` no devuelve handlers).

**Verificar:**
- [ ] Tamaño máximo del batch documentado (ej: 100 items).
- [ ] Respuesta indica por cada item: éxito / error con su código y detalle.
- [ ] Política clara: fail-fast vs best-effort (y documentada).
- [ ] Cuando es best-effort, la respuesta usa 207 Multi-Status o estructura equivalente.

**Ejemplo:**
```json
{
  "results": [
    { "index": 0, "status": "created", "id": "abc-1" },
    { "index": 1, "status": "error", "code": "validation_failed", "errors": [...] },
    { "index": 2, "status": "created", "id": "abc-3" }
  ]
}
```

---

#### `API-BATCH-002` — Idempotencia en batch
**Severidad:** medium · **Aplica a:** api

Los batch operations también respetan `Idempotency-Key`, y el cliente puede
reintentar sin duplicar lo ya procesado.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/services/**`, `**/middleware/**`
**Patrones:**
- `\.post\(['"][^'"]*/(batch|bulk)[\s\S]{0,500}[Ii]dempotency-?[Kk]ey`     # endpoint batch + idempotency-key (positivo)
- `\.post\(['"][^'"]*/(batch|bulk)(?![\s\S]{0,800}idempotency)`     # endpoint batch sin idempotency
- `client_token|client_request_id`     # alternativa a idempotency-key (positivo)
**Señal de N/A:** la API no expone endpoints batch/bulk en el repo.

---

## D. Long-Running Operations (LRO)

#### `API-ASYNC-001` — Patrón LRO uniforme
**Severidad:** high · **Tags:** `long-running` · **Aplica a:** api · backend

Las operaciones que toman > ~1–2 s (análisis pesado, exports, indexación) se
modelan como operación asíncrona, no se bloquean en el request HTTP.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/services/**`, `**/queues/**`, `**/jobs/**`, `**/workers/**`
**Patrones:**
- `\.status\(202\)|HttpStatus\.ACCEPTED`     # 202 emitido (positivo)
- `(bullmq|bull|celery|sidekiq|rq|temporal|river|asynq)`     # workers de cola (positivo)
- `await\s+(generateReport|processExport|reindex|importBulk|generatePDF)\b`     # operación pesada inline
- `(get|post)\(['"][^'"]*/(export|report|generate|reindex|backup)\b`     # endpoint que parece pesado
- `\.post\(['"][^'"]*/tasks\b`     # endpoints de tasks (positivo)
- `setTimeout\([^,]+,\s*[1-9]\d{4,}`     # timeouts > 10s (sospechoso de bloqueo)
**Señal de N/A:** la API no expone operaciones largas (no hay endpoints de export/report/reindex y stack_signal.has_workers == false).

**Verificar:**
- [ ] `POST /resources/{id}/long-action` retorna `202 Accepted` con identificador de tarea.
- [ ] Se puede consultar estado: `GET /tasks/{task_id}` o link `Location` en la respuesta.
- [ ] Estados claros: `pending`, `running`, `succeeded`, `failed`, `cancelled`.
- [ ] La tarea tiene timeout máximo.
- [ ] La respuesta al completar incluye link al recurso resultado (si aplica).
- [ ] Las tareas fallidas tienen mensaje legible y código.
- [ ] El cliente puede cancelar: `DELETE /tasks/{task_id}`.

**Banderas rojas:**
- Endpoints "que a veces tardan 30s" bloqueando worker HTTP.
- Estado binario "hecho/no hecho" sin progreso.

---

#### `API-ASYNC-002` — Polling con intervalo adecuado, o webhooks, o streaming
**Severidad:** medium · **Aplica a:** api

El cliente no adivina cuándo preguntar por el estado. El servidor recomienda
intervalo o usa push.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/services/**`, `**/sse/**`, `**/streaming/**`
**Patrones:**
- `setHeader\(['"]Retry-After['"]`     # Retry-After (positivo)
- `text/event-stream`     # SSE (positivo)
- `(socket\.io|ws\b|websocket)`     # WebSocket (alternativa positiva)
- `(get|GET)\(['"][^'"]*/tasks/:?[a-zA-Z_]+/?status\b`     # endpoint de polling de estado (positivo)
- `taskService\.recompute|recalculateStatus`     # endpoint pesado en cada poll (riesgo)
**Señal de N/A:** la API no expone LRO (`API-ASYNC-001` también es N/A).

**Verificar:**
- [ ] Header `Retry-After` en el 202 inicial y en respuestas intermedias.
- [ ] Idealmente: webhook al completar (si el cliente soporta), o SSE/streaming.
- [ ] El endpoint de estado es ligero (no recalcula en cada llamada).

---

#### `API-ASYNC-003` — Idempotencia de LRO
**Severidad:** medium · **Aplica a:** api · backend

Crear dos veces la misma tarea con la misma key retorna la misma tarea, no crea
dos.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/services/**`, `**/queues/**`, `**/jobs/**`
**Patrones:**
- `\.post\(['"][^'"]*/tasks\b[\s\S]{0,500}[Ii]dempotency-?[Kk]ey`     # POST /tasks con idempotency-key (positivo)
- `task_id\s*=\s*uuid\(|task_id\s*=\s*ulid\(`     # task_id opaco (positivo)
- `task_id\s*=\s*\w+\.id\b`     # task_id que es PK del registro (no opaco)
- `jobId\s*:\s*req\.body\.[a-zA-Z_]+`     # jobId provisto por cliente (verificar)
**Señal de N/A:** la API no expone LRO en el repo.

**Verificar:**
- [ ] Los LRO aceptan `Idempotency-Key`.
- [ ] El task_id es opaco y no revela información interna.

---

## E. Webhooks (salientes del sistema)

#### `API-HOOK-001` — Firma de webhook verificable
**Severidad:** critical · **Tags:** `security`, `integrity` · **Aplica a:** backend

Los webhooks que envía el sistema incluyen firma HMAC verificable por el
receptor.

**Dónde buscar:** `**/webhooks/**`, `**/services/**`, `**/notifications/**`, `**/integrations/**`, `**/events/**`
**Patrones:**
- `crypto\.createHmac\(['"]sha(256|512)['"]`     # HMAC con SHA-256/512 (positivo)
- `hmac\.new\([^,]+,\s*[^,]+,\s*hashlib\.sha(256|512)\)`     # Python HMAC (positivo)
- `X-Signature|X-Hub-Signature|Webhook-Signature`     # headers de firma (positivo)
- `X-Timestamp|webhook-timestamp`     # timestamp anti-replay (positivo)
- `fetch\(\s*webhook\.url[\s\S]{0,400}\)(?![\s\S]{0,400}(hmac|sign|hash))`     # POST a webhook sin firma
- `axios\.post\(\s*webhook[\s\S]{0,400}\)(?![\s\S]{0,400}(hmac|sign|signature))`     # idem axios
**Señal de N/A:** el sistema no envía webhooks salientes (no hay endpoints/registros de `webhook` ni servicios de notificación a URLs externas).

**Verificar:**
- [ ] Header con firma (ej: `X-Signature: sha256=...`).
- [ ] Timestamp en header (`X-Timestamp`) para prevenir replay.
- [ ] La documentación explica cómo verificar.
- [ ] Rotación de secretos soportada (permite múltiples secrets simultáneamente durante la rotación).

(Ver también `SEC-CRYPTO-040` para validación en webhooks entrantes.)

---

#### `API-HOOK-002` — Reintentos y DLQ en envío de webhooks
**Severidad:** high · **Aplica a:** backend

Si el receptor falla, el sistema reintenta con backoff y acumula fallos en una
cola muerta tras N intentos.

**Dónde buscar:** `**/webhooks/**`, `**/queues/**`, `**/jobs/**`, `**/workers/**`, `**/services/**`
**Patrones:**
- `(bullmq|bull)[\s\S]{0,500}attempts\s*:\s*\d+`     # BullMQ con attempts (positivo)
- `backoff\s*:\s*\{?\s*type\s*:\s*['"]exponential['"]`     # backoff exponencial (positivo)
- `dead-?letter|DLQ|deadLetterQueue|failed_jobs|dlx`     # DLQ configurado (positivo)
- `(timeout|AbortController|signal)[\s\S]{0,200}fetch\([^)]*webhook`     # timeout en envío (positivo)
- `fetch\(\s*webhook[\s\S]{0,300}\)(?![\s\S]{0,400}(timeout|signal|AbortController))`     # webhook sin timeout
**Señal de N/A:** el sistema no envía webhooks salientes en el repo.

**Verificar:**
- [ ] Reintentos con backoff exponencial.
- [ ] Número máximo de intentos configurado.
- [ ] DLQ o similar para fallos permanentes.
- [ ] UI/log para que el dueño del webhook vea fallos y pueda re-entregar manualmente.
- [ ] Timeouts de entrega definidos.

---

#### `API-HOOK-003` — Eventos entregados con at-least-once y receptor idempotente
**Severidad:** high · **Tags:** `idempotency` · **Aplica a:** api · backend

Los webhooks se entregan at-least-once; el receptor debe manejar duplicados.
El sistema emisor usa `event_id` único para ayudar al receptor a deduplicar.

**Dónde buscar:** `**/webhooks/**`, `**/events/**`, `**/services/**`, `**/notifications/**`, `**/integrations/**`
**Patrones:**
- `event_?id\s*[:=]\s*(uuid|ulid|nanoid)\(`     # event_id opaco (positivo)
- `X-Event-Id|Webhook-Id|event-id`     # header con id de evento (positivo)
- `event_?id\s*=\s*Date\.now\(\)|event_?id\s*=\s*time\(\)`     # id no único (riesgo)
- `attempt_?id|delivery_?id`     # delivery_id distinto de event_id (positivo)
**Señal de N/A:** el sistema no envía webhooks salientes en el repo.

**Verificar:**
- [ ] Cada evento lleva `event_id` único y estable.
- [ ] Se documenta que el receptor debe deduplicar.
- [ ] El sistema no envía el mismo evento con distintos IDs por reintento.

---

## F. Streams y SSE

#### `API-STREAM-001` — Server-Sent Events / streaming documentado
**Severidad:** medium · **Aplica a:** api

Si la API usa SSE o streaming HTTP, hay política clara de heartbeats,
reconnection e IDs de eventos.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/sse/**`, `**/streaming/**`, `**/services/**`
**Patrones:**
- `text/event-stream`     # SSE (positivo)
- `Last-Event-ID|last-event-id`     # soporte reconnection (positivo)
- `setInterval\([^,]+,\s*\d+\s*\)[\s\S]{0,200}heartbeat|: heartbeat`     # heartbeat (positivo)
- `\bid:\s*\$?\{?[a-zA-Z_]+\}?\s*\\n`     # id: en eventos SSE (positivo)
- `retry:\s*\d+`     # campo retry SSE (positivo)
- `res\.write\(\s*`     # write streamed (verificar backpressure)
**Señal de N/A:** la API no expone SSE/streaming (búsqueda de `text/event-stream` no devuelve nada).

**Verificar:**
- [ ] Heartbeat periódico (ej: comment `: heartbeat` cada 15 s).
- [ ] `id:` en cada evento y soporte para `Last-Event-ID` en reconexión.
- [ ] Timeout de reconexión documentado (`retry:`).
- [ ] Backpressure en el servidor (no acumular infinitamente si el cliente es lento).

---

## Checklist resumen

| ID                | Control                                                | Severidad |
| ----------------- | ------------------------------------------------------ | --------- |
| API-IDEM-001      | Idempotency-Key en críticos                            | high      |
| API-IDEM-002      | Reintentos seguros en clientes                         | medium    |
| API-IDEM-003      | ETag / If-Match en updates                             | high      |
| API-IDEM-004      | Locking pesimista justificado                          | medium    |
| API-BATCH-001     | Batch con límite y resultado granular                  | high      |
| API-BATCH-002     | Idempotencia en batch                                  | medium    |
| API-ASYNC-001     | Patrón LRO uniforme                                    | high      |
| API-ASYNC-002     | Polling/webhook/streaming apropiado                    | medium    |
| API-ASYNC-003     | Idempotencia en LRO                                    | medium    |
| API-HOOK-001      | Firma de webhook                                       | critical  |
| API-HOOK-002      | Reintentos y DLQ en webhooks                           | high      |
| API-HOOK-003      | Entrega at-least-once + event_id                       | high      |
| API-STREAM-001    | SSE/streaming con heartbeat y reconnection             | medium    |
