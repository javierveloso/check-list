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

**Verificar:**
- [ ] Cada bounded context (billing, catálogo, auth, etc.) tiene su propio módulo/paquete.
- [ ] No hay "God Models" que sepan de todo el dominio.
- [ ] Mapeos explícitos entre contextos (anti-corruption layer) cuando sea necesario.

---

#### `ARCH-LAYER-003` — Separación lectura/escritura cuando aporta (CQRS ligero)
**Severidad:** low · **Aplica a:** backend

Para casos donde lectura y escritura tienen necesidades muy distintas
(reports, dashboards), se separan los modelos.

**Verificar:**
- [ ] Queries de reporting usan views/read models especializados.
- [ ] Commands y queries tienen interfaces distintas cuando aporta claridad.

---

## B. Acoplamiento y cohesión

#### `ARCH-COUPL-001` — Servicios con contratos estables
**Severidad:** high · **Aplica a:** backend

Entre servicios internos existen contratos bien definidos (schema, OpenAPI,
protobuf) que cambian bajo control.

**Verificar:**
- [ ] Cada servicio publica su contrato.
- [ ] Consumidores versiones compatibles.
- [ ] Cambios breaking siguen proceso claro (ver `API-VER-002`).

---

#### `ARCH-COUPL-002` — Dependencias entre servicios minimizadas
**Severidad:** medium · **Aplica a:** backend

Los servicios no se llaman en cascadas largas para servir una request.

**Verificar:**
- [ ] Dependencias graficadas y revisadas regularmente.
- [ ] Request crítica no requiere más de 2-3 hops internos.
- [ ] Se evalúa periódicamente si un módulo debería ser servicio aparte o fusionarse.

---

#### `ARCH-COUPL-003` — Comunicación asíncrona cuando es apropiada
**Severidad:** medium · **Aplica a:** backend

Flujos que no requieren respuesta inmediata usan eventos/colas, reduciendo
acoplamiento temporal.

**Verificar:**
- [ ] Side effects (emails, notifs, indexación) se disparan como eventos.
- [ ] Los consumidores son idempotentes (ver `CODE-EFFECT-002`).
- [ ] Eventos tienen schema versionado.

---

#### `ARCH-COUPL-004` — Shared libraries versionadas y minimal
**Severidad:** medium · **Aplica a:** backend

Las librerías compartidas son pequeñas, estables y versionadas. No son
vehículo para propagar todos los cambios.

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

(Ver `CICD-DB-002`, `DB-MIG-002`.)

---

#### `ARCH-DATA-003` — Caching con invalidación explícita
**Severidad:** medium · **Aplica a:** backend

El cache es parte de la arquitectura, no un parche: se decide qué, dónde y por
cuánto.

(Ver `PERF-BE-020`.)

---

## D. Tenant, multi-region

#### `ARCH-TENANT-001` — Estrategia de multi-tenancy definida
**Severidad:** high · **Aplica a:** backend · data

Se elige y respeta una estrategia: shared DB con tenant_id, schema por tenant,
DB por tenant.

**Verificar:**
- [ ] Decisión documentada con trade-offs.
- [ ] Todo query incluye filtro de tenant cuando aplica.
- [ ] Pruebas de aislamiento entre tenants.

---

#### `ARCH-REGION-001` — Estrategia multi-region consciente
**Severidad:** medium · **Aplica a:** infra

Si el producto sirve a múltiples regiones, la arquitectura lo considera
(latencia, soberanía de datos).

**Verificar:**
- [ ] Regiones y sus roles documentados.
- [ ] Residencia de datos cumple regulaciones (GDPR, LGPD, etc.).
- [ ] Replicación / failover entre regiones planificados.

---

## E. Escalabilidad y stateless

#### `ARCH-SCALE-001` — Servicios stateless cuando sea posible
**Severidad:** high · **Aplica a:** backend · infra

El estado vive en stores (BD, cache, objeto), no en memoria del proceso.

**Verificar:**
- [ ] Sesiones en Redis/DB, no en memoria.
- [ ] Uploads en storage, no en disco local.
- [ ] Los workers se pueden escalar horizontal sin coordinación extra.
- [ ] Ningún worker es "especial" (sticky) salvo justificación.

---

#### `ARCH-SCALE-002` — Trabajos en colas para desacoplar spikes
**Severidad:** medium · **Aplica a:** backend · infra

Trabajos costosos van a colas; los workers procesan a su ritmo.

(Ver `PERF-BE-030`.)

---

## F. Documentación arquitectural

#### `ARCH-DOC-001` — Diagramas actualizados (C4)
**Severidad:** medium · **Aplica a:** documentation

Existen diagramas de la arquitectura (contexto, contenedores, componentes).

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
