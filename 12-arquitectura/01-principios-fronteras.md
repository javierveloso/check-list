# 12 · Arquitectura · Principios, fronteras y acoplamiento

> Decisiones arquitecturales: capas, bounded contexts, acoplamiento, cohesión,
> contratos entre servicios.
>
> **Marcos de referencia:** Clean Architecture · DDD (Evans) · Hexagonal · Team Topologies · C4 Model.

---

## A. Capas y fronteras

#### `ARCH-LAYER-001` — Capas claras con dependencias unidireccionales
**Severidad:** high · **Aplica a:** backend · frontend

El código se organiza en capas y las dependencias fluyen hacia adentro
(dominio no depende de infra).

**Dónde buscar:** `**/domain/**`, `**/core/**`, `**/services/**`, `**/modules/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `from\s+['"](fastapi|express|django\.db|@nestjs/common|sqlalchemy|typeorm|prisma)`     # imports de infra/framework dentro de domain
- `import.*\b(pg|mysql|mongoose|prisma|redis)\b`     # cliente de BD/infra fuera de la capa adapter
- `process\.env\.`     # acceso directo a env desde domain (debería pasar por config layer)
- `new\s+\w+(Service|Repository|Controller)\(`     # instanciación directa en lugar de DI
- `\.\./\.\./\.\./[^'"]+`     # importaciones cruzadas profundas entre capas
- `@(Controller|RestController)[\s\S]{0,200}@(Inject|Autowired)\s*\(\s*\w*Repository`     # controller llamando repositorio sin pasar por service
**Señal de N/A:** el repo es un script monolítico sin estructura de capas (sin carpetas `domain/`, `services/`, `adapters/`, `core/`).

**Verificar:**
- [ ] Capas definidas (por ejemplo: adapters → use cases → domain).
- [ ] Dominio no importa frameworks HTTP, SQL, ni librerías de infra.
- [ ] Adapters implementan puertos definidos en el dominio.
- [ ] Linter o estructura de carpetas refuerza la regla.

**Banderas rojas:**
- Modelo de dominio importando `fastapi`, `express`, `django.db`.
- Querys SQL en un handler HTTP sin pasar por un repositorio.

---

#### `ARCH-LAYER-002` — Bounded contexts explícitos
**Severidad:** medium · **Aplica a:** backend

Dominios distintos viven en contextos separados; no comparten modelos de BD sin
justificación.

**Dónde buscar:** `**/modules/**`, `**/domain/**`, `**/services/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `class\s+\w+[\s\S]{3000,}\}`     # god-objects que abarcan múltiples dominios
- `from\s+['"]\.\.\/\.\.\/(billing|catalog|auth|user|order|payment)\/`     # módulo importando entidades de otro bounded context
- `import\s+\{[^}]{200,}\}\s+from`     # imports masivos desde un único módulo (señal de god-module)
- `@Entity[\s\S]{0,500}@(ManyToOne|OneToMany)[\s\S]{0,200}(Billing|Catalog|Auth)`     # entidades cruzando contextos sin ACL
**Señal de N/A:** el repo no tiene múltiples dominios de negocio (CRUD simple monocontexto) o es un script monolítico sin estructura modular.

**Verificar:**
- [ ] Cada bounded context (billing, catálogo, auth, etc.) tiene su propio módulo/paquete.
- [ ] No hay "God Models" que sepan de todo el dominio.
- [ ] Mapeos explícitos entre contextos (anti-corruption layer) cuando sea necesario.

---

#### `ARCH-LAYER-003` — Separación lectura/escritura cuando aporta (CQRS ligero)
**Severidad:** low · **Aplica a:** backend

Para casos donde lectura y escritura tienen necesidades muy distintas
(reports, dashboards), se separan los modelos.

**Dónde buscar:** `**/services/**`, `**/queries/**`, `**/commands/**`, `**/read-models/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `(class|function)\s+\w*(Query|Command)Handler`     # handlers separados de query/command
- `interface\s+\w*Read(Model|Repository)`     # read models declarados
- `CREATE\s+(MATERIALIZED\s+)?VIEW`     # views especializadas para reporting
- `@CommandHandler|@QueryHandler`     # decoradores CQRS (NestJS)
**Señal de N/A:** la app no tiene flujos de reporting/dashboard con requisitos distintos al modelo de escritura, o es un CRUD simple sin justificación para CQRS.

**Verificar:**
- [ ] Queries de reporting usan views/read models especializados.
- [ ] Commands y queries tienen interfaces distintas cuando aporta claridad.

---

## B. Acoplamiento y cohesión

#### `ARCH-COUPL-001` — Servicios con contratos estables
**Severidad:** high · **Aplica a:** backend

Entre servicios internos existen contratos bien definidos (schema, OpenAPI,
protobuf) que cambian bajo control.

**Dónde buscar:** `**/architecture/**`, `**/adr/**`, `**/contracts/**`, `**/*.{proto,yaml,json}`, `**/openapi*`, `**/swagger*`
**Patrones:**
- `openapi:\s*['"]?\d`     # spec OpenAPI presente
- `syntax\s*=\s*['"]proto3?['"]`     # contratos protobuf
- `\$ref:\s*['"]https?://`     # contratos compartidos por URL (versionado externo)
- `version:\s*['"]?\d+\.\d+`     # versionado explícito en contratos
**Señal de N/A:** el repo es un servicio único sin comunicación con otros servicios internos (monolito sin SOA/microservicios).

**Verificar:**
- [ ] Cada servicio publica su contrato.
- [ ] Consumidores versiones compatibles.
- [ ] Cambios breaking siguen proceso claro (ver `API-VER-002`).

---

#### `ARCH-COUPL-002` — Dependencias entre servicios minimizadas
**Severidad:** medium · **Aplica a:** backend

Los servicios no se llaman en cascadas largas para servir una request.

**Dónde buscar:** `**/services/**`, `**/clients/**`, `**/*.{ts,js,py,go,java,cs}`, `**/architecture/**`
**Patrones:**
- *(sin patrones mecánicos — revisión humana / arquitectura)*
**Señal de N/A:** el repo es un servicio único sin llamadas a otros servicios internos (monolito o standalone).

**Verificar:**
- [ ] Dependencias graficadas y revisadas regularmente.
- [ ] Request crítica no requiere más de 2-3 hops internos.
- [ ] Se evalúa periódicamente si un módulo debería ser servicio aparte o fusionarse.

---

#### `ARCH-COUPL-003` — Comunicación asíncrona cuando es apropiada
**Severidad:** medium · **Aplica a:** backend

Flujos que no requieren respuesta inmediata usan eventos/colas, reduciendo
acoplamiento temporal.

**Dónde buscar:** `**/services/**`, `**/events/**`, `**/queues/**`, `**/workers/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `\b(emit|publish|dispatch)\s*\(\s*['"][\w.]+(Event|Created|Updated)`     # publicación de eventos
- `@EventPattern|@MessagePattern|@OnEvent`     # decoradores de eventos
- `(bullmq|kafka|rabbitmq|sqs|sns|nats|pubsub|celery|sidekiq)`     # uso de broker/cola
- `await\s+\w+\.(send|sendMail|notify|index)\s*\(`     # side effects síncronos sospechosos (deberían ser eventos)
**Señal de N/A:** la app no tiene side effects relevantes (emails, notifs, indexación) o es un CRUD puramente request/response sin trabajos diferibles.

**Verificar:**
- [ ] Side effects (emails, notifs, indexación) se disparan como eventos.
- [ ] Los consumidores son idempotentes (ver `CODE-EFFECT-002`).
- [ ] Eventos tienen schema versionado.

---

#### `ARCH-COUPL-004` — Shared libraries versionadas y minimal
**Severidad:** medium · **Aplica a:** backend

Las librerías compartidas son pequeñas, estables y versionadas. No son
vehículo para propagar todos los cambios.

**Dónde buscar:** `**/shared/**`, `**/lib/**`, `**/common/**`, `**/packages/**`, `**/utils/**`, `**/package.json`
**Patrones:**
- `"version":\s*"0\.0\.\d+"`     # libs sin versionado real (siempre 0.0.x)
- `"workspace:\*"`     # dependencias workspace sin pinning de versión
- *(además — revisión humana del tamaño/scope de las shared libs)*
**Señal de N/A:** el repo no es un monorepo y no expone librerías compartidas internas (sin carpetas `shared/`, `lib/`, `packages/`).

**Verificar:**
- [ ] Shared code solo para lo verdaderamente común (logging, tracing, auth client).
- [ ] Cambios mayores en shared libs requieren migration plan.
- [ ] Consumidores no están forzados a bumpear al mismo tiempo.

---

## C. Datos

#### `ARCH-DATA-001` — Ownership de datos claro
**Severidad:** high · **Aplica a:** backend · data

Cada pieza de datos tiene un único owner; otros servicios la consultan vía
API o eventos, no tocan directamente la BD del owner.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/entities/**`, `**/*.{ts,js,py,go,java,cs}`, `**/architecture/**`
**Patrones:**
- `DATABASE_URL.*=.*\$\{?(BILLING|AUTH|CATALOG|ORDER)_DB`     # un servicio configurando BD ajena
- `getRepository\(\s*['"]?(\w+)['"]?\s*\)`     # accesos a repositorios cruzados
- *(además — revisión humana del mapa de ownership de tablas)*
**Señal de N/A:** el repo es un servicio único con su propia BD (sin múltiples servicios compartiendo storage) o es un monolito.

**Verificar:**
- [ ] Cada tabla/entidad pertenece a un solo servicio.
- [ ] Servicios no se conectan a BD ajenas.
- [ ] Sincronización entre servicios vía eventos o API.

**Banderas rojas:**
- Dos servicios escribiendo la misma tabla.
- Servicio A leyendo la tabla de servicio B sin API.

---

#### `ARCH-DATA-002` — Cambios de schema con compatibilidad
**Severidad:** high · **Aplica a:** data

Cambiar schema no rompe producción porque se hace en pasos compatibles.

**Dónde buscar:** `**/migrations/**`, `**/db/**`, `**/*.sql`, `**/schema.prisma`
**Patrones:**
- `DROP\s+(COLUMN|TABLE)`     # drops directos sin pasos expand/contract
- `ALTER\s+TABLE\s+\w+\s+RENAME\s+(COLUMN\s+)?\w+\s+TO`     # rename directo (debería ser duplicar+migrar+drop)
- `ALTER\s+COLUMN\s+\w+\s+TYPE`     # cambio de tipo directo
- `NOT\s+NULL`     # añadir NOT NULL sin default ni backfill previo
**Señal de N/A:** no hay BD en el stack (sin ORM en deps: `typeorm|prisma|sequelize|mongoose|sqlalchemy|django|gorm|hibernate`, sin archivos `.sql`).

(Ver `CICD-DB-002`, `DB-MIG-002`.)

---

#### `ARCH-DATA-003` — Caching con invalidación explícita
**Severidad:** medium · **Aplica a:** backend

El cache es parte de la arquitectura, no un parche: se decide qué, dónde y por
cuánto.

**Dónde buscar:** `**/services/**`, `**/cache/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `\b(redis|memcached|node-cache|cache-manager|@CacheKey|@Cacheable)\b`     # uso de cache
- `\.(set|setex|cache)\s*\([^)]*,\s*\d+\s*\)`     # set con TTL
- `\.(invalidate|del|evict|delete)\s*\(\s*['"]\w*cache`     # invalidación explícita
- `\.(set|setex)\s*\([^)]*\)(?!.*ttl|.*EX)`     # cache sin TTL declarado
**Señal de N/A:** la app no usa cache de aplicación (sin `redis|memcached|cache-manager` en deps) ni lo necesita por volumen.

(Ver `PERF-BE-020`.)

---

## D. Tenant, multi-region

#### `ARCH-TENANT-001` — Estrategia de multi-tenancy definida
**Severidad:** high · **Aplica a:** backend · data

Se elige y respeta una estrategia: shared DB con tenant_id, schema por tenant,
DB por tenant.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/entities/**`, `**/middlewares/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `tenant_?[Ii]d`     # presencia de columna/parámetro tenant_id
- `\.(find|findOne|where|filter)\s*\(\s*\{[^}]*\}\s*\)`     # queries que podrían omitir tenant_id (revisar manualmente)
- `SET\s+search_path|CREATE\s+SCHEMA`     # estrategia schema-per-tenant (Postgres)
- `@Filter\(.*tenant`     # filtros globales de tenant (ORM)
**Señal de N/A:** la app es single-tenant por diseño (un único cliente o despliegue por cliente sin lógica de tenant_id).

**Verificar:**
- [ ] Decisión documentada con trade-offs.
- [ ] Todo query incluye filtro de tenant cuando aplica.
- [ ] Pruebas de aislamiento entre tenants.

---

#### `ARCH-REGION-001` — Estrategia multi-region consciente
**Severidad:** medium · **Aplica a:** infra

Si el producto sirve a múltiples regiones, la arquitectura lo considera
(latencia, soberanía de datos).

**Dónde buscar:** `**/architecture/**`, `**/adr/**`, `**/infra/**`, `**/terraform/**`, `**/*.{tf,yaml,yml}`
**Patrones:**
- `region\s*[:=]\s*['"](us-|eu-|sa-|ap-)`     # configuración multi-region
- `replication|failover|geo[_-]?(replica|distributed)`     # estrategia de replicación
- `data[_-]?residency|gdpr|lgpd|soberan`     # consideración de residencia/regulación
- *(además — revisión humana de la estrategia documentada)*
**Señal de N/A:** el producto sirve a una única región/jurisdicción y no hay requisitos regulatorios de residencia de datos.

**Verificar:**
- [ ] Regiones y sus roles documentados.
- [ ] Residencia de datos cumple regulaciones (GDPR, LGPD, etc.).
- [ ] Replicación / failover entre regiones planificados.

---

## E. Escalabilidad y stateless

#### `ARCH-SCALE-001` — Servicios stateless cuando sea posible
**Severidad:** high · **Aplica a:** backend · infra

El estado vive en stores (BD, cache, objeto), no en memoria del proceso.

**Dónde buscar:** `**/services/**`, `**/middlewares/**`, `**/*.{ts,js,py,go,java,cs}`, `**/config/**`
**Patrones:**
- `express-session\s*\(\s*\{\s*\}|MemoryStore`     # sesiones en memoria
- `(let|var|const)\s+\w*[Cc]ache\s*=\s*(new\s+Map|\{\})`     # cache en variable de módulo (state local)
- `multer\(\s*\{\s*dest:`     # uploads en disco local del proceso
- `fs\.writeFileSync?\s*\(\s*['"]\.?\/(uploads|tmp)`     # escritura en filesystem local
- `global\.\w+\s*=`     # estado global del proceso
**Señal de N/A:** el repo es un script CLI / job batch que no se escala horizontalmente (single-instance por diseño).

**Verificar:**
- [ ] Sesiones en Redis/DB, no en memoria.
- [ ] Uploads en storage, no en disco local.
- [ ] Los workers se pueden escalar horizontal sin coordinación extra.
- [ ] Ningún worker es "especial" (sticky) salvo justificación.

---

#### `ARCH-SCALE-002` — Trabajos en colas para desacoplar spikes
**Severidad:** medium · **Aplica a:** backend · infra

Trabajos costosos van a colas; los workers procesan a su ritmo.

**Dónde buscar:** `**/workers/**`, `**/jobs/**`, `**/queues/**`, `**/services/**`, `**/*.{ts,js,py,go,java,cs}`
**Patrones:**
- `(bullmq|bull|bee-queue|kue|celery|sidekiq|rq|asynq|hangfire)`     # uso de cola de jobs
- `@Process|@Processor|@WorkerHost`     # decoradores worker (BullMQ/Nest)
- `await\s+\w+\.(send|sendMail|render|generate|export)\s*\([^)]{500,}`     # operaciones costosas síncronas sospechosas
- `setTimeout\s*\([^,]+,\s*\d{4,}`     # "colas" hechas a mano con setTimeout
**Señal de N/A:** la app no tiene trabajos costosos (sin emails, exports, procesamiento batch, ML, generación de PDFs, etc.).

(Ver `PERF-BE-030`.)

---

## F. Documentación arquitectural

#### `ARCH-DOC-001` — Diagramas actualizados (C4)
**Severidad:** medium · **Aplica a:** documentation

Existen diagramas de la arquitectura (contexto, contenedores, componentes).

**Dónde buscar:** `**/docs/**`, `**/architecture/**`, `**/adr/**`, `**/*.{md,puml,dsl,mmd}`, `README*`
**Patrones:**
- `\`\`\`mermaid|@startuml|workspace\s*\{`     # diagramas en formato editable (Mermaid/PlantUML/Structurizr)
- `C4Context|C4Container|C4Component`     # diagramas C4
- `!include\s+C4`     # PlantUML C4
**Señal de N/A:** el repo es un script o lib pequeña (<5 módulos) donde un diagrama no aporta valor.

**Verificar:**
- [ ] Diagramas en formato editable (Mermaid, PlantUML, Structurizr).
- [ ] Al menos nivel Context y Container.
- [ ] Actualizados en cada cambio arquitectural relevante.

(Cross con `14-documentacion/`.)

---

#### `ARCH-DOC-002` — ADRs para decisiones arquitecturales
**Severidad:** medium · **Aplica a:** documentation

Las decisiones arquitecturales se documentan con ADRs (Architecture Decision
Records).

**Dónde buscar:** `**/adr/**`, `**/docs/adr/**`, `**/architecture/decisions/**`, `**/*.md`
**Patrones:**
- `\d{4}-\w+\.md`     # convención de archivo ADR (NNNN-titulo.md)
- `##?\s*(Status|Estado)\s*[:|\n]`     # secciones típicas de ADR
- `(Accepted|Aceptada|Superseded|Deprecated)`     # estados de ADR
- `\bADR-\d+\b`     # referencias a ADRs
**Señal de N/A:** el repo es un script o experimentación sin decisiones arquitecturales relevantes que documentar.

(Ver `14-documentacion/02-adrs-operacional.md`.)

---

## Checklist resumen

| ID                | Control                                           | Severidad |
| ----------------- | ------------------------------------------------- | --------- |
| ARCH-LAYER-001    | Capas con dependencia unidireccional              | high      |
| ARCH-LAYER-002    | Bounded contexts explícitos                       | medium    |
| ARCH-LAYER-003    | Separación lectura/escritura si aporta            | low       |
| ARCH-COUPL-001    | Contratos estables entre servicios                | high      |
| ARCH-COUPL-002    | Dependencias minimizadas                          | medium    |
| ARCH-COUPL-003    | Comunicación asíncrona                            | medium    |
| ARCH-COUPL-004    | Shared libs minimal                               | medium    |
| ARCH-DATA-001     | Ownership de datos                                | high      |
| ARCH-DATA-002     | Cambios de schema compatibles                     | high      |
| ARCH-DATA-003     | Caching con invalidación                          | medium    |
| ARCH-TENANT-001   | Estrategia multi-tenancy                          | high      |
| ARCH-REGION-001   | Estrategia multi-region                           | medium    |
| ARCH-SCALE-001    | Servicios stateless                               | high      |
| ARCH-SCALE-002    | Trabajos en colas                                 | medium    |
| ARCH-DOC-001      | Diagramas actualizados                            | medium    |
| ARCH-DOC-002      | ADRs                                              | medium    |
