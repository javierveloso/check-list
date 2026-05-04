# 13 · Base de datos · Queries, índices y transacciones

> Consultas eficientes, uso de índices, concurrencia, transacciones, backups.

---

## A. Queries eficientes

#### `DB-QRY-001` — SELECT acotado a campos necesarios
**Severidad:** medium · **Aplica a:** backend · data

Se evita `SELECT *` en queries de alta frecuencia sobre tablas con columnas
grandes.

**Dónde buscar:** `**/repositories/**`, `**/services/**`, `**/db/**`, `**/queries/**`, `**/*.{sql,ts,js,py,go,java,cs}`
**Patrones:**
- `SELECT\s+\*\s+FROM`     # SELECT * literal
- `\.findAll\(\s*\)|\.find\(\s*\{\s*\}\s*\)`     # ORM findAll sin select
- `\.find\([^)]*\)(?!.*select|.*\.select)`     # find sin select fields
- `\.query\s*\(\s*['"`]SELECT\s+\*`     # raw query con SELECT *
- `repository\.(find|findOne)\([^)]*\)(?!.*select)`     # TypeORM repo sin select
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

(Ver `PERF-DB-002`.)

---

#### `DB-QRY-002` — N+1 evitado con eager loading apropiado
**Severidad:** high · **Aplica a:** backend

Relaciones que se usan juntas se cargan juntas.

**Dónde buscar:** `**/repositories/**`, `**/services/**`, `**/db/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `forEach\s*\([^)]*\)\s*\{[\s\S]{0,500}\bawait\s+\w+\.(find|findOne|query)`     # await en forEach (N+1 clásico)
- `for\s*\(\s*const\s+\w+\s+of\s+\w+\s*\)\s*\{[\s\S]{0,500}\bawait\s+\w+\.(find|findOne)`     # for-of con await por item
- `\.map\s*\(\s*async\s+\w+\s*=>\s*\{[\s\S]{0,300}\bawait\s+\w+\.(find|findOne)`     # map(async) con queries
- `\.find\([^)]*\)(?!.*relations|.*include|.*populate|.*joinedLoad)`     # find sin eager loading
- `\b(include|populate|joinedLoad|with|preload|relations:)`     # eager loading explícito
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

(Ver `PERF-DB-003`.)

---

#### `DB-QRY-003` — LIMIT obligatorio en listados
**Severidad:** high · **Aplica a:** backend · api

Ningún handler productivo hace `SELECT ... FROM table` sin LIMIT.

**Dónde buscar:** `**/controllers/**`, `**/repositories/**`, `**/services/**`, `**/handlers/**`, `**/*.{sql,ts,js,py,go,java,cs}`
**Patrones:**
- `\.findAll\s*\(\s*\)`     # findAll sin paginación
- `SELECT\s+[\s\S]{0,200}FROM\s+\w+\s*(?:WHERE\s+[\s\S]{0,200})?(?!.*LIMIT)\s*;`     # SELECT sin LIMIT
- `\.find\(\s*\{[^}]*\}\s*\)(?!.*take|.*limit|.*\$top)`     # find sin take/limit
- `\.findMany\(\s*\{[^}]*\}\s*\)(?!.*take|.*skip)`     # Prisma findMany sin take
- `OFFSET\s+\d{4,}`     # paginación profunda inestable
**Señal de N/A:** no hay BD en el stack o todos los listados son por colecciones inherentemente acotadas (e.g., enums fijos).

(Ver `API-PAGE-001`, `PERF-BE-051`.)

---

#### `DB-QRY-004` — Batching de escrituras
**Severidad:** medium · **Aplica a:** backend

Inserts/updates masivos se agrupan.

