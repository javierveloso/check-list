# 11 · CI/CD · Pipelines y quality gates

> Pipelines de integración, linting, tests, seguridad, y control de calidad
> antes de merge.

---

## A. Pipelines

#### `CICD-PIPE-001` — Pipeline por PR con etapas fast-fail
**Severidad:** high · **Aplica a:** ci-cd

Cada PR dispara un pipeline que valida el cambio antes del merge, en etapas
ordenadas del más rápido al más lento.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.gitlab-ci.yml`, `azure-pipelines*.{yml,yaml}`, `Jenkinsfile`, `bitbucket-pipelines.yml`
**Patrones:**
- `on:\s*\n\s*pull_request|on:\s*\[?pull_request`     # workflow disparado por PR
- `\bjobs:\s*\n[\s\S]*\b(lint|format|typecheck|test|build)\s*:`     # etapas estándar
- `needs:\s*\[?\w+`     # dependencias entre jobs (orden fast-fail)
- `if:\s*always\(\)`     # bypassea fast-fail (anti-señal en gates)
- `fail-fast:\s*false`     # desactiva fail-fast en matrix
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Orden: lint/format → typecheck → unit → integration → E2E (si aplica) → security.
- [ ] Fast-fail: si algo básico falla, las etapas caras no corren.
- [ ] El pipeline corre en un entorno limpio (no deps del runner).
- [ ] Feedback del pipeline aparece claramente en el PR.

---

#### `CICD-PIPE-002` — Builds reproducibles
**Severidad:** high · **Aplica a:** ci-cd

El mismo commit produce el mismo artefacto, independiente de quién o cuándo
lo construye.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.gitlab-ci.yml`, `Jenkinsfile`, `Dockerfile*`, `package*.json`, `**/*.lock`
**Patrones:**
- `package-lock\.json|yarn\.lock|pnpm-lock\.yaml|poetry\.lock|Cargo\.lock|go\.sum`     # lockfiles presentes
- `npm\s+ci|yarn\s+install\s+--frozen-lockfile|pnpm\s+install\s+--frozen-lockfile`     # install determinista
- `FROM\s+\w+:[\w.-]+@sha256:[a-f0-9]{64}`     # imagen base pinneada por digest
- `FROM\s+\w+:latest`     # tag latest (anti-señal)
- `BUILD_DATE|GIT_SHA|VCS_REF|COMMIT_HASH`     # metadata embebida
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Lock files commiteados (`package-lock.json`, `poetry.lock`, `Cargo.lock`, etc.).
- [ ] Instalación con `--frozen-lockfile` / `npm ci`.
- [ ] Imagen base pinneada por digest en Docker.
- [ ] No hay dependencia del wall clock salvo donde es explícita.
- [ ] Artefactos incluyen metadata (commit hash, build date, builder).

---

#### `CICD-PIPE-003` — Caché efectiva entre runs
**Severidad:** medium · **Aplica a:** ci-cd

Las dependencias y outputs intermedios se cachean para acelerar builds.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.gitlab-ci.yml`, `azure-pipelines*.{yml,yaml}`, `Jenkinsfile`
**Patrones:**
- `actions/cache@|cache:\s*\n\s*paths:`     # cache configurada
- `key:.*hashFiles\(`     # key basada en lockfile (correcto)
- `cache-from:|cache-to:|--cache-from`     # buildx/docker cache
- `restore-keys:`     # fallback de cache
- `key:\s*[\"']?build-cache[\"']?\s*$`     # key estática (cache contaminada, anti-señal)
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Cache de deps por lock hash.
- [ ] Cache de tests/build cuando corresponde.
- [ ] TTL y tamaño acotados.
- [ ] El pipeline debe funcionar con cache vacío (no depender de él para corrección).

---

#### `CICD-PIPE-004` — Branch protection y aprobaciones
**Severidad:** high · **Aplica a:** process

Main/master (y ramas release) están protegidas; se requiere revisión y
checks verdes.

**Dónde buscar:** `.github/CODEOWNERS`, `.github/settings.yml`, `.github/branch-protection*.{yml,yaml}`, `**/*.tf`
**Patrones:**
- `branch.*protection|required_status_checks|required_pull_request_reviews`     # config de protección
- `dismiss_stale_reviews|require_code_owner_reviews`     # políticas estrictas
- `enforce_admins:\s*true`     # admins también sujetos
- `allow_force_pushes:\s*true`     # force-push permitido (anti-señal)
- `--no-verify`     # bypass de hooks en commits
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Branch protection activa: review obligatoria, status checks obligatorios.
- [ ] Nadie commitea directo a main.
- [ ] Force-push bloqueado en main.
- [ ] Al menos 1 revisor distinto al autor (2 en repos críticos).
- [ ] CODEOWNERS aplicable.

---

## B. Quality gates

#### `CICD-GATE-001` — Lint, format, typecheck bloqueantes
**Severidad:** high · **Aplica a:** ci-cd

Los PRs con fallos de lint/format/typecheck no se mergean.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.gitlab-ci.yml`, `azure-pipelines*.{yml,yaml}`, `Jenkinsfile`, `package.json`, `pyproject.toml`
**Patrones:**
- `eslint|prettier|stylelint|ruff|flake8|black|gofmt|clippy`     # herramientas de lint/format
- `tsc\s+--noEmit|mypy|pyright|pyre`     # typecheck
- `continue-on-error:\s*true`     # gate que no bloquea (anti-señal)
- `if:\s*always\(\).*\b(lint|typecheck)`     # ejecuta pero no bloquea
- `--fix\s|--write\s`     # fix automático en CI (debería fallar, no auto-arreglar)
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Lint en CI con la misma config que local (pre-commit idealmente).
- [ ] Formatter (prettier/black/etc.) falla si el código no está formateado.
- [ ] Typechecker (mypy/pyright/tsc/clippy/etc.) en strict mode.

---

#### `CICD-GATE-002` — Tests unit + integración obligatorios
**Severidad:** critical · **Aplica a:** ci-cd

Sin tests verdes, no hay merge.

(Cross con `TEST-STRAT-003`.)

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.gitlab-ci.yml`, `azure-pipelines*.{yml,yaml}`, `Jenkinsfile`
**Patrones:**
- `(npm|yarn|pnpm)\s+(run\s+)?test|pytest|go\s+test|mvn\s+test|cargo\s+test`     # ejecución de tests
- `coverage|--cov|nyc|jacoco`     # cobertura medida
- `coverageThreshold|fail_under|--cov-fail-under`     # umbral configurado
- `if:\s*always\(\).*test`     # tests no bloqueantes (anti-señal)
- `--passWithNoTests|--no-tests=skip`     # permite ausencia de tests (anti-señal)
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Tests unitarios y de integración corren en CI.
- [ ] Umbral de cobertura configurado.
- [ ] Tests flaky marcados como tales (no ignorados) y con issue abierto.

---

#### `CICD-GATE-003` — Análisis de seguridad
**Severidad:** high · **Aplica a:** ci-cd

SAST, SCA (dependency scanning) e IaC scanning corren en CI.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.gitlab-ci.yml`, `azure-pipelines*.{yml,yaml}`, `Jenkinsfile`
**Patrones:**
- `semgrep|codeql|snyk\s+code|sonarqube|sonarcloud`     # SAST
- `npm\s+audit|pip-audit|snyk\s+test|dependabot|trivy\s+fs`     # SCA
- `checkov|tfsec|kubesec|terrascan`     # IaC scanning
- `gitleaks|trufflehog|detect-secrets`     # secret scanning
- `severity-threshold|fail-on=critical|--severity\s+CRITICAL`     # política bloqueante
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] SAST: Semgrep, CodeQL, Snyk Code u otro (ver `TEST-SEC-001`).
- [ ] SCA: Snyk, pip-audit, npm audit, Dependabot (ver `SEC-DEPS-004`).
- [ ] IaC: Checkov, tfsec, kubesec si hay Terraform/K8s.
- [ ] Secret scanning activo (gitleaks, trufflehog).
- [ ] Política clara sobre severidades bloqueantes.

---

#### `CICD-GATE-004` — Escaneo de imágenes Docker
**Severidad:** high · **Aplica a:** ci-cd · infra

Antes de publicar una imagen, se escanea en busca de CVEs.

(Ver `SEC-DEPS-032`.)

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.gitlab-ci.yml`, `azure-pipelines*.{yml,yaml}`, `Jenkinsfile`, `Dockerfile*`
**Patrones:**
- `aquasec/trivy|anchore/grype|snyk\s+container|docker\s+scan|clair`     # scanners de imagen
- `--severity\s+(HIGH|CRITICAL)|--exit-code\s+1`     # umbral bloqueante
- `\.trivyignore|\.grypeignore`     # archivo de ignores
- `actions/checkout@(main|master)`     # actions sin pin (anti-señal)
- `uses:\s+\S+@v\d+\.\d+\.\d+|@[a-f0-9]{40}`     # pin a versión/SHA (señal positiva)
**Señal de N/A:** no se construyen imágenes Docker en el repo o stack_signal.has_ci == false

**Verificar:**
- [ ] Trivy/Grype/Snyk Container corre sobre la imagen final.
- [ ] Severidades altas/críticas fallan el build.
- [ ] Los ignores tienen fecha de revisión.

---

#### `CICD-GATE-005` — Tamaño de PR acotado (soft-gate)
**Severidad:** low · **Aplica a:** process

PRs gigantes son difíciles de revisar. Se promueve PRs pequeños.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.github/labeler.yml`, `CONTRIBUTING.md`, `**/*.md`
**Patrones:**
- `pr-size-labeler|size-label-action|pascalgn/size-label-action`     # action de tamaño
- `additions.*deletions|lines.*changed`     # check de líneas
- `max.*lines|MAX_PR_SIZE`     # umbral configurado
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Convención documentada (ej: < 400 líneas cambiadas).
- [ ] PRs grandes se justifican o se dividen.
- [ ] CI puede alertar ante PRs muy grandes.

---

#### `CICD-GATE-006` — Actualización automática de dependencias (Dependabot / Renovate)
**Severidad:** medium · **Aplica a:** ci-cd · process

Un bot de actualización de dependencias (Dependabot, Renovate) está configurado
y abre PRs automáticos cuando hay nuevas versiones. Elimina la deuda silenciosa
de dependencias desactualizadas entre auditorías de seguridad.

> Este control es **complementario** a `CICD-GATE-003` (SCA de vulnerabilidades
> conocidas): ese detecta CVEs; este mantiene el proyecto actualizado
> **antes** de que las versiones queden muy atrás.

**Verificar:**
- [ ] `.github/dependabot.yml` o `renovate.json` presente en el repo y activo.
- [ ] Los PRs de actualización entran al pipeline normal (lint, tests, security scan).
- [ ] Schedule razonable (semanal o mensual), no diario para repos activos.
- [ ] Las actualizaciones de seguridad se configuran con prioridad alta (o `security-updates-only: true` en Dependabot).
- [ ] `automerge` habilitado para `patch` y `minor` cuando la cobertura de tests lo justifica.
- [ ] Actualizaciones de `major` requieren revisión manual y se cierran explícitamente si no se van a hacer.

**Banderas rojas:**
- Repo sin `dependabot.yml` ni `renovate.json`.
- `npm outdated` / `pip list --outdated` muestra dependencias con > 6 meses sin actualizar sin explicación.
- Bot configurado pero PRs de actualización acumulados sin mergear ni cerrar (> 20 PRs abiertos indefinidamente).

**Referencias:** GitHub Dependabot docs · Renovate docs · OWASP A06:2021 (Vulnerable and Outdated Components).

**Dónde buscar:** `.github/dependabot.yml`, `renovate.json`, `.renovaterc*`, `.github/workflows/*.{yml,yaml}`
**Patrones:**
- `package-ecosystem|updates:`     # bloques de Dependabot
- `schedule:\s*\n\s*interval:\s*[\"']?(weekly|monthly)`     # cadencia razonable
- `automerge|automergeType|automergeStrategy`     # automerge configurado
- `security-updates-only|vulnerabilityAlerts`     # prioridad seguridad
- `groupName:|packageRules:`     # agrupación (Renovate)
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

---

## C. Versionado y tags

#### `CICD-VER-001` — Versionado semántico
**Severidad:** medium · **Aplica a:** ci-cd

Los releases siguen SemVer (MAJOR.MINOR.PATCH) y los cambios se documentan.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.releaserc*`, `release-please-config.json`, `package.json`, `CHANGELOG.md`
**Patrones:**
- `semantic-release|release-please|standard-version|changesets`     # tooling de releases
- `\bv?\d+\.\d+\.\d+\b`     # tags SemVer
- `BREAKING\s+CHANGE|!:`     # marca de breaking change
- `CHANGELOG\.md|CHANGES\.md|HISTORY\.md`     # changelog presente
- `version:\s*[\"']\d+\.\d+\.\d+[\"']`     # versión declarada en metadata
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Los tags usan SemVer.
- [ ] Breaking changes incrementan major.
- [ ] Changelog o release notes generados (conventional commits, semantic-release).
- [ ] Los artefactos llevan la versión correcta.

---

#### `CICD-VER-002` — Conventional commits (opcional pero recomendado)
**Severidad:** low · **Aplica a:** process

Formato de commits estandarizado facilita changelog automático y comprensión
del historial.

**Dónde buscar:** `commitlint.config.{js,cjs}`, `.commitlintrc*`, `.husky/commit-msg`, `package.json`, `.github/workflows/*.{yml,yaml}`
**Patrones:**
- `@commitlint/config-conventional|conventional-changelog`     # commitlint
- `husky|simple-git-hooks|pre-commit`     # hooks instalados
- `commit-msg`     # hook de mensaje
- `feat|fix|chore|docs|refactor|test|perf`\(?     # tipos convencionales presentes
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Formato: `tipo(scope): descripción` — `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`.
- [ ] Breaking changes marcados con `!` o `BREAKING CHANGE:`.
- [ ] Linter de commits (commitlint, husky) si el equipo lo adopta.

---

## D. Ambientes y promoción

#### `CICD-ENV-001` — Ambientes espejados
**Severidad:** high · **Aplica a:** infra

Dev / staging / production usan la misma config/infra, con parámetros
adaptados.

**Dónde buscar:** `Dockerfile*`, `docker-compose*.yml`, `**/k8s/**`, `**/helm/**`, `**/*.{tf,yaml}`, `.github/workflows/*.{yml,yaml}`
**Patrones:**
- `environment:\s*\{?\s*name:\s*(dev|staging|production|prod)`     # ambientes definidos
- `Dockerfile\.(prod|staging|dev)`     # múltiples Dockerfiles (anti-señal de espejado)
- `values-(prod|staging|dev)\.yaml`     # values por ambiente (Helm)
- `terraform\s+workspace`     # workspaces para ambientes
- `environments/(dev|staging|prod)`     # estructura por ambiente
**Señal de N/A:** no hay infraestructura/deploy en el repo o stack_signal.has_ci == false

**Verificar:**
- [ ] Un solo Dockerfile y un solo deploy template.
- [ ] Diferencias solo en variables de entorno y secretos.
- [ ] Staging es representativo de producción (datos sintéticos, topología
      similar).

---

#### `CICD-ENV-002` — Promoción de artefacto, no rebuild
**Severidad:** high · **Aplica a:** ci-cd

Lo que se testeó es lo que se despliega: el mismo artefacto viaja de staging
a producción, no se rebuild por ambiente.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.gitlab-ci.yml`, `azure-pipelines*.{yml,yaml}`, `Jenkinsfile`
**Patrones:**
- `IMAGE_TAG|GITHUB_SHA|CI_COMMIT_SHA`     # tag inmutable usado para promoción
- `docker\s+pull\s+\S+:\$\{?\w+\}|docker\s+tag\s+\S+\s+\S+:prod`     # promoción de imagen
- `needs:\s*\[?build`     # deploy depende de build (un solo build)
- `docker\s+build.*deploy`\s.*prod     # build + deploy en mismo job (anti-señal si es el segundo)
- `ECR|GCR|ACR|registry`     # uso de registry compartido
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Imagen/paquete construido una vez por commit.
- [ ] Tag inmutable (ej: `v1.2.3` o `sha-...`).
- [ ] El deploy a prod usa el mismo tag testeado en staging.

---

## E. Developer experience

#### `CICD-DX-001` — Local parity con CI
**Severidad:** medium · **Aplica a:** process

Los checks de CI se pueden correr localmente (o con docker) antes de pushear.

**Dónde buscar:** `Makefile`, `package.json`, `pyproject.toml`, `Taskfile.yml`, `justfile`, `scripts/**`, `README.md`
**Patrones:**
- `make\s+(test|ci|check)|npm\s+run\s+ci|task\s+ci|just\s+ci`     # comandos atajo
- `\.husky/|pre-commit|lefthook`     # hooks instalables
- `act\s|nektos/act`     # correr GH Actions local
- `docker-compose.*test|compose\.test\.yml`     # entorno de test dockerizado
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] `make test`, `npm run ci`, script equivalente.
- [ ] Pre-commit/pre-push hooks opcionales (husky, pre-commit).
- [ ] `README` explica cómo correr todo.

---

#### `CICD-DX-002` — CI rápido (< 10 min ideal)
**Severidad:** medium · **Aplica a:** ci-cd

Feedback rápido aumenta la productividad.

**Dónde buscar:** `.github/workflows/*.{yml,yaml}`, `.gitlab-ci.yml`, `azure-pipelines*.{yml,yaml}`, `Jenkinsfile`
**Patrones:**
- `strategy:\s*\n\s*matrix:`     # matrix paralela
- `parallel:\s*\d+|--parallel`     # ejecución paralela
- `timeout-minutes:\s*\d+`     # timeout configurado
- `needs:\s*\[`     # ordenamiento explícito
- `schedule:\s*\n\s*-\s*cron`     # cron jobs (E2E nocturno)
**Señal de N/A:** no hay archivos en `.github/workflows/`, `.gitlab-ci.yml`, `azure-pipelines*`, `Jenkinsfile` o stack_signal.has_ci == false

**Verificar:**
- [ ] Pipeline principal tarda menos de ~10 min.
- [ ] Jobs en paralelo donde sea posible.
- [ ] Tests lentos (E2E completo) en pipeline separado o nocturno.

---

## Checklist resumen

| ID               | Control                                             | Severidad |
| ---------------- | --------------------------------------------------- | --------- |
| CICD-PIPE-001    | Pipeline PR con etapas fast-fail                    | high      |
| CICD-PIPE-002    | Builds reproducibles                                | high      |
| CICD-PIPE-003    | Cache efectiva                                      | medium    |
| CICD-PIPE-004    | Branch protection                                   | high      |
| CICD-GATE-001    | Lint/format/typecheck bloqueantes                   | high      |
| CICD-GATE-002    | Tests bloqueantes                                   | critical  |
| CICD-GATE-003    | Análisis de seguridad                               | high      |
| CICD-GATE-004    | Escaneo de imágenes                                 | high      |
| CICD-GATE-005    | PRs acotados                                        | low       |
| CICD-GATE-006    | Dependabot / Renovate configurado                   | medium    |
| CICD-VER-001     | Versionado semántico                                | medium    |
| CICD-VER-002     | Conventional commits                                | low       |
| CICD-ENV-001     | Ambientes espejados                                 | high      |
| CICD-ENV-002     | Promoción de artefacto                              | high      |
| CICD-DX-001      | Local parity con CI                                 | medium    |
| CICD-DX-002      | CI rápido                                           | medium    |
