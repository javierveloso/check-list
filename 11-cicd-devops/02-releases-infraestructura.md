# 11 · CI/CD · Releases, infraestructura y rollback

> Estrategias de despliegue, feature flags, rollback, IaC.

---

## A. Estrategias de despliegue

#### `CICD-DEPLOY-001` — Despliegue con downtime cero
**Severidad:** high · **Aplica a:** infra

El despliegue no interrumpe servicio: rolling, blue-green, canary.

**Verificar:**
- [ ] Estrategia definida y documentada (rolling por defecto).
- [ ] Liveness/readiness (ver `OBS-HEALTH-001`) permiten orquestar correctamente.
- [ ] Migrations de BD compatibles con N y N+1 versiones simultáneas.
- [ ] Graceful shutdown en workers (termina tareas en vuelo, no acepta nuevas).

**Banderas rojas:**
- Despliegue que reinicia todo el servicio en serie.
- Migrations breaking sin plan de compatibilidad.

---

#### `CICD-DEPLOY-002` — Canary / progressive rollout para riesgos altos
**Severidad:** medium · **Aplica a:** infra

Cambios significativos se despliegan gradualmente (1% → 10% → 50% → 100%) con
métricas monitoreadas.

**Verificar:**
- [ ] Herramienta (Flagger, Argo Rollouts, LaunchDarkly) en uso.
- [ ] Criterios de promoción/rollback claros y automáticos donde posible.
- [ ] Monitoreo de errores y latencia durante el rollout.

---

#### `CICD-DEPLOY-003` — Rollback rápido y probado
**Severidad:** critical · **Aplica a:** infra

Se puede volver a la versión anterior en minutos; el proceso se prueba
periódicamente.

**Verificar:**
- [ ] Rollback a versión anterior con un comando/botón.
- [ ] Se ensaya rollback periódicamente (game days).
- [ ] Migrations de BD diseñadas para permitir rollback (ver `DB-MIG-002`).
- [ ] Rollback de feature flags instantáneo.

---

## B. Feature flags

#### `CICD-FLAG-001` — Feature flags para cambios riesgosos
**Severidad:** medium · **Aplica a:** backend · frontend

Features nuevas se liberan detrás de flags; se pueden activar/desactivar sin
redeploy.

**Verificar:**
- [ ] Sistema de flags (LaunchDarkly, Unleash, propio) en uso.
- [ ] Flags con dueño, descripción y fecha de sunset.
- [ ] Flags viejos se limpian (technical debt budget).
- [ ] Flags de killswitch para features de alto riesgo.

---

#### `CICD-FLAG-002` — Flags evaluados consistentemente
**Severidad:** medium · **Aplica a:** backend · frontend

La misma flag se evalúa igual en toda la request.

**Verificar:**
- [ ] Flag evaluada una vez por request, no múltiples veces (evita flapping).
- [ ] Evaluación considera usuario/tenant/atributos relevantes.
- [ ] Sticky assignment cuando el contexto lo requiere.

---

## C. Infrastructure as Code

#### `CICD-IAC-001` — Toda la infra como código
**Severidad:** high · **Aplica a:** infra

Los recursos de cloud, networking, DNS, queues, etc., están en código (Terraform,
Pulumi, CDK) versionado.

**Verificar:**
- [ ] Terraform/Pulumi/CDK con state backend compartido.
- [ ] PRs de IaC requieren review.
- [ ] `plan` y `apply` separados; `plan` visible en PR.
- [ ] Changes via consola de cloud se evitan; drift detectado automáticamente.

---

#### `CICD-IAC-002` — Secretos fuera del IaC
**Severidad:** critical · **Aplica a:** infra

Los valores secretos no viven en los archivos de IaC commiteados.

**Verificar:**
- [ ] Referencias a secret manager / vault.
- [ ] Variables marcadas como `sensitive = true` cuando aplique.
- [ ] `state` cifrado y con acceso restringido.

---

#### `CICD-IAC-003` — Módulos reutilizables y versionados
**Severidad:** medium · **Aplica a:** infra

