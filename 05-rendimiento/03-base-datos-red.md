# 05 · Rendimiento · Base de datos y red

> Consultas, índices, transacciones y patrones de red (en el contexto de
> rendimiento). La higiene estructural de BD está en `13-base-datos/`.

---

## A. Consultas

#### `PERF-DB-001` — Queries con EXPLAIN analizadas en críticos
**Severidad:** high · **Aplica a:** backend

Las consultas de endpoints calientes se revisan con EXPLAIN (ANALYZE) antes de
mergear; no hay full table scans ocultos.

**Dónde buscar:** `**/*.{ts,js,py,go,sql}`, `**/migrations/**`, `**/repositories/**`, `**/queries/**`, `**/docs/**`
**Patrones:**
- `EXPLAIN\s+(ANALYZE|VERBOSE)?\s+(SELECT|UPDATE|DELETE)` # uso de EXPLAIN
- `Seq\s+Scan|Sequential\s+Scan`           # full scan reportado en docs
- `LEFT\s+JOIN[\s\S]{0,200}LEFT\s+JOIN[\s\S]{0,200}LEFT\s+JOIN` # joins múltiples
- `(NOT\s+IN|NOT\s+EXISTS)\s*\(\s*SELECT`  # patrones costosos
- `pg_stat_statements|slow_query_log|long_query_time` # observabilidad de queries

**Señal de N/A:** sistema sin BD relacional o sin endpoints calientes definidos.

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

**Dónde buscar:** `**/*.{ts,js,py,go,sql}`, `**/repositories/**`, `**/queries/**`, `**/migrations/**`
**Patrones:**
- `SELECT\s+\*\s+FROM`                     # select all
- `repository\.find\(\{\s*\}\)`            # ORM find sin select
- `\.findAll\(\)|\.find\(\)\.exec\(\)`     # find sin proyección
- `select\s*:\s*\{|attributes\s*:\s*\[`    # proyección explícita (positivo)
- `(text|json|jsonb|blob|bytea)\s+(NOT\s+)?NULL` # columnas grandes en migrations

**Señal de N/A:** tablas con pocos campos pequeños donde SELECT * es trivial.

**Verificar:**
- [ ] En queries con columnas grandes, se listan los campos necesarios.
- [ ] El ORM está configurado para hidratar solo lo que se usa, cuando aporta.
- [ ] Las columnas grandes (documento, blob) se guardan en tabla separada cuando el acceso es raro.

---

#### `PERF-DB-003` — N+1 detectado y eliminado
**Severidad:** high · **Tags:** `n+1` · **Aplica a:** backend

