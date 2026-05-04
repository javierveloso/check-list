# 12 · Arquitectura · Resiliencia y patrones

> Retries, circuit breakers, timeouts, bulkheads, sagas, eventos, idempotencia
> a nivel arquitectural.
>
> **Marcos de referencia:** Release It! (Michael Nygard) · Microsoft Cloud Design Patterns · The Reactive Manifesto.

---

## A. Aislamiento de fallos

#### `ARCH-RES-001` — Timeouts en toda dependencia
**Severidad:** critical · **Aplica a:** backend

Cada llamada externa tiene timeout. (Duplicado a propósito con seguridad y
performance por su criticidad arquitectural.)

**Dónde buscar:** `**/services/**`, `**/clients/**`, `**/lib/**`, `**/utils/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `\b(fetch|axios|got|undici)\s*\([^)]*\)(?!.*timeout)`     # fetch/axios sin timeout
- `axios\.(get|post|put|delete|patch)\s*\([^)]*\)`     # axios call (validar que tenga timeout)
- `new\s+(HttpClient|RestTemplate|WebClient)\([^)]*\)`     # cliente HTTP (Java/.NET) — validar timeout
- `requests\.(get|post|put|delete)\s*\([^)]*\)`     # python requests (validar timeout=)
- `http\.Client\{[^}]*\}`     # Go http.Client (validar Timeout)
- `urllib\.request\.urlopen\s*\(`     # urlopen sin timeout
**Señal de N/A:** la app no realiza llamadas a servicios externos (sin clientes HTTP/gRPC/DB remota — script puro de cómputo local).

(Ver `SEC-HEADERS-041`, `CODE-ASYNC-004`, `PERF-BE-003`.)

---

#### `ARCH-RES-002` — Circuit breakers ante servicios inestables
**Severidad:** high · **Tags:** `resilience` · **Aplica a:** backend

Cuando una dependencia falla repetidamente, el circuit breaker "abre" y
rechaza rápido.

**Dónde buscar:** `**/services/**`, `**/clients/**`, `**/lib/**`, `**/*.{ts,js,py,go,java,cs}`, `**/package.json`, `**/pom.xml`, `**/requirements*.txt`
**Patrones:**
- `(opossum|cockatiel|circuit-breaker|hystrix|resilience4j|polly|pybreaker|gobreaker)`     # libs de circuit breaker
- `CircuitBreaker|circuit_breaker`     # uso explícito
- `\b(closed|open|half[_-]open)\b.*state`     # estados del breaker referenciados
- `fallback\s*[:=]|onFallback`     # fallback definido
**Señal de N/A:** la app no consume servicios externos inestables o críticos (sin integraciones de terceros que justifiquen el costo del breaker).

**Verificar:**
- [ ] Circuit breaker (Hystrix, resilience4j, pybreaker, Polly) alrededor de deps frágiles.
- [ ] Estados claros: closed / open / half-open.
- [ ] Umbrales y ventanas documentadas.
- [ ] Fallback definido cuando está abierto (ver `LLM-API-010`).

---

#### `ARCH-RES-003` — Bulkheads: recursos aislados por criticidad
**Severidad:** medium · **Aplica a:** backend

Un problema en una feature no tumba todo: pools / workers separados por área.

**Dónde buscar:** `**/config/**`, `**/services/**`, `**/workers/**`, `**/*.{ts,js,py,go,java,cs,yaml,yml}`
**Patrones:**
- `pool[_-]?(size|max|min)\s*[:=]`     # configuración de pools
- `new\s+(Pool|ThreadPoolExecutor|Semaphore)\s*\(`     # instanciación de pools/semáforos
- `bulkhead|isolation`     # primitivas explícitas de bulkhead
- `rate[_-]?limit.*per[_-]?(feature|endpoint)`     # rate limits por feature
- `concurrency\s*[:=]\s*\d+`     # límites de concurrencia configurados
**Señal de N/A:** la app es un servicio único pequeño (<3 features) donde el aislamiento por bulkhead no aporta vs el costo de complejidad.

**Verificar:**
- [ ] Pool de conexiones / workers separados para "análisis pesado" vs "login".
- [ ] Rate limits independientes por feature.
- [ ] Saturación en una parte no bloquea requests a otras.

---

#### `ARCH-RES-004` — Retries con política clara
**Severidad:** high · **Aplica a:** backend

Los retries ayudan ante fallas transitorias; mal configurados amplifican
outages.

**Dónde buscar:** `**/services/**`, `**/clients/**`, `**/utils/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `\b(retry|p-retry|async-retry|axios-retry|tenacity|backoff)\b`     # libs de retry
- `\b(exponential|jitter|backoff)\b`     # backoff exponencial / jitter
- `for\s*\(\s*let\s+\w+\s*=\s*0[^}]{0,200}\bawait\s+(fetch|axios)`     # retry naïve sin backoff
- `maxAttempts|max_retries|retries:\s*\d+`     # límite explícito de intentos
- `catch[\s\S]{0,200}\b(fetch|axios|request)\(`     # retry por catch (revisar política)
**Señal de N/A:** la app no realiza llamadas a servicios externos sujetas a fallos transitorios.

**Verificar:**
- [ ] Retry solo ante errores que tienen sentido reintentar (5xx, timeouts, 429).
- [ ] Backoff exponencial con jitter.
- [ ] Límite duro de intentos.
- [ ] Si el cliente pidió no reintentar (idempotency-key vencida), respetar.
- [ ] Los retries no se concatenan (retry en cliente + retry en servidor + retry en LB = storm).

---

## B. Idempotencia arquitectural

#### `ARCH-IDEM-001` — Idempotencia de cara al cliente
**Severidad:** high · **Aplica a:** api · backend

Las operaciones que el cliente puede reintentar son idempotentes.

**Dónde buscar:** `**/controllers/**`, `**/routes/**`, `**/handlers/**`, `**/middlewares/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `[Ii]dempotency[-_]?[Kk]ey`     # uso de Idempotency-Key header
- `@(Post|Put|Patch|Delete)\s*\(`     # endpoints mutadores (revisar idempotencia)
- `INSERT\s+INTO[\s\S]{0,200}ON\s+CONFLICT`     # upsert idempotente
- `(findOrCreate|upsert|merge)\s*\(`     # patrón upsert
**Señal de N/A:** la API es read-only (solo GET) o no expone operaciones que el cliente pueda reintentar.

(Ver `API-IDEM-001`.)

---

#### `ARCH-IDEM-002` — Idempotencia entre servicios y workers
**Severidad:** high · **Aplica a:** backend

Mensajes / eventos entre servicios se asumen at-least-once; los consumidores
son idempotentes o deduplican.

**Dónde buscar:** `**/workers/**`, `**/consumers/**`, `**/handlers/**`, `**/services/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `@(Process|EventPattern|MessagePattern|OnEvent)`     # handlers de eventos/jobs
- `(processed_events|dedup|idempotency_keys|message_ids)`     # tablas/cachés de dedup
- `INSERT\s+INTO[\s\S]{0,200}ON\s+CONFLICT.*DO\s+NOTHING`     # dedup vía constraint
- `await\s+\w+\.(send|publish|emit)\s*\([^)]*\)(?!.*key|.*id)`     # publicación sin id de mensaje (revisar)
**Señal de N/A:** la app no consume mensajes de colas/eventos (sin BullMQ/Kafka/RabbitMQ/SQS/etc.).

(Ver `CODE-EFFECT-002`, `API-HOOK-003`.)

---

## C. Patrones de consistencia

#### `ARCH-CONS-001` — Transacciones distribuidas evitadas o gestionadas
**Severidad:** high · **Aplica a:** backend

Si un flujo requiere consistencia entre sistemas, se usa saga (compensating
transactions) u outbox, no two-phase commit.

**Dónde buscar:** `**/services/**`, `**/sagas/**`, `**/workflows/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `\b(saga|orchestrator|choreography|temporal|cadence)\b`     # patrones saga / engines de workflow
- `\b(compensate|compensating|compensation)\b`     # compensaciones declaradas
- `\boutbox\b`     # outbox table/pattern
- `(2pc|two[_-]phase[_-]commit|XA[_-]?Transaction)`     # 2PC (anti-patrón a flagear)
**Señal de N/A:** los flujos de la app son single-DB single-service (no requieren consistencia entre sistemas).

**Verificar:**
- [ ] Outbox pattern cuando se deben publicar eventos consistentes con cambios en BD.
- [ ] Saga con pasos y compensaciones documentada para flujos multi-servicio.
- [ ] Consistencia eventual aceptada y expuesta honestamente al consumidor.

---

#### `ARCH-CONS-002` — Outbox para publicación confiable de eventos
**Severidad:** high · **Aplica a:** backend · data

Los eventos que deben publicarse "si la transacción commitea" se persisten en
una tabla outbox dentro de la misma transacción, y se publican de forma
asíncrona con garantías.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/services/**`, `**/workers/**`, `**/*.{sql,ts,js,py,go,java,cs}`
**Patrones:**
- `CREATE\s+TABLE\s+\w*outbox`     # tabla outbox
- `@Entity[\s\S]{0,200}[Oo]utbox`     # entidad outbox
- `INSERT\s+INTO\s+\w*outbox`     # inserción a outbox
- `(debezium|cdc|change[_-]data[_-]capture)`     # CDC como alternativa
**Señal de N/A:** la app no publica eventos a otros servicios desde transacciones de BD (solo HTTP request/response sin event-driven).

**Verificar:**
- [ ] Tabla `outbox` con mensajes pendientes.
- [ ] Publicador que lee y envía (at-least-once).
- [ ] Consumidores idempotentes.

---

## D. Comunicación confiable

#### `ARCH-MSG-001` — Colas con garantías claras
**Severidad:** high · **Aplica a:** backend · infra

Las colas/brokers usados se entienden en sus garantías (at-least-once,
at-most-once, ordenamiento, particiones).

**Dónde buscar:** `**/queues/**`, `**/workers/**`, `**/config/**`, `**/*.{ts,js,py,go,java,cs,yaml,yml}`, `**/docs/**`
**Patrones:**
- `(bullmq|kafka|rabbitmq|sqs|sns|nats|pubsub|kinesis|servicebus)`     # brokers
- `\bDLQ\b|dead[_-]?letter|deadLetterQueue`     # DLQ configurada
- `attempts\s*[:=]\s*\d+`     # max attempts antes de DLQ
- `retention|messageTtl|retention_ms`     # retención configurada
- `@Process[\s\S]{0,200}attempts`     # config de reintentos en consumer
**Señal de N/A:** la app no usa colas/brokers de mensajería (sin BullMQ/Kafka/RabbitMQ/SQS/NATS/PubSub en deps).

**Verificar:**
- [ ] Documentación de "qué garantías ofrece nuestra cola y qué asume el consumer".
- [ ] Dead Letter Queue (DLQ) para mensajes que fallan repetidamente.
- [ ] Alertas en DLQ con procedimiento para reprocesar.
- [ ] Retention adecuada al caso.

---

#### `ARCH-MSG-002` — Schemas de eventos versionados
**Severidad:** high · **Aplica a:** backend

Los eventos tienen schema versionado; cambios no rompen consumers existentes.

**Dónde buscar:** `**/events/**`, `**/contracts/**`, `**/schemas/**`, `**/*.{proto,avsc,json,yaml,ts,js}`
**Patrones:**
- `(avro|protobuf|json[_-]schema|schema[_-]registry|confluent)`     # registry/formato de schema
- `\.v\d+\b|version\s*[:=]\s*['"]?\d+`     # versionado en nombre/campo
- `eventVersion|schemaVersion|schema_version`     # campo de versión en payload
- `optional\s+\w+\s+\w+\s*=\s*\d+`     # campos protobuf opcionales (compat)
**Señal de N/A:** la app no publica eventos hacia otros servicios o consumidores externos (eventos sólo internos efímeros).

**Verificar:**
- [ ] Schema registry o archivo versionado en el repo.
- [ ] Cambios backward-compatible (campos opcionales).
- [ ] Breaking changes crean eventos nuevos, no reemplazan.
- [ ] Consumers toleran campos desconocidos.

---

## E. Failover y graceful degradation

#### `ARCH-DEGRAD-001` — Degradación definida por feature
**Severidad:** medium · **Aplica a:** backend · frontend

Para cada feature, se define qué pasa cuando una dependencia no está
disponible.

**Dónde buscar:** `**/services/**`, `**/clients/**`, `**/components/**`, `**/*.{ts,js,py,go,java,cs,tsx,jsx}`
**Patrones:**
- `\b(fallback|defaultValue|onError|catchError)\b`     # fallback definido
- `try\s*\{[\s\S]{0,500}\}\s*catch[\s\S]{0,200}return\s+(null|\[\]|\{\})`     # degrado silencioso (revisar)
- `<ErrorBoundary|componentDidCatch`     # error boundaries (frontend)
- `if\s*\(.*?(unavailable|disabled|degraded)`     # checks de degradación
**Señal de N/A:** la app es un script o batch sin features visibles al usuario donde la degradación parcial aplique.

**Verificar:**
- [ ] Mapa de dependencias y consecuencias de caída.
- [ ] Mensajes al usuario cuando una feature no está disponible (no 500 silencioso).
- [ ] Features básicas siguen funcionando cuando caen las avanzadas.

---

#### `ARCH-DEGRAD-002` — Kill switches para features de alto riesgo
**Severidad:** high · **Aplica a:** backend · frontend

Se pueden apagar instantáneamente features problemáticas sin redeploy.

**Dónde buscar:** `**/services/**`, `**/config/**`, `**/middlewares/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `(launchdarkly|unleash|flagsmith|configcat|growthbook|optimizely)`     # SaaS de feature flags
- `(featureFlag|isEnabled|feature\.enabled|isFeatureOn)`     # APIs de flags
- `process\.env\.FEATURE_\w+`     # flags vía env (kill switch sencillo)
- `if\s*\(\s*(killSwitch|disabled|maintenance)`     # kill switches manuales
**Señal de N/A:** la app no tiene features de alto riesgo (operaciones financieras, integraciones externas críticas, ML en producción).

(Ver `CICD-FLAG-001`.)

---

## F. Patrones específicos

#### `ARCH-PAT-001` — Read models / CQRS donde aporta
**Severidad:** low · **Aplica a:** backend

Para lecturas con requisitos muy distintos al modelo de escritura, un read
model dedicado (search index, view materializada).

**Dónde buscar:** `**/services/**`, `**/queries/**`, `**/read-models/**`, `**/migrations/**`, `**/*.{ts,js,py,go,java,cs,sql}`
**Patrones:**
- `CREATE\s+MATERIALIZED\s+VIEW`     # materialized views
- `(elasticsearch|opensearch|meilisearch|typesense|algolia)`     # search index como read model
- `@QueryHandler|read[_-]?model`     # handlers de query / read models
- `REFRESH\s+MATERIALIZED\s+VIEW`     # refresh de materialized views
**Señal de N/A:** la app no tiene flujos de lectura con requisitos divergentes del modelo de escritura (CRUD simple).

---

#### `ARCH-PAT-002` — Event-sourcing evaluado cuando aplica
**Severidad:** low · **Aplica a:** backend

Para dominios donde la historia importa (auditoría, financiero), se evalúa
event sourcing.

**Dónde buscar:** `**/domain/**`, `**/events/**`, `**/services/**`, `**/migrations/**`, `**/*.{ts,js,py,go,java,cs,sql}`
**Patrones:**
- `(eventstore|eventstoredb|axon|eventuate|nest-event-sourcing)`     # libs de event sourcing
- `\b(aggregate|aggregateRoot|applyEvent|loadFromHistory)\b`     # primitivas de event sourcing
- `CREATE\s+TABLE\s+\w*events?`     # tabla de eventos persistente
- `version\s*[:=]\s*\w+\.version\s*\+\s*1`     # versionado optimista de aggregate
**Señal de N/A:** el dominio no requiere historia inmutable (sin requisitos regulatorios/auditoría que justifiquen el costo del event sourcing).

---

#### `ARCH-PAT-003` — Sidecar / gateway para cross-cutting concerns
**Severidad:** medium · **Aplica a:** infra

Autenticación, rate limiting, logging de red, tracing pueden vivir en un
gateway/sidecar, no duplicados en cada servicio.

**Dónde buscar:** `**/infra/**`, `**/k8s/**`, `**/gateway/**`, `**/*.{yaml,yml,tf,conf}`, `**/services/**`
**Patrones:**
- `(istio|linkerd|consul|envoy|traefik|kong|ambassador|nginx-ingress)`     # service mesh / gateways
- `(VirtualService|DestinationRule|Gateway):`     # CRDs de Istio
- `mtls|tls\.mode|ISTIO_MUTUAL`     # mTLS configurado
- `@ApiGateway|x-api-gateway|cors|rate[_-]?limit`     # configuración cross-cutting en gateway
**Señal de N/A:** el repo es un servicio único sin microservicios ni service mesh; cross-cutting concerns viven en middlewares de la propia app.

**Verificar:**
- [ ] API gateway centraliza auth común, rate limit, logging.
- [ ] Service mesh (si se usa) aporta mTLS, retries, circuit breakers consistentes.

---

## Checklist resumen

| ID                 | Control                                             | Severidad |
| ------------------ | --------------------------------------------------- | --------- |
| ARCH-RES-001       | Timeouts universales                                | critical  |
| ARCH-RES-002       | Circuit breakers                                    | high      |
| ARCH-RES-003       | Bulkheads                                           | medium    |
| ARCH-RES-004       | Retries con política clara                          | high      |
| ARCH-IDEM-001      | Idempotencia cliente                                | high      |
| ARCH-IDEM-002      | Idempotencia entre servicios                        | high      |
| ARCH-CONS-001      | Transacciones distribuidas vía saga                 | high      |
| ARCH-CONS-002      | Outbox pattern                                      | high      |
| ARCH-MSG-001       | Colas con garantías claras + DLQ                    | high      |
| ARCH-MSG-002       | Schemas de eventos versionados                      | high      |
| ARCH-DEGRAD-001    | Degradación por feature                             | medium    |
| ARCH-DEGRAD-002    | Kill switches                                       | high      |
| ARCH-PAT-001       | Read models / CQRS si aporta                        | low       |
| ARCH-PAT-002       | Event-sourcing evaluado                             | low       |
| ARCH-PAT-003       | Sidecar/gateway para cross-cutting                  | medium    |
