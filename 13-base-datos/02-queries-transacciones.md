# 13 · Base de datos · Queries, índices y transacciones

> Consultas eficientes, uso de índices, concurrencia, transacciones, backups.

---

## A. Queries eficientes

#### `DB-QRY-001` — SELECT acotado a campos necesarios
**Severidad:** medium · **Aplica a:** backend · data

Se evita `SELECT *` en queries de alta frecuencia sobre tablas con columnas
grandes.

(Ver `PERF-DB-002`.)

---

#### `DB-QRY-002` — N+1 evitado con eager loading apropiado
**Severidad:** high · **Aplica a:** backend

Relaciones que se usan juntas se cargan juntas.

(Ver `PERF-DB-003`.)

---

#### `DB-QRY-003` — LIMIT obligatorio en listados
**Severidad:** high · **Aplica a:** backend · api

Ningún handler productivo hace `SELECT ... FROM table` sin LIMIT.

(Ver `API-PAGE-001`, `PERF-BE-051`.)

---

#### `DB-QRY-004` — Batching de escrituras
**Severidad:** medium · **Aplica a:** backend

Inserts/updates masivos se agrupan.

(Ver `PERF-DB-004`.)

---

#### `DB-QRY-005` — Queries lentas auditadas
**Severidad:** high · **Aplica a:** data

Se identifica y corrige queries lentas periódicamente.

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

(Ver `PERF-DB-010`.)

---

#### `DB-IDX-002` — Índices compuestos en orden correcto
**Severidad:** medium · **Aplica a:** data

Los índices multi-columna siguen el orden por cardinalidad y uso.

**Verificar:**
- [ ] Columnas en el orden que usan las queries.
- [ ] Índices cubren queries frecuentes ("covering index") cuando aporta.
- [ ] Se evalúa reemplazar varios índices uni-columna por uno compuesto cuando aplica.

---

#### `DB-IDX-003` — Tipos de índice apropiados
**Severidad:** medium · **Aplica a:** data

B-tree no siempre es la mejor opción.

**Verificar:**
- [ ] GIN/GiST para full-text (tsvector).
- [ ] Trigram (`pg_trgm`) o equivalente para búsquedas LIKE.
- [ ] Vectorial (pgvector, Pinecone, etc.) para embeddings.
- [ ] Hash / partial index en casos específicos.

---

#### `DB-IDX-004` — Índices no usados eliminados
**Severidad:** medium · **Aplica a:** data

Índices ocupan espacio y ralentizan escrituras. Se remueven los inútiles.

(Ver `PERF-DB-011`.)

---

#### `DB-IDX-005` — Cambios de índice seguros
**Severidad:** medium · **Aplica a:** data

Crear/eliminar índices en tablas grandes se hace sin bloquear lecturas.

**Verificar:**
- [ ] `CREATE INDEX CONCURRENTLY` en PostgreSQL.
- [ ] `ALGORITHM=INPLACE, LOCK=NONE` en MySQL cuando aplique.
- [ ] Se mide el tiempo en staging antes de aplicar en prod.

---

## C. Transacciones

#### `DB-TXN-001` — Transacciones cortas
**Severidad:** high · **Aplica a:** backend

Las transacciones solo contienen operaciones necesarias.

(Ver `PERF-DB-020`.)

---

#### `DB-TXN-002` — Nivel de aislamiento documentado
**Severidad:** medium · **Aplica a:** data

Se elige y documenta el nivel apropiado; se manejan errores de serialización
cuando se usa SERIALIZABLE.

(Ver `PERF-DB-021`.)

---

#### `DB-TXN-003` — Locking y deadlocks manejados
**Severidad:** high · **Aplica a:** backend · data

Se entienden los locks que toma cada operación y se previenen deadlocks.

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

**Verificar:**
- [ ] Context manager / `try/except/finally` garantiza rollback.
- [ ] Las conexiones se devuelven al pool limpias.

---

## D. Concurrencia de datos

#### `DB-CONC-001` — Concurrencia optimista por default
**Severidad:** medium · **Aplica a:** backend

Para recursos con probabilidad de conflict bajo, usar version/ETag + check en
update.

(Ver `API-IDEM-003`.)

---

#### `DB-CONC-002` — Locks pesimistas justificados
**Severidad:** medium · **Aplica a:** backend

`SELECT FOR UPDATE` y similares se usan solo cuando el costo del conflicto lo
justifica.

---

## E. Integridad y validación en BD

#### `DB-INT-001` — FKs con acciones explícitas
**Severidad:** high · **Aplica a:** data

Cada FK declara qué pasa al borrar/actualizar la referenciada.

**Verificar:**
- [ ] `ON DELETE CASCADE`, `SET NULL`, `RESTRICT` — cada uno intencional.
- [ ] Cascades peligrosos documentados.
- [ ] No hay cascades implícitas no deseadas.

---

#### `DB-INT-002` — Triggers documentados y minimizados
**Severidad:** medium · **Aplica a:** data

Los triggers ocultan lógica; si se usan, están bien documentados.

**Verificar:**
- [ ] Lista de triggers por tabla.
- [ ] Lógica de triggers mantenida en el repo (migrations).
- [ ] Preferir lógica en la aplicación salvo casos justificados (auditoría, integridad).

---

## F. Backups y recuperación

#### `DB-BK-001` — Backups automáticos testeados
**Severidad:** critical · **Aplica a:** data · infra

(Ver `CICD-BK-001`.)

---

#### `DB-BK-002` — PITR cuando el dominio lo requiere
**Severidad:** high · **Aplica a:** data

Point-in-time recovery disponible para productos donde perder horas de datos
no es aceptable.

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

**Verificar:**
- [ ] No se usan credenciales root/admin para la app.
- [ ] Permisos DDL separados del runtime.
- [ ] Scripts de migration corren con credenciales distintas.

---

#### `DB-SEC-002` — Row-Level Security / tenant isolation cuando aplica
**Severidad:** high · **Aplica a:** data

Si la BD soporta RLS, puede reforzar aislamiento entre tenants como defensa en
profundidad.

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
