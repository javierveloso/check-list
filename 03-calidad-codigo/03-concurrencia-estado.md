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

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `async\s+def[\s\S]{0,500}\btime\.sleep\(`     # time.sleep en función async
- `async\s+def[\s\S]{0,500}\brequests\.(get|post|put|delete)\(` # `requests` en async
- `async\s+def[\s\S]{0,500}\bopen\([^)]+\)`     # open() bloqueante en async
- `async\s+function[\s\S]{0,500}\bfs\.readFileSync` # sync FS en async JS
- `^\s*\w+\s*\(\s*\)\s*\n` (línea con llamada plain a async sin `await`) # await olvidado (heurístico)
**Señal de N/A:** stack 100% síncrono (CLI Python sync, Java sync, scripts batch).

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

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `asyncio\.gather\(\*\[`            # gather sobre comprensión sin límite
- `Promise\.all\(\s*\w+\.map\(`      # Promise.all sobre map ilimitado
- `asyncio\.gather\((?![\s\S]{0,200}Semaphore)` # gather sin semáforo cercano
- `for\s+\w+\s+in\s+\w+\s*\{[\s\S]{0,200}go\s+\w+\(` # goroutine por iteración sin pool
- `p-limit|p-queue|asyncio\.Semaphore` # señales positivas (presencia esperada)
**Señal de N/A:** sin operaciones concurrentes (procesamiento serial por diseño).

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

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `asyncio\.create_task\([^)]+\)(?!\s*[)\],])` # create_task sin guardar referencia
- `\.then\([^)]+\)(?!\s*\.(catch|finally))`    # promise sin catch/finally
- `go\s+func\s*\([^)]*\)\s*\{`       # goroutine fire-and-forget Go (revisar wg/errgroup)
- `setTimeout\(\s*async\s*\(`        # setTimeout con async crea fire-and-forget
- `TaskGroup|errgroup\.|AbortController` # señales positivas
**Señal de N/A:** sin programación concurrente (todo serial).

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

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go,java,cs}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `httpx\.(get|post|put|delete)\([^)]+\)(?![^)]*timeout)` # httpx sin timeout
- `requests\.(get|post|put|delete)\([^)]+\)(?![^)]*timeout)` # requests sin timeout
- `axios\.(get|post|put|delete)\([^)]+\)(?![^)]*timeout)` # axios sin timeout
- `fetch\([^)]+\)(?![\s\S]{0,200}AbortController|signal)` # fetch sin AbortController
- `http\.Client\{\s*\}`              # Go http.Client default sin Timeout
- `new\s+OkHttpClient\(\)\s*[;.]`    # Java OkHttp sin .timeout
**Señal de N/A:** código sin I/O externo (cómputo puro / batch local sin red).

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

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `except\s+Exception(?![\s\S]{0,200}CancelledError)` # captura genérica que puede tragar CancelledError
- `try\s*:\s*\n[\s\S]{0,300}except\s*:\s*\n` # except desnudo que traga cancelación
- `is_disconnected|abortController|context\.Done\(\)` # señales positivas
- `SIGTERM|SIGINT|graceful` # señales de manejo de shutdown
**Señal de N/A:** scripts batch o CLI sin servidor / worker de larga duración.

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

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go,java,cs}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `^let\s+\w+\s*=\s*[^;]+;?$`        # `let` a nivel módulo TS/JS (mutable global)
- `^var\s+\w+\s*=`                   # `var` a nivel módulo
- `^global\s+\w+`                    # `global` keyword Python
- `^\s*[A-Z_][A-Z_0-9]*\s*=\s*\[\s*\]` # const "global" mutable Python (lista vacía a nivel módulo)
- `singleton|getInstance\(\)`        # patrones singleton (revisar thread-safety)
**Señal de N/A:** módulo puramente declarativo (constantes inmutables) o función pura aislada.

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

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,java,cs,kt,rs}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `\blet\s+\w+\s*[:=]`               # `let` donde podría ser `const` JS/TS
- `@dataclass\b(?!\([^)]*frozen)`    # dataclass Python sin `frozen=True`
- `interface\s+\w+\s*\{[^}]*[^?]\s*:\s*[^?\n]+\n[^}]*\}` # interface sin `readonly` (heurístico)
- `\.push\(|\.pop\(|\.splice\(`      # mutación de arrays JS
- `frozen=True|@immutable|Object\.freeze|readonly` # señales positivas
**Señal de N/A:** lenguaje con inmutabilidad por defecto (Haskell, Elm, Clojure).

