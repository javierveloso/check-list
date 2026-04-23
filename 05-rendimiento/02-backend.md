# 05 · Rendimiento · Backend

> Concurrencia, timeouts, pools, streaming, caché, tareas de fondo.

---

## A. Concurrencia y async

#### `PERF-BE-001` — I/O async en todo el camino crítico
**Severidad:** high · **Aplica a:** backend

El servidor HTTP corre async; toda operación de I/O (BD, HTTP, cache, cola)
es async. (Ver también `CODE-ASYNC-001`.)

**Verificar:**
- [ ] Handlers async con clientes async.
- [ ] Código bloqueante pesado movido a thread pool / worker.
- [ ] No hay mezcla inadvertida de APIs sync dentro del event loop.

---

#### `PERF-BE-002` — Paralelismo limitado donde aporta
**Severidad:** medium · **Aplica a:** backend

Operaciones independientes se ejecutan en paralelo con límite de concurrencia.

**Verificar:**
- [ ] `gather` / `Promise.all` con límite (Semaphore, p-limit) en fan-out.
- [ ] No se paraleliza lo que la BD no puede atender (sobrepasa pool).
- [ ] En operaciones CPU-bound, se usa process pool, no thread pool en runtimes GIL.

---

#### `PERF-BE-003` — Timeouts y backpressure
**Severidad:** critical · **Aplica a:** backend

Todo I/O tiene timeout; las colas de trabajo no aceptan indefinidamente.

(Ver `SEC-HEADERS-041`, `CODE-ASYNC-004`.)

**Verificar:**
- [ ] Timeout en clientes HTTP, BD, cache.
- [ ] Queue size máxima.
- [ ] `503` retornado antes que aceptar más carga en sobrecarga.
- [ ] Circuit breakers donde aporta.

---

#### `PERF-BE-004` — Streaming en responses grandes
**Severidad:** medium · **Aplica a:** backend

Responses largos se sirven en streaming, no se arman en memoria.

**Verificar:**
- [ ] `StreamingResponse` / `chunked transfer encoding` cuando el tamaño es grande o desconocido.
- [ ] Generación de CSV/JSON grande se serializa en chunks.
- [ ] Se respeta backpressure del cliente.

**Banderas rojas:**
- Construir un JSON de 500 MB en memoria y luego devolverlo.

---

## B. Pools y conexiones

#### `PERF-BE-010` — Pools dimensionados y compartidos
**Severidad:** high · **Aplica a:** backend

Hay un pool de conexiones a BD/cache/HTTP compartido por la app, con tamaño
acorde al workload.

**Verificar:**
- [ ] Cliente HTTP creado una vez y reutilizado (no por request).
- [ ] Pool DB con `pool_size` + `max_overflow` razonables.
- [ ] Timeouts para adquirir conexión.
- [ ] Alertas cuando el pool se satura (> 80% uso sostenido).

**Banderas rojas:**
- `httpx.AsyncClient()` dentro de cada handler.
- `create_engine` dentro del handler.

---

#### `PERF-BE-011` — Keep-alive y reutilización
**Severidad:** medium · **Aplica a:** backend

Clientes HTTP reutilizan conexiones (keep-alive). Pools de BD hacen ping/recycle
apropiado.

**Verificar:**
- [ ] `pool_pre_ping` o ping periódico para detectar conexiones muertas.
- [ ] `pool_recycle` configurado (BD cierra conexiones inactivas).
- [ ] HTTP keep-alive habilitado.

---

## C. Caché

#### `PERF-BE-020` — Caché en capas: memoria, remoto, HTTP
**Severidad:** medium · **Aplica a:** backend · infra

Se usa caché en las capas apropiadas: en proceso para datos de configuración
inmutables, remoto (Redis) para compartido, HTTP para clientes.

**Verificar:**
- [ ] Caché in-process con TTL y tamaño máximo (LRU) para valores muy consultados.
- [ ] Caché distribuido (Redis/Memcached) con política de invalidación.
- [ ] Cache-Control en responses HTTP.
- [ ] El cache key incluye dimensiones relevantes (user, locale, versión).

---

#### `PERF-BE-021` — Invalidación de caché correcta
**Severidad:** high · **Tags:** `bug-risk` · **Aplica a:** backend

La invalidación ocurre en las mutaciones; no se sirven datos obsoletos en flujos
críticos.

**Verificar:**
- [ ] Mutation → invalidate relevant keys.
- [ ] TTLs cortos en datos que cambian.
- [ ] Version en el cache key cuando aplica (ej: `user:v2:{id}`).
- [ ] Stale-while-revalidate donde tenga sentido.

**Banderas rojas:**
- Cache infinito sin invalidación.
- Flags de feature leídos de caché sin forma de refrescar.

---

#### `PERF-BE-022` — Cache stampede / thundering herd evitado
**Severidad:** medium · **Aplica a:** backend

Cuando una key expira, no todos los workers reconstruyen simultáneamente.

**Verificar:**
- [ ] Lock por key al regenerar (singleflight pattern).
- [ ] Jitter en TTLs para evitar expiración simultánea.
- [ ] Fallback a valor stale durante el refresh.

