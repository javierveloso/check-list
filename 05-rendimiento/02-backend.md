# 05 · Rendimiento · Backend

> Concurrencia, timeouts, pools, streaming, caché, tareas de fondo.

---

## A. Concurrencia y async

#### `PERF-BE-001` — I/O async en todo el camino crítico
**Severidad:** high · **Aplica a:** backend

El servidor HTTP corre async; toda operación de I/O (BD, HTTP, cache, cola)
es async. (Ver también `CODE-ASYNC-001`.)

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/handlers/**`, `**/middleware/**`, `**/controllers/**`
**Patrones:**
- `(readFileSync|writeFileSync|execSync|spawnSync)` # APIs sync de Node
- `requests\.(get|post|put|delete)\(`      # python sync HTTP en código async
- `time\.sleep\(`                          # sync sleep en código async
- `\bdef\s+\w+[\s\S]{0,500}\bawait\b`      # def (sync) con await dentro (error)
- `async\s+def\s+\w+[\s\S]{0,500}requests\.` # async def usando librería sync
- `(asyncio|aiohttp|httpx|fastapi|express|fastify|nestjs)` # stack async (positivo)

**Señal de N/A:** runtime sin event loop (Rails sync, PHP-FPM, scripts CLI).

**Verificar:**
- [ ] Handlers async con clientes async.
- [ ] Código bloqueante pesado movido a thread pool / worker.
- [ ] No hay mezcla inadvertida de APIs sync dentro del event loop.

---

#### `PERF-BE-002` — Paralelismo limitado donde aporta
**Severidad:** medium · **Aplica a:** backend

Operaciones independientes se ejecutan en paralelo con límite de concurrencia.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/handlers/**`
**Patrones:**
- `Promise\.all\(\s*\[`                    # paralelización (revisar límite)
- `asyncio\.gather\(`                      # paralelización Python
- `(p-limit|p-map|bottleneck|semaphore)`   # libs de límite
- `Semaphore\(\s*\d+\s*\)|asyncio\.Semaphore`  # semáforo explícito
- `for[\s\S]{0,200}await[\s\S]{0,200}push\([\s\S]{0,200}Promise\.all` # acumular promesas + all
- `workerData|cluster\.fork\(|multiprocessing\.Pool` # process pool

**Señal de N/A:** sistema sin operaciones independientes paralelizables.

**Verificar:**
- [ ] `gather` / `Promise.all` con límite (Semaphore, p-limit) en fan-out.
- [ ] No se paraleliza lo que la BD no puede atender (sobrepasa pool).
- [ ] En operaciones CPU-bound, se usa process pool, no thread pool en runtimes GIL.

---

#### `PERF-BE-003` — Timeouts y backpressure
**Severidad:** critical · **Aplica a:** backend

Todo I/O tiene timeout; las colas de trabajo no aceptan indefinidamente.

(Ver `SEC-HEADERS-041`, `CODE-ASYNC-004`.)

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/clients/**`, `**/config/**`, `**/data-source.*`
**Patrones:**
- `axios\.(get|post|put|delete|create)\([^)]*\)(?![\s\S]{0,200}timeout)` # axios sin timeout
- `fetch\([^)]+\)(?![\s\S]{0,200}signal)`  # fetch sin AbortController
- `httpx\.\w+\([\s\S]{0,200}\)(?![\s\S]{0,200}timeout)` # httpx sin timeout
- `(connectTimeoutMS|connectionTimeoutMillis|acquireTimeoutMillis|statement_timeout)` # timeouts BD (positivo)
- `setTimeout\(.*server\.\w+|server\.setTimeout\(` # timeout HTTP
- `(circuit-breaker|opossum|cockatiel|tenacity)`  # circuit breakers

**Señal de N/A:** servicio sin I/O externo (computación pura).

**Verificar:**
- [ ] Timeout en clientes HTTP, BD, cache.
- [ ] ORM / cliente de BD con `connectTimeout`, `acquireTimeoutMillis` y `statement_timeout` configurados explícitamente.
- [ ] Queue size máxima.
- [ ] `503` retornado antes que aceptar más carga en sobrecarga.
- [ ] Circuit breakers donde aporta.

**Banderas rojas:**
- `TypeORM DataSource` sin `connectTimeoutMS` / `acquireTimeoutMillis` — un pico de carga deja workers de Node.js bloqueados indefinidamente.
- Express.js sin timeout a nivel HTTP (`server.setTimeout()`, middleware `connect-timeout`).
- Clientes Axios/fetch sin `timeout` ni `signal` configurado.

**Ejemplo de hallazgo:**
```yaml
control_id: PERF-BE-003
severity: critical
file: src/config/data-source.ts
line: 3
evidence: |
  export const AppDataSource = new DataSource({
    type: 'postgres',
    host: process.env.DB_HOST,
    // Sin connectTimeoutMS, acquireTimeoutMillis, statement_timeout
    extra: { max: 10 },
  });
explanation: |
  Sin timeout en el pool de TypeORM, una query lenta o una conexión rota
  deja el worker de Node.js esperando indefinidamente. En picos de carga
  el pool se agota y los requests se apilan sin ningún límite de espera,
  degradando toda la aplicación hasta timeout del cliente.
suggestion: |
  extra: {
    max: 10,
    connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000,
    statement_timeout: 30000,
  },
```

---

#### `PERF-BE-004` — Streaming en responses grandes
**Severidad:** medium · **Aplica a:** backend

Responses largos se sirven en streaming, no se arman en memoria.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/handlers/**`, `**/controllers/**`, `**/exports/**`
**Patrones:**
- `(StreamingResponse|res\.write\(|response\.write|stream\.pipe)` # streaming explícito
- `JSON\.stringify\([\s\S]{0,200}\.findAll\(\)|\.find\(\{\}\)` # JSON masivo en memoria
- `Buffer\.concat\(\[[\s\S]{0,200}\]\)`    # concatenación de buffers grandes
- `\.toBuffer\(\)|readAll\(`               # carga completa en memoria
- `Transfer-Encoding:\s*chunked`           # chunked HTTP (positivo)
- `csv-stringify|fast-csv|@fast-csv/format` # libs CSV streaming

**Señal de N/A:** API sin endpoints que retornen payloads grandes.

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

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/data-source.*`, `**/db.{ts,js,py}`, `**/config/**`, `**/*.module.ts`
**Patrones:**
- `httpx\.AsyncClient\(\)|new\s+axios\.create\(\)` # cliente creado por request (revisar scope)
- `create_engine\(|new\s+DataSource\(|new\s+Pool\(`  # init de pool (revisar scope)
- `(pool_size|poolSize|max:\s*\d+|max_pool_size)` # tamaño de pool configurado
- `idleTimeoutMillis|idle_timeout|max_overflow` # parámetros de pool
- `function\s+\w+Handler[\s\S]{0,500}new\s+(Pool|Client|AsyncClient)` # pool dentro de handler

**Señal de N/A:** servicio stateless sin conexiones a BD/HTTP externos.

**Verificar:**
- [ ] Cliente HTTP creado una vez y reutilizado (no por request).
- [ ] Pool DB con `pool_size` + `max_overflow` razonables.
- [ ] Timeouts para adquirir conexión.
- [ ] Alertas cuando el pool se satura (> 80% uso sostenido).

**Banderas rojas:**
- `httpx.AsyncClient()` dentro de cada handler.
- `create_engine` dentro del handler.
- `TypeORM DataSource` sin bloque `extra: { max: N, idleTimeoutMillis: N }` — el pool puede crecer sin límite y agotar las conexiones disponibles en PostgreSQL.

---

#### `PERF-BE-011` — Keep-alive y reutilización
**Severidad:** medium · **Aplica a:** backend

Clientes HTTP reutilizan conexiones (keep-alive). Pools de BD hacen ping/recycle
apropiado.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/clients/**`, `**/db.*`, `**/data-source.*`
**Patrones:**
- `(pool_pre_ping|pool_recycle|pingInterval|keepAlive)` # configuración de recycle
- `keepAlive\s*:\s*true|http\.Agent\(\{[^}]*keepAlive` # agent con keep-alive
- `new\s+http\.Agent\(|new\s+https\.Agent\(` # agent custom
- `Connection:\s*close`                    # forzar cierre (anti-pattern)
- `maxSockets|maxFreeSockets`              # límites de socket

**Señal de N/A:** servicio sin clientes HTTP salientes ni BD persistente.

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

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/middleware/**`, `**/cache/**`
**Patrones:**
- `(lru-cache|node-cache|memoizee|cachetools|@nestjs/cache-manager)` # cache in-process
- `(redis|ioredis|aioredis|node-redis|memcached)` # cache remoto
- `Cache-Control[\s\S]{0,100}(public|private|max-age)` # cache HTTP
- `\bttl\s*[:=]\s*\d+|expiresIn\s*:\s*\d+` # TTL configurado
- `cache.*key.*[\$\{].*user.*[\$\{].*locale|cache.*key.*v\d+` # key con dimensiones

**Señal de N/A:** sistema sin necesidad de caché (latencia ya aceptable).

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

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/cache/**`, `**/repositories/**`
**Patrones:**
- `(invalidate|del|delete|evict|clear)Cache|cache\.del\(`  # invalidación
- `cache\.set\([^)]+\)(?![\s\S]{0,200}(ttl|expire))`        # set sin TTL
- `(stale-while-revalidate|swr)`           # SWR pattern
- `cache\s*[:=].*v\d+:|version\s*:|:v\d+:` # versionado en key
- `\bttl\s*[:=]\s*-1|expire.*0|forever`    # TTL infinito (revisar)

**Señal de N/A:** sistema sin caché de datos mutables.

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

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/cache/**`, `**/services/**`
**Patrones:**
- `(singleflight|dataloader|p-memoize|asyncio\.Lock)` # patrón singleflight
- `(jitter|randomize.*ttl|ttl\s*[+\-]\s*Math\.random)` # jitter en TTL
- `\bttl\s*[:=]\s*\d{3,}\s*[*]\s*\(1\s*[+\-]` # TTL con variación
- `redis\.(set|setex)[\s\S]{0,500}(NX|XX|EX)`  # locks distribuidos
- `(staleWhileRevalidate|stale-while-revalidate)` # SWR

**Señal de N/A:** caché con baja concurrencia o sin reconstrucción cara.

**Verificar:**
- [ ] Lock por key al regenerar (singleflight pattern).
- [ ] Jitter en TTLs para evitar expiración simultánea.
- [ ] Fallback a valor stale durante el refresh.

---

## D. Background y tareas

#### `PERF-BE-030` — Trabajo pesado delegado a workers
**Severidad:** high · **Aplica a:** backend

Los handlers HTTP no hacen trabajo prolongado; lo mandan a una cola/worker.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/handlers/**`, `**/controllers/**`, `**/workers/**`, `**/queues/**`, `**/jobs/**`
**Patrones:**
- `(bullmq|bull|celery|sidekiq|rq|sqs|rabbitmq|kafka|pgmq)` # libs de cola
- `\.add\(['"]|\.enqueue\(|\.dispatch\(|\.delay\(` # encolado de jobs
- `for[\s\S]{0,500}sendMail\(|forEach[\s\S]{0,500}sendMail` # loops síncronos pesados
- `setTimeout\([\s\S]{0,200}\d{4,}\)`      # delays largos en handler
- `(202|Accepted)[\s\S]{0,200}(taskId|jobId|task_id)` # respuesta async correcta
- `dead[_-]?letter|DLQ|retries\s*:`        # DLQ y retry config

**Señal de N/A:** servicio sin operaciones que excedan ~1s por request.

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

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/cron/**`, `**/jobs/**`, `**/scheduled/**`, `**/k8s/**/*.yaml`, `**/cronjob*.yaml`
**Patrones:**
- `(node-cron|cron|@nestjs/schedule|APScheduler|celery\.beat|pg-cron)` # libs cron
- `(setLock|acquireLock|distributed[_-]?lock|redlock|advisory_lock)` # lock distribuido
- `kind:\s*CronJob|schedule:\s*['"][\d\*\s/]+['"]` # k8s cronjob
- `INSERT[\s\S]{0,200}ON\s+CONFLICT|MERGE\s+INTO`  # upsert idempotente
- `concurrencyPolicy\s*:\s*(Forbid|Replace)` # k8s anti-overlap

**Señal de N/A:** sistema sin tareas programadas.

**Verificar:**
- [ ] Job puede correr dos veces sin efectos duplicados.
- [ ] Lock distribuido impide doble ejecución simultánea cuando importa.
- [ ] Timeouts por job; alertas cuando exceden duración esperada.

---

## E. Memoria

#### `PERF-BE-040` — Memoria monitoreada y acotada
**Severidad:** high · **Aplica a:** backend · infra

El proceso tiene límites de memoria y se monitorea crecimiento/leaks.

**Dónde buscar:** `**/k8s/**/*.yaml`, `Dockerfile`, `**/values*.yaml`, `**/*.{ts,js,py,go}`, `**/observability/**`
**Patrones:**
- `resources:[\s\S]{0,200}memory:\s*['"]?\d+(Mi|Gi)` # k8s memory limit
- `--max-old-space-size|NODE_OPTIONS=.*max-old-space` # límite Node.js
- `(prom-client|prometheus_client|datadog|newrelic).*memory` # métricas mem
- `process\.memoryUsage\(\)|psutil\.Process\(\)` # observación de uso
- `OOMKilled|OOM\s+kill`                   # eventos OOM
- `heapdump|heap-snapshot|gc-stats`        # diagnóstico

**Señal de N/A:** sin orquestador con límites configurables (script CLI corto).

**Verificar:**
- [ ] Cgroup/container con memory limit.
- [ ] Métricas de memoria por proceso en dashboards.
- [ ] Alertas ante crecimiento sostenido (memory leak).
- [ ] OOM kill reportado con contexto.

---

#### `PERF-BE-041` — Colecciones y buffers con límites
**Severidad:** medium · **Aplica a:** backend

No se acumulan listas/maps sin límite en memoria.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/cache/**`, `**/handlers/**`
**Patrones:**
- `(let|const|var)\s+\w+\s*=\s*\[\][\s\S]{0,500}\.push\(` # array que crece sin límite
- `Map\(\)|new\s+Map\(\)|dict\(\)|\{\}[\s\S]{0,500}\[\w+\]\s*=` # mapa que crece
- `lru-cache|node-cache|cachetools\.LRUCache` # estructura con límite (positivo)
- `\.readAll\(|\.read\(\)\.split` # lectura sin límite de stream
- `maxLength|maxSize|limit\s*:\s*\d+`      # límites configurados (positivo)

**Señal de N/A:** servicio sin acumulación de estado (puramente request-response sin caches).

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

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/repositories/**`, `**/controllers/**`
**Patrones:**
- `\.forEach\(\s*async[\s\S]{0,200}await[\s\S]{0,200}(find|query)` # await + find en forEach
- `for\s*\(.*of[\s\S]{0,200}await[\s\S]{0,200}(findOne|findById|find\()` # N+1 explícito
- `\.map\(\s*async[\s\S]{0,200}await[\s\S]{0,200}repository\.` # map async con query
- `(joinedload|selectinload|include\s*:|prefetch_related|JoinTable)` # eager loading (positivo)
- `(django-debug-toolbar|bullet|query-counter)` # detección N+1
- `LIMIT\s+1[\s\S]{0,200}LIMIT\s+1[\s\S]{0,200}LIMIT\s+1` # múltiples queries unitarias

**Señal de N/A:** sistema sin BD relacional ni ORM.

**Verificar:**
- [ ] Revisión de handlers que iteran y consultan en cada iteración.
- [ ] Herramientas (django-debug-toolbar, bullet, log de queries lentas) detectando N+1.
- [ ] Eager loading (selectinload, joinedload, include) donde aporta.

(Más detalle en `13-base-datos/02-queries-transacciones.md`.)

---

#### `PERF-BE-051` — Queries de listado paginadas y con índice
**Severidad:** high · **Aplica a:** backend

Los listados paginan (ver `API-PAGE-001`) y usan índices apropiados.

**Dónde buscar:** `**/*.{ts,js,py,sql}`, `**/repositories/**`, `**/services/**`, `**/migrations/**`
**Patrones:**
- `(SELECT|find|findAll|findMany)[\s\S]{0,500}(?!LIMIT|take|limit)` # consulta sin LIMIT
- `LIMIT\s+\d+|take\s*:\s*\d+|limit\s*:\s*\d+|page_size`  # paginación (positivo)
- `OFFSET\s+\d{4,}`                        # offsets grandes (revisar cursor)
- `ORDER\s+BY[\s\S]{0,100}LIMIT`           # listado ordenado (verificar índice)
- `EXPLAIN\s+(ANALYZE\s+)?SELECT`          # uso de EXPLAIN
- `@Index|CREATE\s+INDEX`                  # índices explícitos

**Señal de N/A:** sistema sin endpoints de listado o con datasets pequeños fijos.

**Verificar:**
- [ ] Listados con LIMIT/OFFSET razonables o cursor.
- [ ] Índices sobre columnas de filtrado y orden.
- [ ] EXPLAIN en queries críticas.

---

## G. Medición

#### `PERF-BE-060` — Latencias p50/p95/p99 medidas
**Severidad:** high · **Aplica a:** backend · observability

Métricas RED (Rate, Errors, Duration) por endpoint.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/middleware/**`, `**/observability/**`, `**/metrics/**`, `**/k8s/**`
**Patrones:**
- `(prom-client|prometheus_client|micrometer|@opentelemetry/api-metrics)` # libs métricas
- `(Histogram|histogram|Summary|summary)\(` # histograma de latencia
- `(p50|p95|p99|quantile|percentile)`      # percentiles
- `(slo|sli|error.budget)`                 # SLOs definidos
- `request_duration|http_request_duration|response_time` # métrica común

**Señal de N/A:** servicio interno sin SLOs ni observabilidad establecida.

**Verificar:**
- [ ] Histogramas de latencia por endpoint.
- [ ] Alertas ante regresión de p95/p99.
- [ ] SLOs documentados.

(Ver `10-observabilidad/`.)

---

#### `PERF-BE-061` — Tracing distribuido para cuellos de botella
**Severidad:** medium · **Aplica a:** backend · observability

Hay tracing que permite identificar spans lentos entre servicios.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/middleware/**`, `**/observability/**`, `**/tracing.*`
**Patrones:**
- `(@opentelemetry/api|@opentelemetry/sdk|opentracing|jaeger|zipkin|datadog-trace|elastic-apm)` # libs tracing
- `(startSpan|tracer\.start|with\s+tracer\.start_as_current_span|trace\.SpanFromContext)` # spans
- `(traceparent|x-b3-traceid|datadog-trace-id)` # propagación de contexto
- `instrument(express|fastify|koa|nestjs|fastapi|django|flask)` # auto-instrumentación

**Señal de N/A:** monolito de un solo servicio sin necesidad de tracing distribuido.

(Ver `10-observabilidad/03-trazas-alertas.md`.)

---

## H. Complejidad algorítmica

#### `PERF-BE-070` — Hot paths sin complejidad supralineal
**Severidad:** high · **Tags:** `big-o`, `algorithmic-complexity` · **Aplica a:** backend

Las funciones ejecutadas en el camino crítico (por request, por evento, dentro
de loops sobre colecciones) tienen complejidad identificada. Una rutina O(n²)
con n = 1.000 ejecutada 100 veces/segundo puede colapsar el servidor aunque
en desarrollo con n = 10 parezca instantánea.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/handlers/**`, `**/utils/**`
**Patrones:**
- `for[\s\S]{0,200}for\s*\([^)]*[\s\S]{0,500}\.(includes|indexOf|find)\(` # bucle anidado con búsqueda lineal
- `\.includes\([\s\S]{0,200}\.includes\(`  # múltiples includes en cadena
- `\.sort\(\s*\([^)]+\)\s*=>[\s\S]{0,200}(parseInt|parse|toLowerCase|split)` # comparador con parsing
- `\.find\([^)]+\)[\s\S]{0,500}\.find\(`   # múltiples finds (probable n*m)
- `\.filter\([\s\S]{0,200}\.includes\(`    # intersección O(n*m)

**Señal de N/A:** funciones con datasets fijos pequeños (< 50 elementos) no expuestas a usuario.

**Verificar:**
- [ ] Las funciones de transformación/filtrado sobre colecciones en hot paths tienen complejidad ≤ O(n log n).
- [ ] Los bucles anidados sobre la misma colección se revisan: ¿puede reemplazarse con una sola pasada usando Map/Set auxiliar?
- [ ] Las operaciones costosas que se repiten por cada elemento (búsqueda lineal, sort, serialización pesada) se precalculan fuera del loop.
- [ ] Los cambios en el tamaño de entrada están documentados: si n puede crecer con el uso (registros por cliente, items en carrito), la complejidad se escala mentalmente al revisar.
- [ ] Los sorts en hot paths usan comparadores simples sin I/O ni parsing dentro del comparador.

**Banderas rojas:**
- `for (const item of list) { if (otherList.includes(item)) ... }` — O(n·m), reemplazable con Set en O(n+m).
- Sort con comparador que llama a `Date.parse()`, `split()` o `toLowerCase()` en cada comparación, en lugar de normalizar el array una sola vez antes.
- Endpoint que tarda 10 ms con 100 registros, 400 ms con 1.000 y 40 s con 10.000 — comportamiento cuadrático en producción.
- "Solo es lento cuando hay muchos datos" en una issue — indicador claro de complejidad supralineal sin detectar.

---

#### `PERF-BE-071` — Estructuras de datos adecuadas al patrón de acceso
**Severidad:** high · **Tags:** `data-structures`, `big-o` · **Aplica a:** backend

La elección de estructura de datos determina la complejidad de cada operación.
Usar un array para búsquedas repetidas transforma O(1) en O(n); dentro de un
loop, el resultado acumulado es O(n²).

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/handlers/**`, `**/utils/**`
**Patrones:**
- `for[\s\S]{0,200}\.find\(\s*\w+\s*=>\s*\w+\.id\s*===` # find por id en loop (usar Map)
- `for[\s\S]{0,200}\.includes\(`           # includes en loop (usar Set)
- `\.filter\([^)]+\)\.length\s*[><]\s*0`   # filter().length en lugar de some()
- `\.shift\(\)`                            # O(n) en arrays largos
- `\.unshift\(`                            # O(n) por inserción
- `new\s+(Set|Map)\(`                      # uso correcto (positivo)

**Señal de N/A:** código sin loops sobre colecciones con búsquedas internas.

**Verificar:**
- [ ] Membership checks frecuentes usan `Set` (`set.has(id)`) en lugar de `Array.includes()` / `array.find()`.
- [ ] Lookups por clave usan `Map` u objeto indexado en lugar de `array.find(x => x.id === key)`.
- [ ] Agrupaciones repetidas precalculan un `Map<key, items[]>` en una pasada, no `filter()` por cada grupo.
- [ ] Colas FIFO de alta frecuencia usan estructuras con O(1) en ambos extremos — `array.shift()` en arrays largos es O(n).
- [ ] Operaciones de conjunto (intersección, diferencia) usan Set para O(n+m), no `.filter(x => arr2.includes(x))` O(n·m).

**Banderas rojas:**
- `users.find(u => u.id === id)` dentro de un loop sobre recursos — O(n·users) por request.
- `array.filter(x => x.status === 'active').length > 0` cuando `array.some(...)` termina en el primer match.
- `array.unshift(item)` dentro de un loop — insertar al inicio de un array es O(n) por llamada.

**Ejemplo de hallazgo:**
```yaml
control_id: PERF-BE-071
severity: high
file: src/services/authorization.service.ts
line: 28
evidence: |
  for (const resource of resources) {
    const allowed = user.permissions.find(p => p.resourceId === resource.id);
    if (!allowed) continue;
  }
explanation: |
  Array.find() es O(n_permisos). Con 500 recursos y 50 permisos = 25.000
  comparaciones por request. A 100 req/s = 2.5M comparaciones/s innecesarias.
suggestion: |
  const permSet = new Set(user.permissions.map(p => p.resourceId));
  for (const resource of resources) {
    if (!permSet.has(resource.id)) continue;
  }
  // O(n_permisos + n_recursos) total vs O(n_permisos × n_recursos)
```

---

#### `PERF-BE-072` — Construcción de strings en loops
**Severidad:** medium · **Tags:** `string-building`, `memory` · **Aplica a:** backend

La concatenación `str += item` en un loop crea una nueva cadena inmutable en
cada iteración: O(n²) de tiempo y memoria. Para n = 10.000 ítems genera ~50 MB
de strings intermedias que el GC debe colectar.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/exports/**`, `**/templates/**`, `**/services/**`, `**/utils/**`
**Patrones:**
- `for[\s\S]{0,200}\w+\s*\+=\s*['"\`]`     # str += en loop
- `forEach\([\s\S]{0,500}\w+\s*\+=`        # forEach con concatenación
- `query\s*\+=\s*['"]`                     # SQL construido con +=
- `\.push\([\s\S]{0,200}\.join\(`          # patrón correcto (positivo)
- `Buffer\.concat\(|stream\.write`         # buffers/streams (positivo)
- `(handlebars|ejs|pug|nunjucks|jinja2|mustache)` # template engines

**Señal de N/A:** sin generación de strings grandes en loops.

**Verificar:**
- [ ] La construcción de strings grandes usa `Array.push()` + `.join()`, `Buffer`, streams o `StringBuilder` equivalente.
- [ ] Generación de CSV, SQL multi-row o HTML usa buffer de partes, no concatenación directa.
- [ ] Los templates que producen centenares de líneas (reports, emails complejos) usan motor de plantillas.
- [ ] SQL con cláusulas `IN (...)` construidas dinámicamente agrupan los parámetros desde el inicio, no acumulan con `+=`.

**Banderas rojas:**
- `let csv = ''; for (const row of rows) csv += formatRow(row);` sobre miles de filas.
- `` let html = ''; items.forEach(i => { html += `<tr>...</tr>`; }); `` en endpoints de listado.
- SQL construido como `query += ' AND x IN (' + ids.join(',') + ')'` sin usar query builder.

---

#### `PERF-BE-073` — Recursión acotada y sin bloqueo del event loop
**Severidad:** high · **Tags:** `recursion`, `stack-overflow`, `event-loop` · **Aplica a:** backend

Los algoritmos recursivos sobre datos de entrada del usuario (árboles, grafos,
JSON anidado) deben tener profundidad máxima explícita. En Node.js, la recursión
síncrona profunda bloquea el event loop para todos los requests simultáneos.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/parsers/**`, `**/utils/**`, `**/handlers/**`
**Patrones:**
- `function\s+(\w+)[\s\S]{0,500}\1\(`      # función llamándose a sí misma
- `def\s+(\w+)[\s\S]{0,500}\1\(`           # idem python
- `(?<!max)Depth|maxDepth\s*[:=]\s*\d+`    # parámetro maxDepth (positivo)
- `setImmediate\(|process\.nextTick\(`     # yields al event loop (positivo)
- `(traverse|walk|flatten|deepClone|deepMerge)` # operaciones recursivas típicas
- `JSON\.parse\([^)]+\)(?![\s\S]{0,100}depth)` # parse sin protección de profundidad

**Señal de N/A:** sistema sin entrada del usuario que sea estructura recursiva.

**Verificar:**
- [ ] Toda recursión sobre input del usuario tiene un parámetro `maxDepth` con valor razonable (≤ 50–100 en la mayoría de casos).
- [ ] Superar la profundidad máxima retorna un error controlado (400/422), nunca un stack overflow.
- [ ] En Node.js, recursión con > ~5.000 niveles posibles se implementa con iteración explícita (stack manual, trampolining).
- [ ] La traversal de grafos/árboles grandes sobre datos de usuario usa `setImmediate` entre batches o se delega a un worker thread.
- [ ] La deserialización de JSON profundo tiene protección (ver `SEC-HEADERS-040` para limitar profundidad de parsing).

**Banderas rojas:**
- `function flatten(obj) { for (const k in obj) if (typeof obj[k] === 'object') flatten(obj[k]); }` sin `maxDepth` sobre JSON del usuario.
- Traversal síncrona de árbol en un handler HTTP sin yield al event loop.
- Recursión mutua (A llama B, B llama A) sobre datos de tamaño variable sin límite.

---

#### `PERF-BE-074` — Minimizar pasadas e iteraciones sobre colecciones grandes
**Severidad:** medium · **Tags:** `iteration`, `lazy-evaluation` · **Aplica a:** backend

Una cadena `.filter().map().reduce()` sobre un array realiza múltiples pasadas
completas y crea arrays intermedios. Con colecciones grandes puede unificarse en
una sola pasada. Para datasets que superan la RAM disponible, la respuesta es el
procesamiento en streaming.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/repositories/**`, `**/handlers/**`
**Patrones:**
- `\.filter\([^)]+\)\.filter\(`            # múltiples filter encadenados
- `\.map\([^)]+\)\.filter\([^)]+\)\.map\(` # cadena larga
- `\.find\(\{\}\)|findAll\(\)|repository\.find\(\{\}\)` # find sin where
- `\.slice\(\s*\d+\s*,\s*\w+\.length\)`    # paginación en memoria
- `(generators?|yield|iter\(|itertools)`   # lazy iteration (positivo)
- `cursor\(|stream\(|pipeline\(`           # streaming de BD

**Señal de N/A:** sistema con colecciones siempre pequeñas (< 100 elementos).

**Verificar:**
- [ ] Cadenas de métodos sobre colecciones de miles de elementos se revisan para unificar cuando el impacto es medible.
- [ ] Resultados grandes de BD se procesan como cursor/stream en lugar de cargar todo con `findAll()` / `find({})` sin `LIMIT`.
- [ ] Arrays intermedios innecesarios se evitan: no materializar un `filter` solo para iterar inmediatamente.
- [ ] Generators / iterables lazy se consideran para pipelines de datos que no caben en memoria.
- [ ] Intersección de arrays grandes usa Set (O(n+m)) no `.filter(x => arr2.includes(x))` (O(n·m)).

**Banderas rojas:**
- `await repository.find({})` sin `WHERE`, `LIMIT` ni cursor sobre tabla con crecimiento ilimitado.
- `.filter(a).filter(b).filter(c)` con tres pasadas cuando `.filter(x => a(x) && b(x) && c(x))` haría una.
- Carga de todo el resultado en memoria para luego procesar con `.slice(offset, offset+limit)` en la app en lugar de paginar en la query.

---

## I. Serialización y profiling

#### `PERF-BE-080` — Serialización eficiente en hot paths
**Severidad:** medium · **Tags:** `serialization`, `json` · **Aplica a:** backend

`JSON.stringify` y validación de schema son operaciones costosas en hot paths
de alto throughput. Para respuestas estructuradas y repetitivas se puede reducir
el costo con schemas pre-compilados o formatos más eficientes.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/handlers/**`, `**/middleware/**`, `**/serializers/**`
**Patrones:**
- `JSON\.parse\(\s*JSON\.stringify\(`      # deep clone con JSON
- `new\s+Ajv\(\)[\s\S]{0,200}\.compile\(`  # compile en handler (revisar scope)
- `z\.object\([^)]+\)\.parse\(`            # zod parse en hot path
- `(fast-json-stringify|protobufjs|@msgpack/msgpack|msgpack-lite|avsc)` # alternativas eficientes
- `structuredClone\(`                      # deep clone correcto (positivo)
- `serializer\(|toJSON\(\)|serialize\(`    # serialización custom

**Señal de N/A:** API con throughput bajo donde JSON.stringify no es bottleneck.

**Verificar:**
- [ ] `JSON.stringify` en hot paths revisado: ¿el resultado puede cachearse si el input no cambia entre requests?
- [ ] Para respuestas de alto volumen con schema estable: `fast-json-stringify` con schema pre-compilado (2–5× más rápido que `JSON.stringify` genérico).
- [ ] Los schemas de validación (Ajv, Zod, Joi) se compilan/instancian **una vez al arrancar**, no dentro del handler.
- [ ] `JSON.parse(JSON.stringify(obj))` como técnica de deep clone se reemplaza por `structuredClone()` o librería dedicada.
- [ ] Para comunicación interna entre servicios de alto throughput: se evalúa MessagePack o Protocol Buffers si el overhead de JSON es medible con profiling.

**Banderas rojas:**
- `const validate = new Ajv().compile(schema)` dentro del handler HTTP — recompila en cada request.
- `JSON.stringify(fullOrmEntity)` donde la entidad incluye relaciones cargadas innecesariamente.
- Schema Zod con `.parse()` aplicado a decenas de campos en cada request sin caching del resultado.

---

#### `PERF-BE-081` — Profiling antes de optimizar (measurement-first)
**Severidad:** medium · **Tags:** `profiling`, `flamegraph`, `measurement` · **Aplica a:** backend

Las optimizaciones de rendimiento deben basarse en datos de profiling reales,
no en intuición. El código complejo "por rendimiento" sin evidencia de bottleneck
es deuda técnica sin beneficio medible.

**Dónde buscar:** `**/benchmarks/**`, `**/perf/**`, `package.json`, `Makefile`, `**/*.{ts,js,py,go}`, `**/docs/**`
**Patrones:**
- `(clinic|0x|py-spy|pprof|async-profiler|autocannon|k6|wrk|hyperfine)` # tools profiling
- `//\s*optimi[sz]ed?[\s\S]{0,200}(?!benchmark|measure)` # comentario de "optimizado" sin medición
- `//\s*HACK|//\s*PERF|//\s*OPTIMIZE`      # comentarios de optimización
- `console\.time\(|performance\.now\(\)`   # benchmarks ad hoc
- `before\s*:|after\s*:|baseline`          # comparativas de medición

**Señal de N/A:** sistema sin requisitos de performance medidos ni bottlenecks reportados.

**Verificar:**
- [ ] Antes de optimizar un componente se mide su impacto real: profiling en producción o con load test representativo.
- [ ] Las herramientas de profiling están documentadas y disponibles para el equipo.
- [ ] Los benchmarks de micro-optimizaciones críticas viven en el repo (`/benchmarks`) para detectar regresiones futuras.
- [ ] El flamegraph de CPU identifica los top-3 hotspots antes de invertir tiempo en optimización.
- [ ] El PR que optimiza por rendimiento incluye el before/after de la métrica relevante (latencia p95, throughput, memoria).

**Banderas rojas:**
- Comentario `// optimizado para rendimiento` en código complejo sin benchmark adjunto.
- Micro-optimizaciones (evitar una copia de array) en código que se ejecuta una vez por hora.
- Reescritura de una función "lenta" sin medir que era el bottleneck real.

**Herramientas:** `clinic.js` · `0x` (flamegraph Node.js) · `py-spy` (Python sin instrumentación) · `go tool pprof` · `async-profiler` (JVM) · `autocannon` / `k6` / `wrk` (load testing).

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
| PERF-BE-070    | Hot paths sin complejidad supralineal              | high      |
| PERF-BE-071    | Estructuras de datos adecuadas al acceso           | high      |
| PERF-BE-072    | Construcción de strings en loops                   | medium    |
| PERF-BE-073    | Recursión acotada y sin bloqueo                    | high      |
| PERF-BE-074    | Minimizar pasadas sobre colecciones grandes        | medium    |
| PERF-BE-080    | Serialización eficiente en hot paths               | medium    |
| PERF-BE-081    | Profiling antes de optimizar                       | medium    |
