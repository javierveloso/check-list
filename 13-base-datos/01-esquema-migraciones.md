# 13 · Base de datos · Esquema y migraciones

> Diseño de schema, constraints, integridad referencial, migraciones seguras.

---

## A. Diseño del schema

#### `DB-SCHEMA-001` — Nombres consistentes y autodescriptivos
**Severidad:** low · **Aplica a:** data

Las tablas y columnas siguen una convención estable.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/models/**`, `**/*.{sql,prisma}`, `**/*.entity.{ts,js}`, `**/schema.prisma`
**Patrones:**
- `CREATE\s+TABLE\s+["`]?[A-Z]\w*[A-Z]`     # tablas con CamelCase / PascalCase mezclado
- `(\b\w+_\w+\b).*\b([a-z]+[A-Z]\w*)\b`     # mismo archivo mezclando snake_case y camelCase
- `@Column\s*\(\s*\{\s*name:\s*['"]`     # columnas con nombre explícito (revisar consistencia)
- `CONSTRAINT\s+\w+\s+(FOREIGN\s+KEY|CHECK|UNIQUE)`     # constraints con nombre explícito
- `FOREIGN\s+KEY\s*\([^)]+\)\s+REFERENCES`     # FKs (verificar naming `<tabla>_id`)
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] Convención de casing (snake_case típicamente) aplicada a tablas y columnas.
- [ ] Tablas en plural (o singular) consistente.
- [ ] Columnas claras: `created_at`, `updated_at`, `deleted_at` estándar.
- [ ] Foreign keys con nombre predecible: `order_id`, `user_id`.
- [ ] Constraints con nombre explícito (`fk_order_user`, `chk_order_status`).

---

#### `DB-SCHEMA-002` — Tipos correctos por columna
**Severidad:** high · **Aplica a:** data

