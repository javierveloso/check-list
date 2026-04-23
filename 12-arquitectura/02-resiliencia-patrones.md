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

(Ver `SEC-HEADERS-041`, `CODE-ASYNC-004`, `PERF-BE-003`.)

---

#### `ARCH-RES-002` — Circuit breakers ante servicios inestables
**Severidad:** high · **Tags:** `resilience` · **Aplica a:** backend

Cuando una dependencia falla repetidamente, el circuit breaker "abre" y
rechaza rápido.

**Verificar:**
- [ ] Circuit breaker (Hystrix, resilience4j, pybreaker, Polly) alrededor de deps frágiles.
- [ ] Estados claros: closed / open / half-open.
- [ ] Umbrales y ventanas documentadas.
- [ ] Fallback definido cuando está abierto (ver `LLM-API-010`).

---

#### `ARCH-RES-003` — Bulkheads: recursos aislados por criticidad
**Severidad:** medium · **Aplica a:** backend

Un problema en una feature no tumba todo: pools / workers separados por área.

**Verificar:**
- [ ] Pool de conexiones / workers separados para "análisis pesado" vs "login".
- [ ] Rate limits independientes por feature.
- [ ] Saturación en una parte no bloquea requests a otras.

---

#### `ARCH-RES-004` — Retries con política clara
**Severidad:** high · **Aplica a:** backend

Los retries ayudan ante fallas transitorias; mal configurados amplifican
outages.

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

(Ver `API-IDEM-001`.)

---

#### `ARCH-IDEM-002` — Idempotencia entre servicios y workers
**Severidad:** high · **Aplica a:** backend

Mensajes / eventos entre servicios se asumen at-least-once; los consumidores
son idempotentes o deduplican.

(Ver `CODE-EFFECT-002`, `API-HOOK-003`.)

---

## C. Patrones de consistencia

#### `ARCH-CONS-001` — Transacciones distribuidas evitadas o gestionadas
**Severidad:** high · **Aplica a:** backend

Si un flujo requiere consistencia entre sistemas, se usa saga (compensating
transactions) u outbox, no two-phase commit.

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

**Verificar:**
- [ ] Documentación de "qué garantías ofrece nuestra cola y qué asume el consumer".
- [ ] Dead Letter Queue (DLQ) para mensajes que fallan repetidamente.
- [ ] Alertas en DLQ con procedimiento para reprocesar.
- [ ] Retention adecuada al caso.

---

#### `ARCH-MSG-002` — Schemas de eventos versionados
**Severidad:** high · **Aplica a:** backend

Los eventos tienen schema versionado; cambios no rompen consumers existentes.

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

**Verificar:**
- [ ] Mapa de dependencias y consecuencias de caída.
- [ ] Mensajes al usuario cuando una feature no está disponible (no 500 silencioso).
- [ ] Features básicas siguen funcionando cuando caen las avanzadas.

---

#### `ARCH-DEGRAD-002` — Kill switches para features de alto riesgo
**Severidad:** high · **Aplica a:** backend · frontend

Se pueden apagar instantáneamente features problemáticas sin redeploy.

(Ver `CICD-FLAG-001`.)

---

## F. Patrones específicos

#### `ARCH-PAT-001` — Read models / CQRS donde aporta
**Severidad:** low · **Aplica a:** backend

Para lecturas con requisitos muy distintos al modelo de escritura, un read
model dedicado (search index, view materializada).

---

#### `ARCH-PAT-002` — Event-sourcing evaluado cuando aplica
**Severidad:** low · **Aplica a:** backend

Para dominios donde la historia importa (auditoría, financiero), se evalúa
event sourcing.

---

#### `ARCH-PAT-003` — Sidecar / gateway para cross-cutting concerns
**Severidad:** medium · **Aplica a:** infra

Autenticación, rate limiting, logging de red, tracing pueden vivir en un
gateway/sidecar, no duplicados en cada servicio.

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