---

## D. Background y tareas

#### `PERF-BE-030` — Trabajo pesado delegado a workers
**Severidad:** high · **Aplica a:** backend

Los handlers HTTP no hacen trabajo prolongado; lo mandan a una cola/worker.

**Verificar:**
- [ ] Operaciones > 1-2 s (export, análisis, email batch) van a cola.
- [ ] Hay worker separado procesando.
- [ ] El handler retorna 202 con task_id (ver `API-ASYNC-001`).
- [ ] La cola está limitada y tiene DLQ.

**Banderas rojas:**
- Endpoint HTTP que envía 1000 emails sincrónicamente.

---

#### `PERF-BE-031` — Cron/scheduled jobs idempotentes
**Severidad:** medium · **Aplica a:** backend

Los jobs programados son idempotentes y manejan overlapping.

**Verificar:**
- [ ] Job puede correr dos veces sin efectos duplicados.
- [ ] Lock distribuido impide doble ejecución simultánea cuando importa.
- [ ] Timeouts por job; alertas cuando exceden duración esperada.

---

## E. Memoria

#### `PERF-BE-040` — Memoria monitoreada y acotada
**Severidad:** high · **Aplica a:** backend · infra

El proceso tiene límites de memoria y se monitorea crecimiento/leaks.

**Verificar:**
- [ ] Cgroup/container con memory limit.
- [ ] Métricas de memoria por proceso en dashboards.
- [ ] Alertas ante crecimiento sostenido (memory leak).
- [ ] OOM kill reportado con contexto.

---

#### `PERF-BE-041` — Colecciones y buffers con límites
**Severidad:** medium · **Aplica a:** backend

No se acumulan listas/maps sin límite en memoria.

**Verificar:**
- [ ] Buffers en memoria con tamaño máximo.
- [ ] Streaming cuando el tamaño depende de input externo.
- [ ] Cleanup de caches in-process (tamaño y TTL).

---

## F. Base de datos (alto nivel; detalle en 13)

#### `PERF-BE-050` — Problemas N+1 detectados
**Severidad:** high · **Tags:** `n+1` · **Aplica a:** backend

Las queries no se multiplican en loops. Los ORM usan eager loading cuando
corresponde.

**Verificar:**
- [ ] Revisión de handlers que iteran y consultan en cada iteración.
- [ ] Herramientas (django-debug-toolbar, bullet, log de queries lentas) detectando N+1.
- [ ] Eager loading (selectinload, joinedload, include) donde aporta.

(Más detalle en `13-base-datos/02-queries-transacciones.md`.)

---

#### `PERF-BE-051` — Queries de listado paginadas y con índice
**Severidad:** high · **Aplica a:** backend

Los listados paginan (ver `API-PAGE-001`) y usan índices apropiados.

**Verificar:**
- [ ] Listados con LIMIT/OFFSET razonables o cursor.
- [ ] Índices sobre columnas de filtrado y orden.
- [ ] EXPLAIN en queries críticas.

---

## G. Medición

#### `PERF-BE-060` — Latencias p50/p95/p99 medidas
**Severidad:** high · **Aplica a:** backend · observability

Métricas RED (Rate, Errors, Duration) por endpoint.

**Verificar:**
- [ ] Histogramas de latencia por endpoint.
- [ ] Alertas ante regresión de p95/p99.
- [ ] SLOs documentados.

(Ver `10-observabilidad/`.)

---

#### `PERF-BE-061` — Tracing distribuido para cuellos de botella
**Severidad:** medium · **Aplica a:** backend · observability

Hay tracing que permite identificar spans lentos entre servicios.

(Ver `10-observabilidad/03-trazas-alertas.md`.)

---

## Checklist resumen

| ID             | Control                                            | Severidad |
| -------------- | -------------------------------------------------- | --------- |
| PERF-BE-001    | I/O async en camino crítico                        | high      |
| PERF-BE-002    | Paralelismo limitado                               | medium    |
| PERF-BE-003    | Timeouts y backpressure                            | critical  |
| PERF-BE-004    | Streaming en responses grandes                     | medium    |
| PERF-BE-010    | Pools dimensionados y compartidos                  | high      |
| PERF-BE-011    | Keep-alive y reutilización                         | medium    |
| PERF-BE-020    | Caché en capas                                     | medium    |
| PERF-BE-021    | Invalidación correcta                              | high      |
| PERF-BE-022    | Stampede evitado                                   | medium    |
| PERF-BE-030    | Trabajo pesado a workers                           | high      |
| PERF-BE-031    | Cron idempotente                                   | medium    |
| PERF-BE-040    | Memoria monitoreada                                | high      |
| PERF-BE-041    | Buffers con límites                                | medium    |
| PERF-BE-050    | N+1 detectado y evitado                            | high      |
| PERF-BE-051    | Queries paginadas con índice                       | high      |
| PERF-BE-060    | Latencias p50/p95/p99                              | high      |
| PERF-BE-061    | Tracing distribuido                                | medium    |
