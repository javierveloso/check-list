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
- `TypeORM DataSource` sin bloque `extra: { max: N, idleTimeoutMillis: N }` — el pool puede crecer sin límite y agotar las conexiones disponibles en PostgreSQL.

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

## H. Complejidad algorítmica

#### `PERF-BE-070` — Hot paths sin complejidad supralineal
**Severidad:** high · **Tags:** `big-o`, `algorithmic-complexity` · **Aplica a:** backend

Las funciones ejecutadas en el camino crítico (por request, por evento, dentro
de loops sobre colecciones) tienen complejidad identificada. Una rutina O(n²)
con n = 1.000 ejecutada 100 veces/segundo puede colapsar el servidor aunque
en desarrollo con n = 10 parezca instantánea.

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