Se cargan los relacionados en la misma query cuando se van a usar.

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/repositories/**`, `**/handlers/**`
**Patrones:**
- `\.forEach\([\s\S]{0,200}await[\s\S]{0,200}(find|query)` # N+1 con forEach
- `for\s*\(.*of[\s\S]{0,200}await[\s\S]{0,200}repository\.` # N+1 con for-of
- `\.map\(\s*async[\s\S]{0,200}\.find` # N+1 con map async
- `(joinedload|selectinload|include\s*:|relations\s*:|prefetch_related|withGraphFetched)` # eager loading (positivo)
- `(dataloader|@graphql/dataloader)` # batching de queries

**Señal de N/A:** sistema sin relaciones entre entidades.

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

**Dónde buscar:** `**/*.{ts,js,py,go,sql}`, `**/repositories/**`, `**/services/**`, `**/migrations/**`, `**/jobs/**`
**Patrones:**
- `for[\s\S]{0,200}await[\s\S]{0,200}(repository\.save|\.insert\(|session\.add)` # save en loop
- `INSERT\s+INTO\s+\w+[\s\S]{0,500}VALUES\s*\([^)]+\)\s*,\s*\(` # multi-row insert (positivo)
- `(bulkInsert|bulk_insert|insertMany|createMany|bulk_create)` # API bulk (positivo)
- `COPY\s+\w+\s+FROM|\\copy`               # COPY de Postgres
- `ON\s+CONFLICT\s*\([^)]+\)\s+DO\s+(UPDATE|NOTHING)` # upsert

**Señal de N/A:** sistema sin operaciones masivas (siempre 1 fila por request).

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

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/models/**`, `**/*.{ts,js,py,sql}`, `**/schema.{prisma,sql}`
**Patrones:**
- `CREATE\s+(UNIQUE\s+)?INDEX`             # índices declarados
- `@Index\(|@Column[\s\S]{0,50}index:\s*true|index=True` # índices en ORM
- `FOREIGN\s+KEY|@JoinColumn|references\s*:` # FKs (deberían tener índice)
- `WHERE\s+\w+\s*=|ORDER\s+BY\s+\w+`       # columnas usadas (verificar índice)
- `LIKE\s+['"]%`                           # LIKE con prefijo (no usa índice)
- `CREATE\s+INDEX[\s\S]{0,100}WHERE`       # índice parcial (positivo)

**Señal de N/A:** BD pequeña sin necesidad de optimización por índices.

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

**Dónde buscar:** `**/migrations/**`, `**/scripts/**`, `**/db-maintenance/**`, `**/docs/**`
**Patrones:**
- `pg_stat_user_indexes|pg_stat_all_indexes` # auditoría Postgres
- `sys\.dm_db_index_usage_stats`           # SQL Server
- `DROP\s+INDEX`                           # eliminación documentada (positivo)
- `CREATE\s+(UNIQUE\s+)?INDEX[\s\S]{0,200}\(\w+\)[\s\S]{0,500}CREATE\s+(UNIQUE\s+)?INDEX[\s\S]{0,200}\(\w+,` # posible solapamiento
- `idx_unused|unused_indexes`              # query/script de auditoría

**Señal de N/A:** BD nueva sin acumulación histórica de índices.

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

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/repositories/**`, `**/handlers/**`
**Patrones:**
- `(BEGIN|START\s+TRANSACTION|startTransaction|transaction\(|@Transactional)[\s\S]{0,500}(axios|fetch|httpx|requests)` # HTTP dentro de tx
- `(BEGIN|startTransaction|transaction\()[\s\S]{0,500}(sendMail|publish|sleep)` # I/O dentro de tx
- `manager\.transaction\(|sequelize\.transaction\(|await\s+session\.begin\(` # uso (positivo si scope corto)
- `SELECT\s+\.\.\.\s+FOR\s+UPDATE`         # locks explícitos (revisar duración)
- `READ\s+(COMMITTED|UNCOMMITTED)|REPEATABLE\s+READ|SERIALIZABLE` # isolation explícito

**Señal de N/A:** sistema sin transacciones (operaciones atómicas independientes).

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

**Dónde buscar:** `**/*.{ts,js,py,go}`, `**/services/**`, `**/repositories/**`, `**/data-source.*`, `**/config/**`
**Patrones:**
- `SET\s+TRANSACTION\s+ISOLATION\s+LEVEL` # configuración explícita
- `IsolationLevel\.|isolationLevel\s*:`    # ORM level
- `READ\s+COMMITTED|REPEATABLE\s+READ|SERIALIZABLE` # niveles
- `(SerializationFailure|40001|deadlock_detected)` # manejo de retry
- `retry|backoff|exponential` # política de reintentos

**Señal de N/A:** carga ligera donde el isolation level por defecto basta.

**Verificar:**
- [ ] El isolation level por defecto está definido.
- [ ] Operaciones críticas documentan el nivel usado.
- [ ] Se manejan errores de serialización (retry con backoff).

---

#### `PERF-DB-022` — Deadlocks y lock contention monitoreados
**Severidad:** medium · **Aplica a:** data

Deadlocks y waits largos se miden y se alertan.

**Dónde buscar:** `**/*.{ts,js,py,sql}`, `**/observability/**`, `**/metrics/**`, `**/scripts/**`
**Patrones:**
- `pg_locks|pg_stat_activity|pg_blocking_pids` # observabilidad Postgres
- `INNODB_TRX|INNODB_LOCKS`                # MySQL
- `NOWAIT|SKIP\s+LOCKED|lock_timeout`      # patrones de no bloqueo
- `(deadlock|deadlocked)`                  # alertas/logs
- `lock_wait_time|lockTimeout`             # métricas

**Señal de N/A:** carga ligera sin contención observada.

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

**Dónde buscar:** `**/*.{ts,js,py,sql}`, `**/migrations/**`, `**/services/**`, `**/jobs/**`
**Patrones:**
- `UPDATE\s+\w+\s+SET\s+(counter|count|total|qty|quantity|stock)\s*=\s*\1\s*[+\-]` # contador global
- `SELECT[\s\S]{0,200}FOR\s+UPDATE`        # lock pesimista frecuente
- `(shard|sharded|partition)[\s_-]?counter` # sharding (positivo)
- `materialized\s+view`                    # materialización (positivo)
- `INSERT[\s\S]{0,200}ON\s+CONFLICT[\s\S]{0,200}DO\s+UPDATE[\s\S]{0,200}counter` # upsert sobre hot row

**Señal de N/A:** sin filas/recursos identificados como hot.

**Verificar:**
- [ ] Sharded counters, eventual counters, o materializaciones periódicas.
- [ ] No hay "hot row" tomando lock por cada request.

---

## E. Red y latencia

#### `PERF-NET-001` — Compresión en respuestas
**Severidad:** medium · **Aplica a:** infra · backend

Las respuestas textuales se comprimen con gzip/brotli.

**Dónde buscar:** `**/nginx*.conf`, `**/cloudfront*.{json,yaml,tf}`, `**/*.{ts,js,py,go}`, `**/middleware/**`, `**/app.{ts,js,py}`
**Patrones:**
- `(compression|@fastify/compress|express-static-gzip|brotli)` # libs de compresión
- `gzip\s+(on|true)|brotli\s+(on|true)`    # config nginx
- `Content-Encoding:\s*(gzip|br|deflate)`  # header
- `app\.use\(compression\(\)|server\.register\(compress` # middleware
- `Accept-Encoding`                        # detección
- `(BREACH|CRIME)`                         # consideraciones de seguridad

**Señal de N/A:** servicio que solo retorna binarios ya comprimidos (imágenes, video).

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

**Dónde buscar:** `**/cloudfront*.{json,yaml,tf}`, `**/cdn*.{json,yaml,tf}`, `**/*.tf`, `vercel.json`, `netlify.toml`, `**/k8s/**/*.yaml`
**Patrones:**
- `(cloudfront|cloudflare|fastly|akamai|bunny|keycdn|stackpath)` # proveedores CDN
- `aws_cloudfront_distribution|cloudflare_zone` # IaC
- `purge_(cache|cdn|all)|invalidate`       # invalidación
- `Cache-Control[\s\S]{0,100}immutable`    # cache largo
- `(edge|origin)_(cache|response)` # config CDN

**Señal de N/A:** producto interno con tráfico geográficamente concentrado donde CDN no aporta.

**Verificar:**
- [ ] CDN para estáticos con caché inmutable.
- [ ] CDN frente a la API cuando sea posible para caching de rutas públicas.
- [ ] Purge/invalidation funcionan al deploy.

---

#### `PERF-NET-003` — Edge computing para latencia crítica
**Severidad:** low · **Aplica a:** infra

Para ciertos flujos con latencia crítica, cómputo en edge (Cloudflare Workers,
Lambda@Edge, Deno Deploy).

**Dónde buscar:** `**/*.{ts,js}`, `wrangler.toml`, `**/edge/**`, `**/middleware.ts`, `vercel.json`, `netlify.toml`, `**/functions/**`
**Patrones:**
- `(cloudflare\s*workers|@cloudflare/workers-types|wrangler)` # Cloudflare Workers
- `Lambda@Edge|aws_cloudfront_function`    # AWS edge
- `(deno\s+deploy|deno\.land/std|@deno)`   # Deno Deploy
- `export\s+const\s+config\s*=\s*\{[\s\S]{0,200}runtime\s*:\s*['"]edge['"]` # Vercel edge
- `netlify[/-]edge[-_]functions`           # Netlify edge

**Señal de N/A:** producto sin requisitos de latencia ultra-baja en geografías diversas.

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