**Dónde buscar:** `**/repositories/**`, `**/services/**`, `**/jobs/**`, `**/scripts/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `forEach\s*\([^)]*\)\s*\{[\s\S]{0,300}\bawait\s+\w+\.(save|insert|create|update)\s*\(`     # save en loop (N inserts)
- `for\s+\w+\s+in\s+\w+:[\s\S]{0,300}\.(save|insert|create|update)\s*\(`     # python for con save
- `\.(insert|save|create)Many|bulkCreate|bulkInsert|bulkWrite|insert_all|copy_from`     # batching API
- `INSERT\s+INTO[\s\S]{0,200}VALUES\s*\([^)]+\)\s*,\s*\(`     # multi-row VALUES
**Señal de N/A:** no hay BD en el stack o no hay flujos de carga masiva (single-row writes esporádicos).

(Ver `PERF-DB-004`.)

---

#### `DB-QRY-005` — Queries lentas auditadas
**Severidad:** high · **Aplica a:** data

Se identifica y corrige queries lentas periódicamente.

**Dónde buscar:** `**/config/**`, `**/db/**`, `**/infra/**`, `**/observability/**`, `**/*.{conf,sql,yaml,yml,ts,js,py}`, `postgresql.conf`, `my.cnf`
**Patrones:**
- `pg_stat_statements|slow_query_log|long_query_time|log_min_duration_statement`     # slow query logging habilitado
- `(datadog|newrelic|prometheus|grafana|appdynamics).*db|database.*query`     # APM con métricas de BD
- `EXPLAIN(\s+ANALYZE)?`     # análisis de planes
- `pg_stat_activity|SHOW\s+PROCESSLIST`     # observación en runtime
**Señal de N/A:** no hay BD en el stack o el volumen es trivial (<1k rows, sin queries productivas relevantes).

**Verificar:**
- [ ] Slow query log / `pg_stat_statements` habilitado en producción.
- [ ] Revisión semanal/quincenal de top queries por tiempo y por número de llamadas.
- [ ] Query lentas atribuidas a endpoints / features.
- [ ] Fix priorizado según impacto.

---

## B. Índices

#### `DB-IDX-001` — Índices para filtros comunes y FKs
**Severidad:** high · **Aplica a:** data

Columnas que aparecen frecuentemente en `WHERE`, `JOIN`, `ORDER BY` están
indexadas.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/*.{sql,prisma}`, `**/*.entity.{ts,js}`, `**/schema.prisma`
**Patrones:**
- `CREATE\s+(UNIQUE\s+)?INDEX`     # presencia de índices
- `@Index\s*\(`     # decorador de índice (TypeORM)
- `@@index\s*\(\s*\[`     # @@index en Prisma
- `FOREIGN\s+KEY\s*\(\s*(\w+)\s*\)\s+REFERENCES`     # FKs (verificar índice asociado)
- `WHERE\s+\w+\s*=`     # columnas en WHERE (revisar índice)
**Señal de N/A:** no hay BD en el stack o todas las tablas son pequeñas (<1k rows) donde el full scan es aceptable.

(Ver `PERF-DB-010`.)

---

#### `DB-IDX-002` — Índices compuestos en orden correcto
**Severidad:** medium · **Aplica a:** data

Los índices multi-columna siguen el orden por cardinalidad y uso.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/*.{sql,prisma}`, `**/*.entity.{ts,js}`, `**/schema.prisma`
**Patrones:**
- `CREATE\s+INDEX\s+\w+\s+ON\s+\w+\s*\([^)]+,[^)]+\)`     # índices compuestos
- `@Index\s*\(\s*\[\s*['"]\w+['"]\s*,\s*['"]\w+['"]`     # índice compuesto (TypeORM)
- `@@index\s*\(\s*\[\s*\w+\s*,\s*\w+`     # índice compuesto (Prisma)
- `INCLUDE\s*\(`     # covering index
**Señal de N/A:** no hay BD en el stack o no hay queries con filtros multi-columna frecuentes.

**Verificar:**
- [ ] Columnas en el orden que usan las queries.
- [ ] Índices cubren queries frecuentes ("covering index") cuando aporta.
- [ ] Se evalúa reemplazar varios índices uni-columna por uno compuesto cuando aplica.

---

#### `DB-IDX-003` — Tipos de índice apropiados
**Severidad:** medium · **Aplica a:** data

B-tree no siempre es la mejor opción.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/*.{sql,prisma}`, `**/*.entity.{ts,js}`
**Patrones:**
- `USING\s+(GIN|GIST|HASH|BRIN|SPGIST)`     # tipos de índice no-btree
- `pg_trgm|gin_trgm_ops|gist_trgm_ops`     # trigram para LIKE
- `tsvector|to_tsvector|tsquery`     # full-text search
- `pgvector|vector\(\d+\)|ivfflat|hnsw`     # índices vectoriales
- `CREATE\s+INDEX[\s\S]{0,200}WHERE`     # partial index
**Señal de N/A:** no hay BD en el stack o no hay queries de full-text/búsqueda fuzzy/vectorial (solo equality/range).

**Verificar:**
- [ ] GIN/GiST para full-text (tsvector).
- [ ] Trigram (`pg_trgm`) o equivalente para búsquedas LIKE.
- [ ] Vectorial (pgvector, Pinecone, etc.) para embeddings.
- [ ] Hash / partial index en casos específicos.

---

#### `DB-IDX-004` — Índices no usados eliminados
**Severidad:** medium · **Aplica a:** data

Índices ocupan espacio y ralentizan escrituras. Se remueven los inútiles.

**Dónde buscar:** `**/migrations/**`, `**/db/**`, `**/scripts/**`, `**/*.{sql}`
**Patrones:**
- `DROP\s+INDEX`     # drops de índices históricos
- `pg_stat_user_indexes|idx_scan\s*=\s*0`     # consultas a estadísticas de uso
- `CREATE\s+INDEX`     # contar indices vs tablas (ratio sospechoso)
- *(además — revisión humana del uso real con `pg_stat_user_indexes`)*
**Señal de N/A:** no hay BD en el stack o el schema es nuevo (<6 meses) sin acumulación histórica de índices obsoletos.

(Ver `PERF-DB-011`.)

---

#### `DB-IDX-005` — Cambios de índice seguros
**Severidad:** medium · **Aplica a:** data

Crear/eliminar índices en tablas grandes se hace sin bloquear lecturas.

**Dónde buscar:** `**/migrations/**`, `**/db/**`, `**/*.{sql,ts,js,py}`
**Patrones:**
- `CREATE\s+INDEX\s+(?!CONCURRENTLY)`     # PostgreSQL CREATE INDEX sin CONCURRENTLY
- `DROP\s+INDEX\s+(?!CONCURRENTLY)`     # DROP INDEX sin CONCURRENTLY
- `ALGORITHM\s*=\s*INPLACE,\s*LOCK\s*=\s*NONE`     # MySQL online DDL
- `pt-online-schema-change|gh-ost`     # tools de cambios online (MySQL)
**Señal de N/A:** no hay BD en el stack o todas las tablas son pequeñas (<100k rows) donde un lock breve es aceptable.

**Verificar:**
- [ ] `CREATE INDEX CONCURRENTLY` en PostgreSQL.
- [ ] `ALGORITHM=INPLACE, LOCK=NONE` en MySQL cuando aplique.
- [ ] Se mide el tiempo en staging antes de aplicar en prod.

---

## C. Transacciones

#### `DB-TXN-001` — Transacciones cortas
**Severidad:** high · **Aplica a:** backend

Las transacciones solo contienen operaciones necesarias.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `(BEGIN|startTransaction|begin\(\)|@Transactional|transaction\.atomic)`     # apertura de transacción
- `transaction\s*\([^)]*\)[\s\S]{0,2000}\bawait\s+(fetch|axios|http)`     # llamadas HTTP dentro de transacción (anti-patrón)
- `transaction\s*\([^)]*\)[\s\S]{2000,}commit`     # transacciones largas (>2000 chars)
- `@Transactional[\s\S]{0,500}@(Async|Scheduled)`     # transacción cruzando boundaries async (revisar)
**Señal de N/A:** no hay BD en el stack o la app no usa transacciones explícitas (auto-commit por write).

(Ver `PERF-DB-020`.)

---

#### `DB-TXN-002` — Nivel de aislamiento documentado
**Severidad:** medium · **Aplica a:** data

Se elige y documenta el nivel apropiado; se manejan errores de serialización
cuando se usa SERIALIZABLE.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/config/**`, `**/*.{sql,ts,js,py,go,java,cs}`
**Patrones:**
- `SET\s+TRANSACTION\s+ISOLATION\s+LEVEL`     # isolation level explícito
- `(READ\s+COMMITTED|REPEATABLE\s+READ|SERIALIZABLE|READ\s+UNCOMMITTED)`     # niveles
- `IsolationLevel\.\w+|isolation:\s*['"]\w+`     # ORM API de isolation
- `(serialization_failure|40001|SQLSTATE\s+40001|deadlock_detected)`     # manejo de errores de serialización
**Señal de N/A:** no hay BD en el stack o no hay transacciones con concurrencia relevante (single-writer batch).

(Ver `PERF-DB-021`.)

---

#### `DB-TXN-003` — Locking y deadlocks manejados
**Severidad:** high · **Aplica a:** backend · data

Se entienden los locks que toma cada operación y se previenen deadlocks.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/*.{sql,ts,js,py,go,java,cs}`
**Patrones:**
- `SELECT[\s\S]{0,500}FOR\s+UPDATE`     # locks pesimistas
- `FOR\s+(SHARE|NO\s+KEY\s+UPDATE|KEY\s+SHARE)`     # variantes de lock
- `LOCK\s+TABLE`     # lock de tabla completa
- `pg_advisory_lock|GET_LOCK|sp_getapplock`     # advisory locks
- `(deadlock|40P01|ER_LOCK_DEADLOCK)`     # manejo de deadlock errors
- `ORDER\s+BY\s+id\s+FOR\s+UPDATE`     # ordering consistente para evitar deadlocks
**Señal de N/A:** no hay BD en el stack o no hay operaciones concurrentes que tomen locks explícitos.

**Verificar:**
- [ ] Order consistente al bloquear múltiples filas/tablas.
- [ ] `SELECT ... FOR UPDATE` usado deliberadamente, no por reflejo.
- [ ] Deadlock detection monitoreado (métrica).
- [ ] Retries con backoff en errores de serialización.

---

#### `DB-TXN-004` — Rollback correcto en excepciones
**Severidad:** high · **Aplica a:** backend

Si una transacción falla, se hace rollback explícito; no se deja la conexión
en estado zombie.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `try\s*\{[\s\S]{0,2000}commit[\s\S]{0,500}\}\s*catch[\s\S]{0,500}rollback`     # try/commit/catch/rollback
- `with\s+\w+\.(begin|atomic)\(\)\s*as`     # context manager (Python)
- `transaction\s*\(\s*async`     # callback-style transactions (auto-rollback)
- `connection\.(release|close|end)\s*\(`     # devolución al pool
- `BEGIN\b[\s\S]{0,2000}\bCOMMIT\b(?![\s\S]{0,500}\bROLLBACK\b)`     # BEGIN/COMMIT sin ROLLBACK en path de error
**Señal de N/A:** no hay BD en el stack o la app no usa transacciones explícitas.

**Verificar:**
- [ ] Context manager / `try/except/finally` garantiza rollback.
- [ ] Las conexiones se devuelven al pool limpias.

---

## D. Concurrencia de datos

#### `DB-CONC-001` — Concurrencia optimista por default
**Severidad:** medium · **Aplica a:** backend

Para recursos con probabilidad de conflict bajo, usar version/ETag + check en
update.

**Dónde buscar:** `**/entities/**`, `**/services/**`, `**/repositories/**`, `**/*.{sql,ts,js,py,go,java,cs}`
**Patrones:**
- `@VersionColumn|@Version`     # decorador de versionado (TypeORM/JPA)
- `(version|etag|row_version|rowVersion)\s+(INT|BIGINT|UUID)`     # columna de versión
- `UPDATE\s+\w+\s+SET[\s\S]{0,200}WHERE\s+\w+\s*=\s*\?\s+AND\s+version\s*=`     # check de versión en UPDATE
- `If-Match|If-Unmodified-Since|ETag`     # uso a nivel HTTP
**Señal de N/A:** no hay BD en el stack o no hay flujos con concurrencia de escritura sobre el mismo recurso (writer único).

(Ver `API-IDEM-003`.)

---

#### `DB-CONC-002` — Locks pesimistas justificados
**Severidad:** medium · **Aplica a:** backend

`SELECT FOR UPDATE` y similares se usan solo cuando el costo del conflicto lo
justifica.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/*.{sql,ts,js,py,go,java,cs}`
**Patrones:**
- `SELECT[\s\S]{0,500}FOR\s+UPDATE`     # locks pesimistas (revisar justificación)
- `FOR\s+UPDATE\s+(SKIP\s+LOCKED|NOWAIT)`     # variantes con timeout / skip
- `pessimisticLock|@Lock\s*\(\s*LockModeType\.PESSIMISTIC`     # locks pesimistas vía ORM
- `LOCK\s+TABLE`     # lock de tabla (uso justificado solo en raros casos)
**Señal de N/A:** no hay BD en el stack o el código no usa locks pesimistas (todo concurrencia optimista o single-writer).

---

## E. Integridad y validación en BD

#### `DB-INT-001` — FKs con acciones explícitas
**Severidad:** high · **Aplica a:** data

Cada FK declara qué pasa al borrar/actualizar la referenciada.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/*.{sql,prisma}`, `**/*.entity.{ts,js}`, `**/schema.prisma`
**Patrones:**
- `FOREIGN\s+KEY[\s\S]{0,200}REFERENCES\s+\w+(?!\s*[\(\w]*\s*ON\s+DELETE)`     # FK sin ON DELETE
- `FOREIGN\s+KEY[\s\S]{0,500}ON\s+DELETE\s+(CASCADE|SET\s+NULL|RESTRICT|NO\s+ACTION)`     # política explícita
- `@JoinColumn\s*\(\s*\{[^}]*onDelete:\s*['"]`     # TypeORM onDelete
- `onDelete:\s*(Cascade|SetNull|Restrict|NoAction)`     # Prisma onDelete
- `ON\s+UPDATE\s+(CASCADE|SET\s+NULL|RESTRICT)`     # ON UPDATE explícito
**Señal de N/A:** no hay BD en el stack o el schema no tiene relaciones (tablas independientes).

**Verificar:**
- [ ] `ON DELETE CASCADE`, `SET NULL`, `RESTRICT` — cada uno intencional.
- [ ] Cascades peligrosos documentados.
- [ ] No hay cascades implícitas no deseadas.

---

#### `DB-INT-002` — Triggers documentados y minimizados
**Severidad:** medium · **Aplica a:** data

Los triggers ocultan lógica; si se usan, están bien documentados.

**Dónde buscar:** `**/migrations/**`, `**/db/**`, `**/*.{sql}`
**Patrones:**
- `CREATE\s+(OR\s+REPLACE\s+)?TRIGGER`     # definición de trigger
- `CREATE\s+(OR\s+REPLACE\s+)?FUNCTION[\s\S]{0,200}LANGUAGE\s+plpgsql`     # funciones plpgsql para triggers
- `BEFORE\s+(INSERT|UPDATE|DELETE)|AFTER\s+(INSERT|UPDATE|DELETE)`     # hooks
- `RETURN\s+NEW|RETURN\s+OLD`     # cuerpos típicos de trigger
**Señal de N/A:** no hay BD en el stack o el schema no usa triggers (toda la lógica vive en la app).

**Verificar:**
- [ ] Lista de triggers por tabla.
- [ ] Lógica de triggers mantenida en el repo (migrations).
- [ ] Preferir lógica en la aplicación salvo casos justificados (auditoría, integridad).

---

## F. Backups y recuperación

#### `DB-BK-001` — Backups automáticos testeados
**Severidad:** critical · **Aplica a:** data · infra

**Dónde buscar:** `**/infra/**`, `**/terraform/**`, `**/k8s/**`, `**/scripts/**`, `**/*.{tf,yaml,yml,sh}`
**Patrones:**
- `(pg_dump|mysqldump|mongodump|pg_basebackup)`     # comandos de backup
- `backup_retention_period|backup_window|automated_backups`     # config cloud (RDS/etc.)
- `velero|stash|barman|wal-g|wal-e|pgbackrest`     # tools de backup
- `aws\s+s3\s+(cp|sync).*backup|gsutil\s+cp.*backup`     # backups a object storage
**Señal de N/A:** no hay BD en el stack (sin storage persistente que respaldar).

(Ver `CICD-BK-001`.)

---

#### `DB-BK-002` — PITR cuando el dominio lo requiere
**Severidad:** high · **Aplica a:** data

Point-in-time recovery disponible para productos donde perder horas de datos
no es aceptable.

**Dónde buscar:** `**/infra/**`, `**/terraform/**`, `**/config/**`, `**/*.{tf,yaml,yml,conf}`, `postgresql.conf`
**Patrones:**
- `wal_level\s*=\s*(replica|logical)|archive_mode\s*=\s*on|archive_command`     # WAL archiving (Postgres)
- `log[_-]?bin\s*=|binlog_format`     # binlog (MySQL)
- `point[_-]?in[_-]?time[_-]?(recovery|restore)|pitr`     # config PITR
- `wal-g|wal-e|pgbackrest|barman`     # tools de WAL archiving
- `oplog`     # MongoDB oplog
**Señal de N/A:** no hay BD en el stack o el RPO tolerable es de horas/días (productos donde no aplica PITR).

**Verificar:**
- [ ] WAL/binlog archivado.
- [ ] RPO de minutos soportado.
- [ ] Probado periódicamente.

---

## G. Seguridad en capa de datos

#### `DB-SEC-001` — Credenciales de la app con mínimo privilegio
**Severidad:** high · **Aplica a:** data

El usuario de BD que usa la app solo puede hacer lo necesario.

(Ver `SEC-AUTHZ-021`.)

**Dónde buscar:** `**/migrations/**`, `**/db/**`, `**/config/**`, `**/scripts/**`, `**/.env*`, `**/*.{sql,tf,yaml,yml}`
**Patrones:**
- `DATABASE_URL.*://(root|postgres|admin|sa)[:@]`     # uso de root/admin como user de la app
- `GRANT\s+ALL\s+(PRIVILEGES\s+)?ON`     # GRANT ALL en lugar de privilegios mínimos
- `GRANT\s+(SELECT|INSERT|UPDATE|DELETE)\s+ON`     # privilegios granulares (señal positiva)
- `CREATE\s+ROLE|CREATE\s+USER`     # roles separados para app vs migration vs admin
- `superuser\s*=\s*true|SUPERUSER`     # superuser asignado a la app (anti-patrón)
**Señal de N/A:** no hay BD en el stack o es BD embebida (SQLite local) sin modelo de usuarios.

**Verificar:**
- [ ] No se usan credenciales root/admin para la app.
- [ ] Permisos DDL separados del runtime.
- [ ] Scripts de migration corren con credenciales distintas.

---

#### `DB-SEC-002` — Row-Level Security / tenant isolation cuando aplica
**Severidad:** high · **Aplica a:** data

Si la BD soporta RLS, puede reforzar aislamiento entre tenants como defensa en
profundidad.

**Dónde buscar:** `**/migrations/**`, `**/db/**`, `**/middlewares/**`, `**/services/**`, `**/*.{sql,ts,js,py,go,java,cs}`
**Patrones:**
- `ALTER\s+TABLE\s+\w+\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY`     # RLS habilitada
- `CREATE\s+POLICY`     # políticas RLS
- `current_setting\s*\(\s*['"]app\.tenant`     # propagación de tenant via setting
- `SET\s+(LOCAL\s+)?app\.\w+`     # set de variable de sesión por request
- `tenant_?[Ii]d`     # presencia de tenant_id (precondición de RLS)
**Señal de N/A:** la app es single-tenant o usa otra estrategia de aislamiento (DB por tenant / schema por tenant) donde RLS no aplica.

**Verificar:**
- [ ] Policies de RLS activas en tablas multi-tenant (si la estrategia lo requiere).
- [ ] Setting de `current_tenant` propagado desde la app.
- [ ] Tests que intentan cross-tenant fallan.

---

## Checklist resumen

| ID             | Control                                             | Severidad |
| -------------- | --------------------------------------------------- | --------- |
| DB-QRY-001     | SELECT acotado                                      | medium    |
| DB-QRY-002     | N+1 evitado                                         | high      |
| DB-QRY-003     | LIMIT en listados                                   | high      |
| DB-QRY-004     | Batching de escrituras                              | medium    |
| DB-QRY-005     | Queries lentas auditadas                            | high      |
| DB-IDX-001     | Índices para filtros/FKs                            | high      |
| DB-IDX-002     | Compuestos en orden correcto                        | medium    |
| DB-IDX-003     | Tipos de índice apropiados                          | medium    |
| DB-IDX-004     | No usados eliminados                                | medium    |
| DB-IDX-005     | Cambios de índice seguros                           | medium    |
| DB-TXN-001     | Transacciones cortas                                | high      |
| DB-TXN-002     | Isolation level documentado                         | medium    |
| DB-TXN-003     | Locks y deadlocks manejados                         | high      |
| DB-TXN-004     | Rollback en excepciones                             | high      |
| DB-CONC-001    | Concurrencia optimista                              | medium    |
| DB-CONC-002    | Locks pesimistas justificados                       | medium    |
| DB-INT-001     | FKs con acciones explícitas                         | high      |
| DB-INT-002     | Triggers documentados                               | medium    |
| DB-BK-001      | Backups testeados (→ CICD)                          | critical  |
| DB-BK-002      | PITR cuando corresponde                             | high      |
| DB-SEC-001     | Mínimo privilegio en credenciales                   | high      |
| DB-SEC-002     | RLS / tenant isolation                              | high      |
