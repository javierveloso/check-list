# 11 · CI/CD · Releases, infraestructura y rollback

> Estrategias de despliegue, feature flags, rollback, IaC.

---

## A. Estrategias de despliegue

#### `CICD-DEPLOY-001` — Despliegue con downtime cero
**Severidad:** high · **Aplica a:** infra

El despliegue no interrumpe servicio: rolling, blue-green, canary.

**Dónde buscar:** `**/k8s/**`, `**/helm/**`, `**/*.{tf,yaml}`, `Dockerfile*`, `.github/workflows/*.{yml,yaml}`
**Patrones:**
- `strategy:\s*\n\s*type:\s*RollingUpdate|maxUnavailable|maxSurge`     # rolling K8s
- `blue.green|blueGreen|argo-rollouts|flagger`     # estrategia avanzada
- `terminationGracePeriodSeconds`     # graceful shutdown
- `preStop|SIGTERM`     # señal de shutdown manejada
- `kubectl\s+rollout\s+restart|recreate`     # restart abrupto (anti-señal)
**Señal de N/A:** no hay infraestructura/deploy en el repo o stack_signal.has_ci == false

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

**Dónde buscar:** `**/k8s/**`, `**/helm/**`, `**/*.{tf,yaml}`, `.github/workflows/*.{yml,yaml}`
**Patrones:**
- `argo-rollouts|flagger|spinnaker|kayenta`     # tooling de canary
- `canary:|canaryWeight|stepWeights`     # configuración canary
- `analysis:|analysisTemplate`     # análisis automático de métricas
- `setWeight:\s*\d+|weight:\s*\d+`     # progresión por peso
- `pause:\s*\{`     # pausa para revisión humana
**Señal de N/A:** no hay infraestructura/deploy en el repo o stack_signal.has_ci == false

**Verificar:**
- [ ] Herramienta (Flagger, Argo Rollouts, LaunchDarkly) en uso.
- [ ] Criterios de promoción/rollback claros y automáticos donde posible.
- [ ] Monitoreo de errores y latencia durante el rollout.

---

#### `CICD-DEPLOY-003` — Rollback rápido y probado
**Severidad:** critical · **Aplica a:** infra

Se puede volver a la versión anterior en minutos; el proceso se prueba
periódicamente.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `**/k8s/**`, `**/helm/**`, `scripts/**`, `runbooks/**`, `**/*.md`
**Patrones:**
- `kubectl\s+rollout\s+undo|helm\s+rollback|argo\s+rollout\s+abort`     # comandos de rollback
- `rollback\.sh|rollback-`     # scripts de rollback
- `previous_image|PREVIOUS_TAG|LAST_KNOWN_GOOD`     # tracking de versión previa
- `revisionHistoryLimit:\s*\d+`     # historia preservada para rollback
- `workflow_dispatch.*rollback`     # workflow manual de rollback
**Señal de N/A:** no hay infraestructura/deploy en el repo o stack_signal.has_ci == false

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

**Dónde buscar:** `**/*.{ts,js,py,go,java}`, `package.json`, `requirements.txt`
**Patrones:**
- `LaunchDarkly|launchdarkly|unleash|configcat|flagsmith|optimizely`     # SDK de flags
- `featureFlag|feature_flag|isEnabled\(|isFeatureEnabled`     # uso de flags
- `if\s*\(\s*process\.env\.FEATURE_`     # flags por env var (variante simple)
- `killswitch|kill[_-]?switch`     # killswitch presente
- `// TODO.*remove.*flag|sunset:\s*\d{4}`     # gestión de sunset
**Señal de N/A:** no se usan feature flags en el repo (no hay SDK ni flags en código)

**Verificar:**
- [ ] Sistema de flags (LaunchDarkly, Unleash, propio) en uso.
- [ ] Flags con dueño, descripción y fecha de sunset.
- [ ] Flags viejos se limpian (technical debt budget).
- [ ] Flags de killswitch para features de alto riesgo.

---

#### `CICD-FLAG-002` — Flags evaluados consistentemente
**Severidad:** medium · **Aplica a:** backend · frontend

La misma flag se evalúa igual en toda la request.

