# 03 · Calidad de código · Concurrencia, estado y efectos

> Manejo de async, concurrencia, estado compartido, inmutabilidad y efectos
> externos de forma segura y predecible.
>
> **Marcos de referencia:** Structured Concurrency · Reactive Manifesto · The Twelve-Factor App.

---

## A. Async y concurrencia

#### `CODE-ASYNC-001` — I/O siempre async en runtimes async
**Severidad:** high · **Tags:** `performance` · **Aplica a:** backend · frontend

En código que corre sobre un runtime async (event loop), el I/O se hace con
APIs async. Las funciones síncronas bloqueantes se ejecutan en thread pool.

**Verificar:**
- [ ] No se mezclan clientes síncronos con runtime async (ej: `requests` en Python/asyncio).
- [ ] Funciones costosas CPU-bound se mueven a thread/process pool.
- [ ] `asyncio.to_thread` / equivalente se usa para delegar bloqueantes.
- [ ] `await` nunca se omite en llamadas async (linter lo detecta).

**Banderas rojas:**
- `time.sleep` en función `async`.
- `requests.get` dentro de handler async.
- Olvidar `await` — la coroutine se descarta silenciosamente.

---

#### `CODE-ASYNC-002` — Paralelismo controlado con límite
**Severidad:** medium · **Tags:** `backpressure` · **Aplica a:** backend

Cuando se lanza muchas operaciones concurrentes, se limita la concurrencia con
semáforo, pool, o rate limiter para no sobrecargar recursos externos.

**Verificar:**
- [ ] `asyncio.gather` / `Promise.all` sobre N input tiene un límite.
- [ ] Hay `asyncio.Semaphore`, p-limit, p-queue, o equivalente para APIs externas.
- [ ] Las colas y pools tienen tamaño máximo.

**Banderas rojas:**
- `await asyncio.gather(*[call_api(x) for x in thousands_of_items])` sin límite.
- Abrir una conexión a BD nueva por cada tarea concurrente.

---

#### `CODE-ASYNC-003` — Structured concurrency: tareas cancelables y recolectadas
**Severidad:** medium · **Tags:** `reliability` · **Aplica a:** backend

Las tareas concurrentes se crean bajo un scope que las cancela si el padre falla,
y se esperan antes de retornar.

**Verificar:**
- [ ] Uso de `TaskGroup` (Python 3.11+), `AbortController` (JS), `errgroup` (Go), etc.
- [ ] Ninguna tarea queda "huérfana" tras retornar del handler.
- [ ] Timeouts aplicados al scope completo.

**Banderas rojas:**
- `asyncio.create_task` sin guardar referencia ni await.
- Fire-and-forget sin manejo de errores (excepciones desaparecen).

---

#### `CODE-ASYNC-004` — Timeouts en todo I/O
**Severidad:** critical · **Aplica a:** backend

Toda llamada a sistemas externos (BD, HTTP, cache, cola) tiene timeout explícito.
Sin timeout, un proveedor lento bloquea la aplicación.

**Verificar:**
- [ ] Clientes HTTP inicializados con `timeout` (connect, read, total).
- [ ] Pool de conexiones BD tiene `pool_timeout`.
- [ ] Se usa `asyncio.wait_for` o equivalente en operaciones sin timeout nativo.
- [ ] Jobs de background tienen timeout global.

(Duplica `SEC-HEADERS-041` intencionalmente — aquí enfocado a calidad, allí a DoS.)

**Banderas rojas:**
- `httpx.get(url)` sin `timeout` y sin `Client(timeout=...)`.
- Queries SQL sin statement_timeout.

---

#### `CODE-ASYNC-005` — Cancelación manejada correctamente
**Severidad:** medium · **Aplica a:** backend

Cuando un request HTTP es cancelado por el cliente o un worker recibe shutdown,
las tareas se cancelan limpiamente.

**Verificar:**
- [ ] Las funciones async manejan `CancelledError` / `AbortError` limpiamente (re-raise tras cleanup).
- [ ] Los handlers respetan `request.is_disconnected()` en streams largos.
- [ ] Graceful shutdown termina conexiones activas.

**Banderas rojas:**
- `except Exception` que traga `CancelledError`.
- Workers sin handler de shutdown.

---

## B. Estado compartido e inmutabilidad

#### `CODE-STATE-001` — Estado global minimizado
**Severidad:** high · **Tags:** `bug-risk`, `testing` · **Aplica a:** all

Se evitan variables globales mutables. Cuando son inevitables, están documentadas
y protegidas.

**Verificar:**
- [ ] La configuración se pasa como parámetro/inyección, no se lee por variable global en medio del código.
- [ ] Los singletons son explícitos (lazy init documentado) y thread-safe.
- [ ] Cachés compartidas usan estructuras concurrentes.

**Banderas rojas:**
- Módulos que mutan variables globales en tiempo de ejecución.
- Estado compartido entre requests sin sync (carry-over entre peticiones).

---

#### `CODE-STATE-002` — Datos inmutables preferidos
**Severidad:** low · **Aplica a:** all

Se prefieren estructuras inmutables o copias sobre mutación in-place.