Cada columna tiene el tipo que refleja su dominio.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/models/**`, `**/*.{sql,prisma}`, `**/*.entity.{ts,js}`, `**/schema.prisma`
**Patrones:**
- `\b(FLOAT|REAL|DOUBLE)\b`     # tipos float (peligroso para dinero)
- `(price|amount|balance|total|cost)\s*\w*\s+(FLOAT|REAL|DOUBLE|float|number)`     # dinero como float
- `TIMESTAMP(?!\s+WITH\s+TIME\s+ZONE)`     # timestamp sin TZ
- `VARCHAR\s*\(\s*255\s*\)`     # VARCHAR(255) por defecto
- `CHAR\s*\(\s*1\s*\)|TINYINT\s*\(\s*1\s*\)`     # boolean simulado
- `@Column\s*\(\s*\{\s*type:\s*['"]float['"]`     # ORM declarando float
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] Strings con longitudes acotadas cuando aplica (`VARCHAR(n)` vs `TEXT`).
- [ ] Fechas y timestamps con timezone (`TIMESTAMP WITH TIME ZONE`).
- [ ] Dinero como `DECIMAL(n, m)` o entero en subunidad; nunca FLOAT.
- [ ] Enums nativos cuando los soporta el motor, o tabla lookup.
- [ ] UUID como `uuid` nativo cuando esté disponible.
- [ ] Booleanos como `BOOLEAN`, no `INT(1)` ni `CHAR(1)`.

**Banderas rojas:**
- Precios/balances como `FLOAT`.
- Timestamps sin TZ que se asumen UTC "de palabra".
- `VARCHAR(255)` universal.

---

#### `DB-SCHEMA-003` — Constraints obligatorios declarados
**Severidad:** high · **Aplica a:** data

Constraints de unicidad, obligatoriedad, rango, foreign keys viven en la BD,
no solo en la aplicación.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/models/**`, `**/*.{sql,prisma}`, `**/*.entity.{ts,js}`, `**/schema.prisma`
**Patrones:**
- `CREATE\s+TABLE[\s\S]{0,2000}\)\s*;`     # tabla completa (revisar NOT NULL/UNIQUE)
- `\b\w+_id\s+\w+(?!\s+REFERENCES)`     # columna *_id sin REFERENCES (FK ausente)
- `email\s+\w+(?!.*UNIQUE)`     # email sin UNIQUE
- `CHECK\s*\(`     # CHECK constraints (presencia)
- `@Column\s*\(\s*\{[^}]*nullable:\s*true`     # nullable explícito (revisar si corresponde)
- `@Unique|UNIQUE\s*\(`     # unicidad declarada
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] `NOT NULL` donde corresponde.
- [ ] `UNIQUE` en campos de identidad (email, username, slug).
- [ ] `FOREIGN KEY` para relaciones (con política de cascade/restrict explícita).
- [ ] `CHECK` para invariantes simples (status ∈ enum, amount ≥ 0).

**Banderas rojas:**
- Aplicación "valida que sea único", BD permite duplicados por race condition.
- FKs ausentes en relaciones evidentes.

---

#### `DB-SCHEMA-004` — Normalización adecuada al caso
**Severidad:** medium · **Aplica a:** data

El schema está razonablemente normalizado; la desnormalización, cuando se
hace, es consciente.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/models/**`, `**/*.{sql,prisma}`, `**/*.entity.{ts,js}`, `**/schema.prisma`
**Patrones:**
- `\b(country|state|city|currency|language)\s+VARCHAR`     # datos de catálogo como string libre (deberían ser FK)
- `\w+_(json|jsonb|data)\s+(JSON|JSONB)`     # JSON blobs (revisar si oculta normalización)
- `(addr|address)_(street|city|zip|country)\s+\w+,[\s\S]{0,500}(addr|address)_(street|city|zip|country)`     # bloques repetidos en múltiples tablas
- `enum\s*\(['"]\w+['"]`     # enums hardcodeados (vs tabla lookup)
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] No hay campos repetidos sin razón.
- [ ] Datos "enlatados" (dirección del país) viven en catálogos.
- [ ] Desnormalizaciones documentadas (denormalización por performance).
- [ ] Campos redundantes tienen mecanismo de actualización (trigger, app).

---

#### `DB-SCHEMA-005` — Columnas de auditoría
**Severidad:** medium · **Aplica a:** data

Las tablas relevantes tienen `created_at`, `updated_at`, y cuando el dominio lo
exige, `created_by`/`updated_by`.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/models/**`, `**/*.{sql,prisma}`, `**/*.entity.{ts,js}`, `**/schema.prisma`
**Patrones:**
- `created_at|createdAt|@CreateDateColumn`     # presencia de created_at
- `updated_at|updatedAt|@UpdateDateColumn`     # presencia de updated_at
- `deleted_at|deletedAt|@DeleteDateColumn`     # soft-delete
- `created_by|updated_by|createdBy|updatedBy`     # auditoría de usuario
- `CREATE\s+TABLE\s+\w+[\s\S]{0,2000}\)\s*;`     # cada tabla (verificar columnas de auditoría)
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] `created_at` nunca cambia.
- [ ] `updated_at` se actualiza en cada modificación (trigger o ORM).
- [ ] Soft-delete (`deleted_at`) cuando el dominio requiere histórico.
- [ ] Tabla de audit log separada si es necesario (immutable).

---

## B. Soft delete vs hard delete

#### `DB-SCHEMA-010` — Política de borrado definida
**Severidad:** medium · **Aplica a:** data

Por tabla se decide: hard delete, soft delete + TTL, o solo anonimización.

**Dónde buscar:** `**/migrations/**`, `**/entities/**`, `**/repositories/**`, `**/services/**`, `**/*.{sql,prisma,ts,js,py,go,java,cs}`
**Patrones:**
- `deleted_at|deletedAt|is_deleted|isDeleted`     # campos de soft-delete
- `@DeleteDateColumn|paranoid:\s*true`     # ORM con soft-delete
- `\bDELETE\s+FROM\b`     # hard deletes (revisar política)
- `(anonymize|anonymise|scrub|redact)`     # anonimización
- `\.where\(\s*\{[^}]*deleted`     # filtrado explícito de soft-deletes
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] Decisión documentada por tipo de dato.
- [ ] Soft-deletes se filtran por defecto en queries.
- [ ] Cascadas lógicas (soft delete de usuario → soft delete de sus cosas) manejadas.
- [ ] Jobs que materializan el borrado definitivo (ver `DATA-RET-002`).

---

## C. Migraciones

#### `DB-MIG-001` — Migraciones versionadas en el repo
**Severidad:** high · **Aplica a:** data · ci-cd

Cada cambio de schema es una migración commiteada y aplicada automáticamente.

**Dónde buscar:** `**/migrations/**`, `**/db/**`, `**/database/**`, `**/*.{sql,prisma}`, `**/package.json`, `**/alembic.ini`, `**/flyway.conf`
**Patrones:**
- `(typeorm|prisma|sequelize|mongoose|alembic|flyway|liquibase|knex|diesel|goose)`     # herramienta de migration en deps
- `^\d{4,14}[_-]\w+\.(sql|ts|js|py)$`     # naming determinista (timestamp_descripcion)
- `migration:run|migrate\s+up|alembic\s+upgrade|flyway\s+migrate`     # comando de aplicación de migraciones
- `\b(schema\.prisma|migrations/)\b`     # carpetas/archivos de migration esperados
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] Herramienta de migration (Alembic, Flyway, Liquibase, Prisma Migrate, Diesel, etc.).
- [ ] Orden determinista (timestamp o secuencial).
- [ ] Nombres descriptivos.
- [ ] Aplicadas en dev/staging/prod del mismo modo.

**Banderas rojas:**
- Cambios de schema hechos por DDL manual sin migración.
- Migraciones editadas retroactivamente.

---

#### `DB-SYNC-001` — ORM auto-sync / DDL automático deshabilitado en producción
**Severidad:** critical · **Tags:** `data-loss`, `downtime` · **Aplica a:** backend · data

La sincronización automática de schema por el ORM (`synchronize: true` en TypeORM,
`db.create_all()` sin guard en SQLAlchemy, `autoMigrate` en MikroORM) está
**deshabilitada** en producción. Solo se aplican cambios a través de migraciones
revisadas y controladas.

**Dónde buscar:** `**/config/**`, `**/data-source*`, `**/ormconfig*`, `**/*.{ts,js,py,yaml,yml,json}`, `**/schema.prisma`
**Patrones:**
- `synchronize\s*:\s*true`     # TypeORM synchronize en true
- `synchronize\s*:\s*process\.env\.NODE_ENV\s*!==\s*['"]production['"]`     # peligroso si NODE_ENV no se setea
- `db\.create_all\(\)|Base\.metadata\.create_all\(`     # SQLAlchemy create_all sin guard
- `autoMigrate|migrationsAutoRun|alter\s*:\s*true`     # MikroORM/Sequelize auto-sync
- `force\s*:\s*true`     # Sequelize force (DROP+CREATE)
- `db\.AutoMigrate\(`     # GORM AutoMigrate
**Señal de N/A:** no hay ORM en el stack (sin `typeorm|prisma|sequelize|mongoose|sqlalchemy|mikroorm|gorm|hibernate` en deps).

**Verificar:**
- [ ] La opción de auto-sync está explícitamente en `false` (o ausente) en la configuración de producción.
- [ ] Existe una carpeta de migraciones con historial completo desde el estado inicial del schema.
- [ ] El proceso de deploy corre las migraciones **antes** de levantar la app, no durante el arranque del ORM.
- [ ] La variable de entorno de producción no permite sobreescribir `synchronize` a `true` por error.
- [ ] Los entornos de dev/test pueden usar auto-sync, pero está gateado por `NODE_ENV` o equivalente.

**Banderas rojas:**
- `synchronize: true` en el `DataSource` / engine de producción (TypeORM, Sequelize, MikroORM).
- `db.create_all()` o `Base.metadata.create_all()` en el entrypoint de producción sin guard.
- Carpeta `migrations/` vacía o inexistente junto a entidades ORM activas.
- `synchronize: process.env.NODE_ENV !== 'production'` — si `NODE_ENV` no está seteado en prod, se activa auto-sync silenciosamente.
- Deploy que no incluye ningún paso de `migration:run` antes del `start`.

**Ejemplo de hallazgo:**
```yaml
control_id: DB-SYNC-001
severity: critical
file: src/config/data-source.ts
line: 8
evidence: |
  export const AppDataSource = new DataSource({
    type: 'postgres',
    synchronize: true,   // ← activo en producción
    entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  })
  # No existe src/migrations/ ni script de migration:run
explanation: |
  TypeORM con synchronize:true aplica ALTER TABLE automáticamente en cada
  arranque. Un deploy con una entidad mal definida puede borrar columnas con
  datos productivos sin rollback posible. La ausencia de migraciones impide
  revisar los cambios de schema en code review.
suggestion: |
  1. Cambiar synchronize: false inmediatamente.
  2. Generar la migración inicial del estado actual:
       typeorm migration:generate -d src/config/data-source.ts src/migrations/InitialSchema
  3. Añadir en package.json:
       "migration:run": "typeorm-ts-node-commonjs migration:run -d src/config/data-source.ts"
  4. En el deploy, ejecutar migration:run antes de node dist/main.js.
```

**Referencias:** TypeORM docs — "synchronize warning in production" · Sequelize migrations guide · MikroORM migrations.

---

#### `DB-MIG-002` — Migraciones seguras (expand/contract)
**Severidad:** critical · **Aplica a:** data

Los cambios incompatibles se hacen en pasos que permiten coexistencia de N y
N+1.

**Dónde buscar:** `**/migrations/**`, `**/db/**`, `**/*.{sql,ts,js,py}`
**Patrones:**
- `DROP\s+(COLUMN|TABLE)`     # drops directos (deberían ir en release posterior)
- `ALTER\s+TABLE\s+\w+\s+RENAME\s+(COLUMN\s+)?\w+\s+TO`     # rename directo (anti-patrón)
- `ALTER\s+(TABLE\s+\w+\s+)?ALTER\s+COLUMN\s+\w+\s+TYPE`     # cambio de tipo directo
- `ADD\s+COLUMN\s+\w+\s+\w+\s+NOT\s+NULL(?!\s+DEFAULT)`     # NOT NULL sin default ni backfill
- `DROP\s+CONSTRAINT`     # drop constraint (validar coexistencia)
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] Añadir columna: nullable o con default; backfill asíncrono si aplica.
- [ ] Rename: crear nueva, duplicar writes, migrar reads, eliminar la antigua (al menos 2 releases).
- [ ] Drop column: primero stop using en código, siguiente release drop.
- [ ] Drop table: igual, en pasos.
- [ ] Cambio de tipo: columna paralela si es necesario.

---

#### `DB-MIG-003` — Migraciones idempotentes / chequeadas
**Severidad:** high · **Aplica a:** data

Las migraciones manejan correctamente re-ejecutar y casos previos ambiguos.

**Dónde buscar:** `**/migrations/**`, `**/db/**`, `**/*.{sql,ts,js,py}`
**Patrones:**
- `IF\s+NOT\s+EXISTS|IF\s+EXISTS`     # checks de idempotencia
- `CREATE\s+TABLE\s+(?!IF\s+NOT\s+EXISTS)`     # CREATE TABLE sin guard
- `DROP\s+(TABLE|COLUMN|INDEX)\s+(?!IF\s+EXISTS)`     # DROP sin guard
- `ALTER\s+TABLE\s+\w+\s+ADD\s+COLUMN\s+(?!IF\s+NOT\s+EXISTS)`     # ADD COLUMN sin guard
- `BEGIN\b[\s\S]{0,5000}\bCOMMIT\b`     # uso de transacción explícita
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS` donde aplica.
- [ ] Comprobaciones antes de drop/alter para evitar fallos ambiguos.
- [ ] La migración no deja la BD en estado parcial si falla a mitad.

---

#### `DB-MIG-004` — Migraciones revisadas con ojo crítico
**Severidad:** high · **Aplica a:** process

Migraciones = cambios con potencial destructivo. Requieren review específico.

**Dónde buscar:** `**/migrations/**`, `**/.github/CODEOWNERS`, `**/.github/workflows/**`, `**/docs/**`
**Patrones:**
- `migrations/\s+@\w+`     # CODEOWNERS apunta a reviewers de migraciones
- `(DROP|TRUNCATE|DELETE\s+FROM|ALTER\s+TABLE)`     # operaciones potencialmente destructivas a revisar
- `EXPLAIN(\s+ANALYZE)?`     # EXPLAIN documentado en migration
- `dry[_-]?run|--dry-run`     # dry-run en CI/staging
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] Reviewer con contexto de datos (no solo código).
- [ ] PRs con migraciones destacadas para revisión.
- [ ] Dry-run en staging antes de producción.
- [ ] EXPLAIN de operaciones largas (ALTER en tablas grandes).

---

#### `DB-MIG-005` — Backfills en background, no bloqueantes
**Severidad:** high · **Aplica a:** data

Operaciones de `UPDATE` masivo se hacen en batches, fuera de la migración de
schema.

**Dónde buscar:** `**/migrations/**`, `**/scripts/**`, `**/jobs/**`, `**/db/**`, `**/*.{sql,ts,js,py}`
**Patrones:**
- `UPDATE\s+\w+\s+SET\s+[\s\S]{0,200}(?!WHERE)`     # UPDATE sin WHERE (full table scan)
- `UPDATE\s+\w+\s+SET\s+[\s\S]{0,500}\bWHERE\s+(?!.*LIMIT|.*BETWEEN|.*id\s*[<>])`     # UPDATE masivo sin batching
- `\bbatch[_-]?(size|limit)\s*[:=]\s*\d+`     # batch size declarado
- `(progress|checkpoint|resume)`     # backfill resumible
- `pg_sleep\(|sleep\(`     # pausas entre batches
**Señal de N/A:** no hay BD en el stack o no se hacen backfills sobre tablas grandes (volumen pequeño donde un UPDATE único es seguro).

**Verificar:**
- [ ] Backfill script separado, con batching y progreso medible.
- [ ] No bloquea la tabla (ej: updates por PK, con sleep entre batches).
- [ ] Se puede reanudar si se interrumpe.

---

## D. Seeds y fixtures

#### `DB-SEED-001` — Seeds mínimos para desarrollo
**Severidad:** low · **Aplica a:** data · process

Los devs pueden levantar la BD con datos básicos de ejemplo fácilmente.

**Dónde buscar:** `**/seeds/**`, `**/seeders/**`, `**/fixtures/**`, `**/db/**`, `**/scripts/**`, `**/*.{sql,ts,js,py}`, `**/package.json`
**Patrones:**
- `(seed|seeder|fixture)`     # presencia de seeds
- `\b(faker|factory[_-]?bot|factory[_-]?girl|test[_-]?factory)\b`     # generación con fakers
- `INSERT\s+INTO[\s\S]{0,500}ON\s+CONFLICT\s+DO\s+NOTHING`     # seed idempotente
- `(real|prod|production)[_-]?(data|dump)`     # seeds usando datos reales (anti-patrón)
- `email.*@(gmail|hotmail|outlook|yahoo)\.(com|es|cl)`     # emails reales en seeds (PII)
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

**Verificar:**
- [ ] Script de seed documentado.
- [ ] Seeds no reproducen PII real de producción.
- [ ] Idempotentes.

---

## Checklist resumen

| ID              | Control                                           | Severidad |
| --------------- | ------------------------------------------------- | --------- |
| DB-SCHEMA-001   | Nombres consistentes                              | low       |
| DB-SCHEMA-002   | Tipos correctos                                   | high      |
| DB-SCHEMA-003   | Constraints declarados                            | high      |
| DB-SCHEMA-004   | Normalización adecuada                            | medium    |
| DB-SCHEMA-005   | Columnas de auditoría                             | medium    |
| DB-SCHEMA-010   | Política de borrado                               | medium    |
| DB-MIG-001      | Migraciones versionadas                           | high      |
| DB-SYNC-001     | ORM auto-sync deshabilitado en producción         | critical  |
| DB-MIG-002      | Expand/contract                                   | critical  |
| DB-MIG-003      | Idempotentes                                      | high      |
| DB-MIG-004      | Review dedicado                                   | high      |
| DB-MIG-005      | Backfills en background                           | high      |
| DB-SEED-001     | Seeds de desarrollo                               | low       |
