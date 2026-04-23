# 05 · Rendimiento · Base de datos y red

> Consultas, índices, transacciones y patrones de red (en el contexto de
> rendimiento). La higiene estructural de BD está en `13-base-datos/`.

---

## A. Consultas

#### `PERF-DB-001` — Queries con EXPLAIN analizadas en críticos
**Severidad:** high · **Aplica a:** backend

Las consultas de endpoints calientes se revisan con EXPLAIN (ANALYZE) antes de
mergear; no hay full table scans ocultos.

**Verificar:**
- [ ] Las consultas en hot paths se revisan en PR.
- [ ] EXPLAIN muestra uso de índices, no `Seq Scan` en tablas grandes.
- [ ] Coste estimado dentro de rango razonable.
- [ ] Los JOINs usan el orden correcto / hints cuando el planner falla.

---

#### `PERF-DB-002` — SELECT solo los campos necesarios
**Severidad:** medium · **Aplica a:** backend

`SELECT *` se evita cuando la tabla tiene columnas grandes (texto, blobs) que
no se usan.

**Verificar:**
- [ ] En queries con columnas grandes, se listan los campos necesarios.
- [ ] El ORM está configurado para hidratar solo lo que se usa, cuando aporta.
- [ ] Las columnas grandes (documento, blob) se guardan en tabla separada cuando el acceso es raro.

---

#### `PERF-DB-003` — N+1 detectado y eliminado
**Severidad:** high · **Tags:** `n+1` · **Aplica a:** backend

Se cargan los relacionados en la misma query cuando se van a usar.

**Verificar:**
- [ ] Eager loading (`selectinload`, `joinedload`, `include`, `prefetch_related`) donde se necesita.
- [ ] Lazy por defecto para asociaciones pesadas.
- [ ] Herramientas detectan N+1 en pruebas (bullet, query-analyzer, custom middleware que cuenta queries).

**Banderas rojas:**
- Query count escalando con N en un endpoint (logs muestran 1 + N queries).

---

#### `PERF-DB-004` — Batching de operaciones
**Severidad:** medium · **Aplica a:** backend

Inserts/updates masivos van en bulk, no uno por uno.

**Verificar:**
- [ ] `bulk_insert`, `INSERT ... VALUES (...), (...), ...` en cargas grandes.
- [ ] COPY / stream bulk para cargas masivas.
- [ ] Upserts (ON CONFLICT) agrupados.

**Banderas rojas:**
- Loop que hace `session.add(obj); session.commit()` por item.

---

## B. Índices

#### `PERF-DB-010` — Índices sobre columnas de filtro/orden
**Severidad:** high · **Aplica a:** backend · data

Cada columna que aparece en WHERE, JOIN, ORDER BY de queries frecuentes tiene
índice.

**Verificar:**
- [ ] Foreign keys indexadas (no siempre lo hacen por defecto).
- [ ] Columnas de búsqueda (status, created_at, user_id) indexadas.
- [ ] Índices compuestos en orden correcto para multi-column filtros.
- [ ] Índices parciales / funcionales donde aporten.

---

#### `PERF-DB-011` — Índices no redundantes ni excesivos
**Severidad:** medium · **Aplica a:** data

Cada índice tiene costo (escritura y espacio). Se eliminan los duplicados o
nunca usados.

**Verificar:**
- [ ] Auditoría periódica con `pg_stat_user_indexes` / equivalente.
- [ ] Índices sin uso se eliminan.
- [ ] Índices que son prefijo de otro más general se revisan.

---

## C. Transacciones

#### `PERF-DB-020` — Transacciones cortas
**Severidad:** high · **Aplica a:** backend

Las transacciones cubren el scope mínimo necesario — no incluyen llamadas HTTP
externas, ni operaciones largas que bloqueen filas.

**Verificar:**
- [ ] No hay `await external_api()` dentro de una transacción abierta.
- [ ] El commit ocurre pronto; la lógica externa va fuera.
- [ ] Long-running reports usan snapshots o lecturas READ COMMITTED.

**Banderas rojas:**
- Transacción que abre, envía email, espera respuesta y luego commit.

---

#### `PERF-DB-021` — Niveles de aislamiento apropiados
**Severidad:** medium · **Aplica a:** backend

El nivel de aislamiento se elige conscientemente por caso (READ COMMITTED por
defecto; SERIALIZABLE solo cuando se requiere).

**Verificar:**
- [ ] El isolation level por defecto está definido.
- [ ] Operaciones críticas documentan el nivel usado.
- [ ] Se manejan errores de serialización (retry con backoff).

---

#### `PERF-DB-022` — Deadlocks y lock contention monitoreados
**Severidad:** medium · **Aplica a:** data

Deadlocks y waits largos se miden y se alertan.

**Verificar:**
- [ ] Métricas: locks, wait events, deadlocks detectados.
- [ ] Orden consistente al tomar múltiples locks.
- [ ] `NOWAIT` / timeout en locks donde aplique.

---

## D. Concurrencia a nivel dato

#### `PERF-DB-030` — Counters y hot rows con técnicas específicas
**Severidad:** medium · **Aplica a:** data

Filas muy contendidas (contador global, semáforo) usan patrones que reducen
lock contention.

**Verificar:**
- [ ] Sharded counters, eventual counters, o materializaciones periódicas.
- [ ] No hay "hot row" tomando lock por cada request.

---

## E. Red y latencia

#### `PERF-NET-001` — Compresión en respuestas
**Severidad:** medium · **Aplica a:** infra · backend

Las respuestas textuales se comprimen con gzip/brotli.

**Verificar:**
- [ ] Gzip o Brotli habilitado en reverse proxy / CDN.
- [ ] Se respeta `Accept-Encoding`.
- [ ] Contenido ya comprimido (imágenes, video) no se recomprime.
- [ ] Protección contra BREACH: no mezclar secretos con datos del usuario en el body cuando hay compresión.

---

#### `PERF-NET-002` — CDN para assets y contenido cacheable
**Severidad:** high · **Aplica a:** infra

Assets estáticos y contenido público se sirven por CDN geográficamente
distribuido.

**Verificar:**
- [ ] CDN para estáticos con caché inmutable.
- [ ] CDN frente a la API cuando sea posible para caching de rutas públicas.
- [ ] Purge/invalidation funcionan al deploy.

---

#### `PERF-NET-003` — Edge computing para latencia crítica
**Severidad:** low · **Aplica a:** infra

Para ciertos flujos con latencia crítica, cómputo en edge (Cloudflare Workers,
Lambda@Edge, Deno Deploy).

---

## Checklist resumen

| ID             | Control                                           | Severidad |
| -------------- | ------------------------------------------------- | --------- |
| PERF-DB-001    | EXPLAIN analizado en críticos                     | high      |
| PERF-DB-002    | SELECT campos necesarios                          | medium    |
| PERF-DB-003    | N+1 eliminado                                     | high      |
| PERF-DB-004    | Batching de operaciones                           | medium    |
| PERF-DB-010    | Índices sobre columnas de filtro/orden            | high      |
| PERF-DB-011    | Índices no redundantes                            | medium    |
| PERF-DB-020    | Transacciones cortas                              | high      |
| PERF-DB-021    | Niveles de aislamiento apropiados                 | medium    |
| PERF-DB-022    | Deadlocks monitoreados                            | medium    |
| PERF-DB-030    | Hot rows con técnicas específicas                 | medium    |
| PERF-NET-001   | Compresión en respuestas                          | medium    |
| PERF-NET-002   | CDN para assets                                   | high      |
| PERF-NET-003   | Edge computing si aplica                          | low       |