**Verificar:**
- [ ] Se usan dataclasses congeladas / records / structs cuando no se necesita mutación.
- [ ] En JS/TS, `const` por defecto, `readonly` en interfaces.
- [ ] Collections framework: se prefieren versiones inmutables donde existan.

---

#### `CODE-STATE-003` — Thread-safety documentada
**Severidad:** medium · **Aplica a:** backend

Las clases y estructuras se etiquetan como thread-safe o no. Las compartidas
tienen locking o usan primitives concurrentes.

**Verificar:**
- [ ] Docs aclaran si una clase es safe para uso concurrente.
- [ ] Contadores, caches, mapas compartidos usan sync apropiada o estructuras lock-free.
- [ ] No hay race conditions obvias en inicialización lazy.

---

## C. Efectos laterales y pureza

#### `CODE-EFFECT-001` — Separación entre cálculo y efecto
**Severidad:** medium · **Aplica a:** all

La lógica que calcula se separa de la que produce efectos externos.

**Verificar:**
- [ ] Validación, transformación y reglas de negocio: funciones puras.
- [ ] Persistencia, emails, HTTP, notificaciones: en la capa frontera.
- [ ] Tests de lógica de negocio no requieren mocks de I/O.

---

#### `CODE-EFFECT-002` — Idempotencia en operaciones re-ejecutables
**Severidad:** high · **Tags:** `reliability` · **Aplica a:** backend

Workers, jobs, consumers de cola pueden recibir el mismo mensaje dos veces.
Los handlers son idempotentes o hay deduplicación.

**Verificar:**
- [ ] El consumer aplica dedup por `message_id` / `event_id`.
- [ ] Las mutaciones son idempotentes (upsert, set, compare-and-swap).
- [ ] La re-ejecución no causa efectos duplicados (doble charge, doble email).

**Banderas rojas:**
- Consumer que hace `INSERT` sin llaves únicas ni dedup.
- "Send email" sin tracking de eventos ya procesados.

---

#### `CODE-EFFECT-003` — Tiempo y aleatoriedad inyectados
**Severidad:** low · **Aplica a:** all

`now()`, `uuid()`, `random()` se envuelven en funciones/interfaces que se pueden
sustituir en tests.

**Verificar:**
- [ ] Existe un clock / time provider testeable.
- [ ] Los IDs y aleatorios tienen generador inyectable.
- [ ] Los tests que dependen del tiempo no usan `sleep`.

---

## D. Logging y observabilidad (contracto con la app)

#### `CODE-OBS-001` — No usar `print` / `console.log` en código productivo
**Severidad:** high · **Aplica a:** all

Los mensajes operacionales pasan por el logger configurado.

**Verificar:**
- [ ] Producción no tiene `print`, `System.out`, `console.log`.
- [ ] Linter/pre-commit lo bloquea.
- [ ] Los logs del framework se canalizan al mismo logger.

**Banderas rojas:**
- `print(user)` en medio del servicio.
- `console.log` en componentes UI productivos.

---

#### `CODE-OBS-002` — Niveles de log apropiados
**Severidad:** medium · **Aplica a:** all

Cada mensaje está en el nivel que corresponde: DEBUG para desarrollo, INFO para
operaciones normales, WARNING para anomalías recuperables, ERROR para fallos.

**Verificar:**
- [ ] Nivel por defecto en producción es INFO o superior.
- [ ] Los logs en hot paths no son DEBUG con formato costoso.
- [ ] No hay "log storms" (mensajes idénticos repetidos miles de veces).

---

#### `CODE-OBS-003` — Contexto estructurado en logs
**Severidad:** medium · **Aplica a:** backend

Los logs usan formato estructurado (JSON) con campos consistentes (request_id,
user_id, duration_ms, etc.).

(Detalle completo en `10-observabilidad/01-logs-metricas.md`.)

---

## Checklist resumen

| ID                | Control                                            | Severidad |
| ----------------- | -------------------------------------------------- | --------- |
| CODE-ASYNC-001    | I/O async en runtimes async                        | high      |
| CODE-ASYNC-002    | Paralelismo con límite                             | medium    |
| CODE-ASYNC-003    | Structured concurrency                             | medium    |
| CODE-ASYNC-004    | Timeouts en todo I/O                               | critical  |
| CODE-ASYNC-005    | Cancelación manejada                               | medium    |
| CODE-STATE-001    | Estado global minimizado                           | high      |
| CODE-STATE-002    | Datos inmutables preferidos                        | low       |
| CODE-STATE-003    | Thread-safety documentada                          | medium    |
| CODE-EFFECT-001   | Cálculo separado del efecto                        | medium    |
| CODE-EFFECT-002   | Idempotencia en re-ejecutables                     | high      |
| CODE-EFFECT-003   | Tiempo/aleatoriedad inyectados                     | low       |
| CODE-OBS-001      | Sin print/console.log en prod                      | high      |
| CODE-OBS-002      | Niveles de log correctos                           | medium    |
| CODE-OBS-003      | Logs con contexto estructurado (→ obs)             | medium    |