Patrones comunes (network, servicio, BD) viven en módulos reutilizables.

**Verificar:**
- [ ] Módulos versionados y documentados.
- [ ] Pin a versiones específicas.
- [ ] Tests básicos de los módulos (tflint, checkov).

---

## D. Migraciones de BD

#### `CICD-DB-001` — Migraciones versionadas y automatizadas
**Severidad:** high · **Aplica a:** data · ci-cd

Las migraciones están en el repo, son forward-only preferentemente, y se
aplican en el deploy.

**Verificar:**
- [ ] Herramienta (Alembic, Flyway, Liquibase, Prisma migrate, Django migrations) en uso.
- [ ] Nombres con timestamp y descripción.
- [ ] `up` y `down` cuando el tooling lo soporta (prefiere forward-only con compensación).
- [ ] Migraciones revisadas en PR.

(Más detalle en `13-base-datos/01-esquema-migraciones.md`.)

---

#### `CICD-DB-002` — Migraciones compatibles con despliegue sin downtime
**Severidad:** high · **Aplica a:** data

Cambios de schema se diseñan para funcionar con versión N y N+1 simultáneas.

**Verificar:**
- [ ] Pattern expand-contract para renames y cambios incompatibles.
- [ ] Columnas nuevas nullable o con default (no NOT NULL sin backfill).
- [ ] Borrar columnas: primero stop using, luego drop en siguiente release.
- [ ] Backfills en background, no en la migración sincrónica.

---

## E. Backups y recuperación

#### `CICD-BK-001` — Backups automáticos y probados
**Severidad:** critical · **Aplica a:** infra · data

Los backups se crean automáticamente y su restauración se prueba.

**Verificar:**
- [ ] Frecuencia y retención definidas.
- [ ] Backups cifrados con claves gestionadas.
- [ ] Los backups se almacenan en región/cuenta separada.
- [ ] RTO (recovery time objective) y RPO (recovery point objective) documentados.
- [ ] Restauración ensayada periódicamente (game days).

---

#### `CICD-BK-002` — Disaster recovery plan
**Severidad:** high · **Aplica a:** infra

Existe plan documentado para caídas mayores (región entera, pérdida de datos).

**Verificar:**
- [ ] Playbook escrito con pasos, contactos, dependencias.
- [ ] Se ensaya al menos anualmente.
- [ ] Comunicación al usuario también está planificada.

---

## F. Monitoreo del deploy

#### `CICD-DEPLOY-010` — Métricas del deploy mismo
**Severidad:** medium · **Aplica a:** observability · ci-cd

Se miden: frecuencia de deploys, lead time for changes, change failure rate,
time to restore (DORA metrics).

**Verificar:**
- [ ] Deployment frequency visible.
- [ ] Lead time (commit → prod) medido.
- [ ] Change failure rate (% de deploys que generan incidente).
- [ ] MTTR para incidents.

---

## Checklist resumen

| ID                 | Control                                             | Severidad |
| ------------------ | --------------------------------------------------- | --------- |
| CICD-DEPLOY-001    | Despliegue zero-downtime                            | high      |
| CICD-DEPLOY-002    | Canary / progressive rollout                        | medium    |
| CICD-DEPLOY-003    | Rollback rápido                                     | critical  |
| CICD-FLAG-001      | Feature flags                                       | medium    |
| CICD-FLAG-002      | Flags consistentes                                  | medium    |
| CICD-IAC-001       | Infra como código                                   | high      |
| CICD-IAC-002       | Secretos fuera del IaC                              | critical  |
| CICD-IAC-003       | Módulos IaC reutilizables                           | medium    |
| CICD-DB-001        | Migraciones versionadas                             | high      |
| CICD-DB-002        | Migraciones compatibles                             | high      |
| CICD-BK-001        | Backups automáticos y probados                      | critical  |
| CICD-BK-002        | DR plan                                             | high      |
| CICD-DEPLOY-010    | DORA metrics                                        | medium    |