**Verificar:**
- [ ] Se usan dataclasses congeladas / records / structs cuando no se necesita mutación.
- [ ] En JS/TS, `const` por defecto, `readonly` en interfaces.
- [ ] Collections framework: se prefieren versiones inmutables donde existan.

---

#### `CODE-STATE-003` — Thread-safety documentada
**Severidad:** medium · **Aplica a:** backend

Las clases y estructuras se etiquetan como thread-safe o no. Las compartidas
tienen locking o usan primitives concurrentes.

**Dónde buscar:** `**/*.{py,java,cs,kt,go,rs}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `threading\.Thread|ThreadPoolExecutor` # uso de threads (Python)
- `synchronized\s+(public|private|protected)?\s*\w+\s+\w+\(` # método synchronized Java
- `sync\.(Mutex|RWMutex|Map|Once)`   # primitives concurrentes Go
- `if\s+\w+\s+is\s+None\s*:[\s\S]{0,150}\w+\s*=\s*\w+\(\)` # lazy init sin lock (race)
- `volatile|AtomicInteger|AtomicReference` # señales positivas Java
**Señal de N/A:** runtime single-threaded por contrato (Node.js sin worker_threads, JS browser sin SharedWorker).

**Verificar:**
- [ ] Docs aclaran si una clase es safe para uso concurrente.
- [ ] Contadores, caches, mapas compartidos usan sync apropiada o estructuras lock-free.
- [ ] No hay race conditions obvias en inicialización lazy.

---

## C. Efectos laterales y pureza

#### `CODE-EFFECT-001` — Separación entre cálculo y efecto
**Severidad:** medium · **Aplica a:** all

La lógica que calcula se separa de la que produce efectos externos.

**Dónde buscar:** `**/domain/**`, `**/services/**`, `**/usecases/**`, `**/*.{py,ts,tsx,js,jsx,go,java,cs}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `(domain|entities|models)/[^.]+\.(py|ts|js).*(open\(|requests\.|httpx\.|axios\.|fetch\()` # I/O en dominio
- `def\s+(validate|calculate|compute|transform)\w*[\s\S]{0,400}\bopen\(` # función "pura" con I/O
- `def\s+(validate|calculate|format)\w*[\s\S]{0,400}(requests|httpx|axios)` # idem con HTTP
**Señal de N/A:** todo el módulo es adapter/IO por diseño (no hay lógica que separar).

**Verificar:**
- [ ] Validación, transformación y reglas de negocio: funciones puras.
- [ ] Persistencia, emails, HTTP, notificaciones: en la capa frontera.
- [ ] Tests de lógica de negocio no requieren mocks de I/O.

---

#### `CODE-EFFECT-002` — Idempotencia en operaciones re-ejecutables
**Severidad:** high · **Tags:** `reliability` · **Aplica a:** backend

Workers, jobs, consumers de cola pueden recibir el mismo mensaje dos veces.
Los handlers son idempotentes o hay deduplicación.

**Dónde buscar:** `**/workers/**`, `**/consumers/**`, `**/handlers/**`, `**/*.{py,ts,tsx,js,jsx,go,java,cs}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `consumer|worker|handler|subscribe.*\bINSERT\s+INTO`           # INSERT sin dedup
- `(stripe|paypal|charge|payment).*\.create\(`                    # cobros sin idempotency-key
- `(send|deliver)_(email|notification)\((?![^)]*idempotency|message_id|event_id)` # envío sin dedup
- `Idempotency-Key|idempotency_key|message_id|event_id` # señales positivas
**Señal de N/A:** sin workers / consumers de cola / jobs reintentables (app puramente request-response).

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

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go,java,cs}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`, `**/test_*`)
**Patrones:**
- `\bdatetime\.now\(\)|datetime\.utcnow\(\)`     # tiempo directo Python
- `\bDate\.now\(\)|new\s+Date\(\)`               # tiempo directo JS/TS
- `\btime\.Now\(\)`                  # tiempo directo Go
- `\buuid\.uuid[14]\(\)|crypto\.randomUUID\(\)`  # uuid directo
- `Math\.random\(\)|random\.(random|randint)\(`  # random directo
- `Clock|TimeProvider|FakeClock|sinon\.useFakeTimers` # señales positivas
**Señal de N/A:** código sin lógica dependiente de tiempo o aleatoriedad.

**Verificar:**
- [ ] Existe un clock / time provider testeable.
- [ ] Los IDs y aleatorios tienen generador inyectable.
- [ ] Los tests que dependen del tiempo no usan `sleep`.

---

## D. Logging y observabilidad (contracto con la app)

#### `CODE-OBS-001` — No usar `print` / `console.log` en código productivo
**Severidad:** high · **Aplica a:** all

Los mensajes operacionales pasan por el logger configurado.

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go,java,cs,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`, `**/test_*`, `**/scripts/**`)
**Patrones:**
- `\bconsole\.(log|debug|info|warn|error)\(` # console.* JS/TS
- `^\s*print\(`                      # print() Python en código productivo
- `System\.out\.println|System\.err\.println` # System.out Java
- `fmt\.Println|fmt\.Printf`         # fmt.Println Go (en código no main/CLI)
- `puts\s+|p\s+`                     # Ruby puts/p
**Señal de N/A:** scripts CLI/REPL donde stdout es la salida deseada.

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

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go,java,cs,kt}`, `**/logging.{conf,yaml,json}`, `**/log4j*.{xml,properties}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `logger\.(debug|info|warn|error|critical)\b` # uso de niveles (auditar uso correcto)
- `level\s*[:=]\s*["']?DEBUG["']?`   # nivel DEBUG en config (revisar entorno)
- `for\s+\w+\s+in[\s\S]{0,200}logger\.(info|debug)` # log dentro de loop (potencial storm)
- `logger\.debug\(.*format\(`        # formateo costoso en debug
**Señal de N/A:** sin sistema de logging adoptado (proyecto sin observabilidad estructurada todavía).

**Verificar:**
- [ ] Nivel por defecto en producción es INFO o superior.
- [ ] Los logs en hot paths no son DEBUG con formato costoso.
- [ ] No hay "log storms" (mensajes idénticos repetidos miles de veces).

---

#### `CODE-OBS-003` — Contexto estructurado en logs
**Severidad:** medium · **Aplica a:** backend

Los logs usan formato estructurado (JSON) con campos consistentes (request_id,
user_id, duration_ms, etc.).

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,go,java,cs,kt}`, `**/logging*.{conf,yaml,json,py,ts,js}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `logger\.(info|warn|error)\(\s*f["']`          # f-string sin extra-fields Python
- `logger\.(info|warn|error)\(\s*` + `\` + `\$\{`  # template literal sin contexto JS/TS
- `structlog|pino|winston|zerolog|zap`           # señales positivas (loggers estructurados)
- `request_id|trace_id|correlation_id|user_id`   # campos de contexto esperados
- `JSONFormatter|jsonlogger|json_log`            # formatter JSON configurado
**Señal de N/A:** app frontend pura sin logging server-side (ver `10-observabilidad/`).

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