**Dónde buscar:** `**/middleware/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `flagContext|FlagProvider|FeatureFlagContext`     # contexto de flags por request
- `evaluateAll\(|getAllFlags\(`     # evaluación batch
- `userKey|userId|tenantId`\s*:\s.*flag     # contexto pasado al SDK
- `useFlag\(|useFeature\(`     # hooks por componente (riesgo flapping si se reevalúa)
**Señal de N/A:** no se usan feature flags en el repo

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

**Dónde buscar:** `**/*.{tf,bicep}`, `**/cdk*.{ts,py,json}`, `**/pulumi*.{ts,py,yaml}`, `**/k8s/**`, `**/helm/**`
**Patrones:**
- `terraform\s+\{|provider\s+[\"']aws[\"']|resource\s+[\"']`     # bloques Terraform
- `backend\s+[\"'](s3|azurerm|gcs|remote)[\"']`     # state remoto compartido
- `terraform\s+plan|tf\s+plan`     # plan en pipeline
- `terraform\s+apply\s+-auto-approve`     # apply sin revisión (anti-señal en prod)
- `tags\s*=\s*\{`     # tagging de recursos
**Señal de N/A:** no hay infraestructura como código en el repo o stack_signal.has_ci == false

**Verificar:**
- [ ] Terraform/Pulumi/CDK con state backend compartido.
- [ ] PRs de IaC requieren review.
- [ ] `plan` y `apply` separados; `plan` visible en PR.
- [ ] Changes via consola de cloud se evitan; drift detectado automáticamente.

---

#### `CICD-IAC-002` — Secretos fuera del IaC
**Severidad:** critical · **Aplica a:** infra

Los valores secretos no viven en los archivos de IaC commiteados.

**Dónde buscar:** `**/*.{tf,tfvars,bicep,yaml}`, `**/k8s/**`, `**/helm/**`
**Patrones:**
- `data\s+[\"']aws_secretsmanager_secret|azurerm_key_vault_secret|google_secret_manager`     # referencia a vault
- `external-secrets|sealed-secrets|sops`     # tooling de secret management
- `sensitive\s*=\s*true`     # marcado sensible
- `password\s*=\s*[\"'][^\"']+[\"']|api_key\s*=\s*[\"'][a-zA-Z0-9]{16,}`     # secret hardcodeado (anti-señal)
- `\.tfvars\b`     # tfvars commiteado (verificar contenido)
**Señal de N/A:** no hay infraestructura como código en el repo o stack_signal.has_ci == false

**Verificar:**
- [ ] Referencias a secret manager / vault.
- [ ] Variables marcadas como `sensitive = true` cuando aplique.
- [ ] `state` cifrado y con acceso restringido.

---

#### `CICD-IAC-003` — Módulos reutilizables y versionados
**Severidad:** medium · **Aplica a:** infra

Patrones comunes (network, servicio, BD) viven en módulos reutilizables.

**Dónde buscar:** `**/*.{tf,bicep}`, `**/modules/**`, `**/helm/**/Chart.yaml`
**Patrones:**
- `module\s+[\"']\w+[\"']\s*\{`     # uso de módulos
- `source\s*=\s*[\"'](git|github\.com|registry\.terraform\.io)`     # fuente versionada
- `version\s*=\s*[\"'][~^]?\d+\.\d+`     # pin a versión
- `tflint|checkov|terratest`     # tooling de validación
- `source\s*=\s*[\"']\.\./|source\s*=\s*[\"']\./`     # módulo local sin pin (anti-señal)
**Señal de N/A:** no hay infraestructura como código en el repo o stack_signal.has_ci == false

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

**Dónde buscar:** `**/migrations/**`, `**/alembic/**`, `**/prisma/migrations/**`, `**/*.{sql}`, `package.json`, `requirements.txt`
**Patrones:**
- `alembic|flyway|liquibase|prisma\s+migrate|knex.*migrate|django.*migrations`     # tool
- `\d{8,14}_\w+\.(sql|py|js|ts)`     # nombre con timestamp
- `migrations/V\d+__|migrations/\d+_`     # esquema de versionado
- `migrate\s+up|migrate\s+deploy|alembic\s+upgrade`     # comando en pipeline
- `BEGIN;.*COMMIT;`     # transacción explícita
**Señal de N/A:** no hay base de datos relacional en el repo (sin migraciones presentes)

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

**Dónde buscar:** `**/migrations/**`, `**/*.sql`
**Patrones:**
- `ALTER\s+TABLE\s+\w+\s+DROP\s+COLUMN`     # drop directo (anti-señal sin expand-contract)
- `ADD\s+COLUMN\s+\w+\s+\w+\s+NOT\s+NULL\b(?!\s+DEFAULT)`     # NOT NULL sin default (anti-señal)
- `RENAME\s+(COLUMN|TO)`     # rename directo (anti-señal)
- `CREATE\s+INDEX\s+CONCURRENTLY|ADD\s+COLUMN.*DEFAULT`     # patrón compatible (señal positiva)
- `backfill|backfill_`     # backfill explícito
**Señal de N/A:** no hay base de datos relacional / migraciones en el repo

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

**Dónde buscar:** `**/*.{tf,yaml,yml}`, `**/k8s/**`, `**/helm/**`, `.github/workflows/*.{yml,yaml}`, `scripts/**`
**Patrones:**
- `backup_retention_period|backup_window|backupSchedule`     # config de backups
- `velero|kasten|stash|restic|pgbackrest`     # tooling de backup
- `kms_key_id|encrypted\s*=\s*true`     # backups cifrados
- `cross_region_backup|cross-region|destination_region`     # backup cross-region
- `RPO|RTO`     # objetivos documentados
**Señal de N/A:** no hay infraestructura/datos persistentes en el repo o stack_signal.has_ci == false

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

**Dónde buscar:** `docs/**`, `runbooks/**`, `dr/**`, `**/*.md`
**Patrones:**
- *(sin patrones mecánicos — revisión humana / proceso)*
**Señal de N/A:** no hay infraestructura/servicios productivos en el repo o stack_signal.has_ci == false

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

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `**/instrumentation/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `deployment_frequency|lead_time|change_failure_rate|mttr`     # nombres DORA
- `four-keys|fourkeys|sleuth|linearb`     # tooling DORA
- `deployment\.created|deployment\.success|deployment\.failure`     # eventos de deploy
- `incident\.opened|incident\.resolved`     # tracking de incidentes
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

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
