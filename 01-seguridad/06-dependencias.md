# 01 · Seguridad · Dependencias y supply chain

> Gestión de dependencias de terceros, escaneo de vulnerabilidades, integridad
> de builds y seguridad de contenedores.
>
> **Marcos de referencia:** OWASP A06:2021 · SLSA framework · CIS Docker Benchmark · NIST SSDF.

---

## A. Gestión de dependencias

#### `SEC-DEPS-001` — Dependencias fijadas y reproducibles
**Severidad:** high · **Tags:** `supply-chain` · **Aplica a:** backend · frontend

El proyecto se puede reconstruir con las mismas versiones exactas de dependencias
en cualquier momento.

**Dónde buscar:** raíz y subpaquetes: `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `pyproject.toml`, `poetry.lock`, `uv.lock`, `requirements*.txt`, `Pipfile.lock`, `Cargo.toml`, `Cargo.lock`, `go.sum`, `composer.lock`, `.github/workflows/**`, `.gitlab-ci.yml`, `Dockerfile`
**Patrones:**
- `["']\^?\*["']|["']latest["']`                                              # versión flotante en manifest
- `npm\s+install(?!\s+--frozen-lockfile)|yarn\s+install(?!\s+--frozen-lockfile)` # CI sin frozen
- `pip\s+install(?!.*--require-hashes).*-r\s+requirements`                    # pip sin require-hashes
- `RUN\s+(npm|yarn|pnpm)\s+install\b`                                         # Dockerfile install vs ci
- `~=|>=`                                                                      # rangos peligrosos en pyproject/requirements
**Señal de N/A:** repo sin gestor de paquetes (solo código fuente puro o assets estáticos).

**Verificar:**
- [ ] Existe un lock file commiteado (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `uv.lock`, `requirements.lock`, `Cargo.lock`, `go.sum`).
- [ ] El CI usa `--frozen-lockfile` / `npm ci` / `pip install --require-hashes` o equivalente.
- [ ] Las versiones declaradas en el manifest no usan rangos peligrosos (`*`, `latest`).

**Banderas rojas:**
- Instalación en CI con `npm install` en vez de `npm ci`.
- Dependencias declaradas con `*` o `latest`.
- Ausencia de lock file en repositorios productivos.

---

#### `SEC-DEPS-002` — Verificación de integridad en instalación
**Severidad:** high · **Tags:** `supply-chain` · **Aplica a:** backend · frontend

El gestor de paquetes verifica hashes o firmas de los artefactos descargados.

**Dónde buscar:** `package-lock.json`, `pnpm-lock.yaml`, `requirements*.txt`, `Pipfile.lock`, `**/.npmrc`, `**/pip.conf`, `**/poetry.toml`, `Dockerfile`, `.github/workflows/**`
**Patrones:**
- `pip\s+install\s+git\+https://[^@\s]+(?!@[a-f0-9]{40})`                     # git+https sin pin por commit
- `npm\s+install\s+\S+@latest`                                                # install @latest en build
- `"integrity"\s*:\s*"sha512-`                                                # integrity esperado en lockfile
- `--require-hashes`                                                           # flag esperado en pip
- `registry\s*=\s*https?://[^\s]+`                                            # registry custom — verificar trust
**Señal de N/A:** repo sin dependencias externas (solo stdlib).

**Verificar:**
- [ ] Se usa un lock file con hashes (`pip install --require-hashes`, `npm ci` con integrity, `cargo` con hashes).
- [ ] El registry de paquetes está configurado y solo permite orígenes confiables.
- [ ] Las dependencias privadas se instalan desde un registry interno autenticado.

**Banderas rojas:**
- Instalación desde URLs arbitrarias (`pip install git+https://...` sin pin por commit).
- `npm install package@latest` durante el build.

---

#### `SEC-DEPS-003` — Política de actualización documentada
**Severidad:** medium · **Aplica a:** backend · frontend

Hay un proceso y frecuencia para actualizar dependencias, no "cuando alguien se
acuerde".

**Dónde buscar:** `.github/dependabot.{yml,yaml}`, `.github/renovate.json`, `renovate.json`, `.mend/**`, `.github/workflows/**`, `**/SECURITY.md`, `**/CONTRIBUTING.md`
**Patrones:**
- `dependabot|renovate|snyk|mend\b`                                           # config de bot de updates
- `package-ecosystem|update-type`                                             # campos esperados de dependabot
- `schedule:\s*\n\s*interval:\s*['"]?(daily|weekly|monthly)`                  # cadencia esperada
**Señal de N/A:** ninguna (todo repo activo debe tener política de updates).

**Verificar:**
- [ ] Existe política de actualización (ej: revisión mensual + parches de seguridad inmediatos).
- [ ] Hay una herramienta automatizada abriendo PRs (Dependabot, Renovate, Mend).
- [ ] Los PRs de dependencias pasan por CI completo antes de merge.
- [ ] Los changelogs se revisan antes de mergear upgrades mayores.

---

#### `SEC-DEPS-004` — Escaneo automático de vulnerabilidades
**Severidad:** critical · **Tags:** `cwe-1035` · **Aplica a:** ci-cd

El pipeline escanea dependencias contra bases de vulnerabilidades conocidas (CVE,
GHSA, OSV) y bloquea/alerta ante CVEs críticos.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `**/Jenkinsfile`, `**/azure-pipelines.yml`, `**/bitbucket-pipelines.yml`, `package.json`, `pyproject.toml`
**Patrones:**
- `npm\s+audit|pnpm\s+audit|yarn\s+audit`                                     # JS audit
- `pip-audit|safety\s+check|trivy|grype|snyk\s+test|osv-scanner`              # auditores esperados
- `dependency-check|owasp-dependency-check`                                   # OWASP DC
- `actions/dependency-review-action`                                          # GH Action de review
- `--severity[\s=]+(critical|high)`                                           # threshold esperado
**Señal de N/A:** repo sin CI configurado (proyecto local sin pipelines automáticos).

**Verificar:**
- [ ] Hay un scanner (Dependabot Security, Snyk, pip-audit, npm audit, Trivy, OWASP Dependency-Check) corriendo en CI.
- [ ] El scanner también corre periódicamente (no solo en PRs).
- [ ] Hay política clara sobre severidades que bloquean el merge.
- [ ] Los vendor lock-ins (sin fix disponible) se documentan y se re-evalúan.

**Banderas rojas:**
- Pipelines sin escaneo de dependencias.
- Ignores de CVE sin justificación ni fecha de revisión.
- Alertas de seguridad antiguas sin atender.

---

#### `SEC-DEPS-005` — Dependencias mínimas y de proveedores confiables
**Severidad:** medium · **Tags:** `supply-chain` · **Aplica a:** backend · frontend

Se evalúa antes de añadir una dependencia nueva: ¿realmente la necesitamos? ¿el
mantenedor es confiable? ¿está activa?

**Dónde buscar:** `package.json`, `pyproject.toml`, `requirements*.txt`, `Cargo.toml`, `composer.json`, `**/CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE*`
**Patrones:**
- `"left-pad"|"is-odd"|"is-number"|"is-array"`                                # micro-deps clásicas
- `"moment"|"request"`                                                        # libs deprecadas conocidas
- `(?i)dependency.*(review|justification|rationale)`                          # plantilla PR mencionando review esperado
- `\*(sin patrones mecánicos — revisión humana)\*`                            # placeholder
**Señal de N/A:** repo sin dependencias externas (toda lógica con stdlib).

**Verificar:**
- [ ] Existe revisión de PRs que agregan dependencias nuevas (justificación en descripción del PR).
- [ ] Se evitan micro-dependencias triviales (left-pad effect) cuando son reemplazables por ~20 LOC propios.
- [ ] Dependencias críticas (cripto, auth) provienen de proyectos maduros y auditados.
- [ ] Las dependencias abandonadas (>1-2 años sin commits) se marcan para reemplazo.

**Banderas rojas:**
- Dependencia con 1 mantenedor anónimo y poca actividad usada en flujo de auth/crypto.
- Dependencias duplicadas que hacen lo mismo (ej: dos libs de fechas).

---

## B. SBOM y trazabilidad

#### `SEC-DEPS-010` — Generación de SBOM en el build
**Severidad:** medium · **Tags:** `slsa`, `sbom` · **Aplica a:** ci-cd

El pipeline genera un SBOM (Software Bill of Materials) que documenta qué
dependencias están en el artefacto final.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `**/Jenkinsfile`, `Dockerfile`, `**/Makefile`
**Patrones:**
- `syft\b|cyclonedx|spdx|cdxgen`                                              # generadores SBOM
- `--format[\s=]+(spdx|cyclonedx|cdx)|sbom-format`                            # formato SBOM
- `\.sbom\.(json|xml)|sbom\.(spdx|cdx)\.json`                                 # artefactos SBOM
**Señal de N/A:** lib/SDK sin artefactos binarios distribuidos (solo source publicado al registry público).

**Verificar:**
- [ ] SBOM en formato estándar (SPDX, CycloneDX) generado por cada release.
- [ ] SBOM publicado junto al artefacto (asset del release, o en registro).
- [ ] El SBOM incluye dependencias transitivas.

---

#### `SEC-DEPS-011` — Firma de artefactos y releases
**Severidad:** medium · **Tags:** `slsa`, `sigstore` · **Aplica a:** ci-cd · infra

Los artefactos publicados (contenedores, paquetes, binarios) se firman y la
firma se verifica al desplegar.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `**/Jenkinsfile`, `Dockerfile`, `**/release*.{yml,yaml,sh}`
**Patrones:**
- `cosign\s+(sign|verify)|sigstore`                                           # cosign/sigstore
- `gpg\s+(--sign|--verify)|gpg2`                                              # firma GPG
- `slsa-framework|generator-generic`                                          # SLSA generators
- `signature\s+verification|verifyAttestation`                                # verificación esperada
**Señal de N/A:** repo no produce releases versionados (servicio interno deployado siempre desde main).

**Verificar:**
- [ ] Los releases se firman (cosign, GPG, sigstore).
- [ ] El deploy verifica la firma antes de arrancar.
- [ ] Los tags de Git se firman en releases productivas.

---

## C. Dependencias transitivas y versiones sombra

#### `SEC-DEPS-020` — Control de dependencias transitivas
**Severidad:** medium · **Aplica a:** backend · frontend

Se audita el árbol completo (directas + transitivas), no solo las que declaramos.

**Dónde buscar:** `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `pyproject.toml`, `poetry.lock`, `Cargo.toml`
**Patrones:**
- `"overrides"\s*:\s*\{|"resolutions"\s*:\s*\{`                               # npm overrides / yarn resolutions
- `\[tool\.poetry\.dependencies\][\s\S]*?\[tool\.poetry\.group`               # Poetry constraints
- `\[patch\.crates-io\]`                                                       # Cargo patch
- `npm\s+ls|pnpm\s+why|cargo\s+tree`                                          # comandos esperados de auditoría
**Señal de N/A:** repo sin dependencias externas o solo dependencias directas sin transitivas.

**Verificar:**
- [ ] Los reportes de vulnerabilidades cubren dependencias transitivas.
- [ ] Hay un mecanismo para pinear overrides de versiones transitivas (npm `overrides`, Yarn `resolutions`, Poetry `~=`, etc.).
- [ ] Se revisan duplicados de versiones del mismo paquete en el lock file.

---

#### `SEC-DEPS-021` — Prevención de dependency confusion
**Severidad:** high · **Tags:** `supply-chain`, `typosquatting` · **Aplica a:** backend · frontend

Los paquetes privados tienen scope que evita que un atacante publique un paquete
homónimo en el registry público.

**Dónde buscar:** `package.json`, `**/.npmrc`, `**/pip.conf`, `**/poetry.toml`, `**/.yarnrc.yml`, `**/.pypirc`
**Patrones:**
- `"name"\s*:\s*"(?!@)[a-z][^"]*"`                                            # paquete sin scope (revisar si interno)
- `@[a-z0-9-]+/[a-z0-9-]+`                                                    # uso esperado de scope namespaced
- `registry\s*=\s*https?://(registry\.npmjs|pypi\.org)`                       # registry público — verificar prioridad
- `index-url\s*=\s*https?://[^\s]+`                                           # pip index custom
- `always-auth\s*=\s*true|@scope:registry\s*=`                                # auth esperada en registry interno
**Señal de N/A:** repo no publica paquetes ni consume paquetes internos (solo deps públicas).

**Verificar:**
- [ ] Paquetes internos bajo scope namespaced (`@org/pkg`, prefijo de grupo).
- [ ] `.npmrc`, `pip.conf` u otros apuntan al registry interno ANTES del público, o el público está deshabilitado para internos.
- [ ] No se publican paquetes privados accidentalmente al registry público (CI bloquea).

**Banderas rojas:**
- Paquetes internos sin scope compitiendo por el mismo nombre en registros públicos.
- Configuración que permite instalar cualquier paquete con el nombre del interno desde el registry público.

---

## D. Contenedores e infraestructura

#### `SEC-DEPS-030` — Imágenes base minimales y versionadas
**Severidad:** high · **Aplica a:** infra

Las imágenes Docker/OCI parten de bases oficiales con tag específico (no `latest`)
y preferiblemente minimal (distroless, alpine) cuando sea viable.

**Dónde buscar:** `**/Dockerfile*`, `**/Containerfile`, `docker-compose*.{yml,yaml}`, `**/k8s/**`
**Patrones:**
- `FROM\s+\S+:latest|FROM\s+\S+\s*$`                                          # FROM sin tag específico
- `FROM\s+ubuntu(:latest)?|FROM\s+debian(:latest)?`                           # base pesada sin pin
- `FROM\s+\S+@sha256:[a-f0-9]{64}`                                            # uso esperado de pin por digest
- `apt-get\s+install[^&]*&&\s*\\?$`                                           # install sin --no-install-recommends ni cleanup
- `(?i)distroless|alpine|chainguard|wolfi`                                    # bases minimales esperadas
**Señal de N/A:** repo sin contenedores (deploy directo a serverless/PaaS sin Dockerfile propio).

**Verificar:**
- [ ] Dockerfile usa tag fijo (idealmente digest: `image@sha256:...`).
- [ ] Se usa imagen minimal o distroless en la etapa final.
- [ ] Multi-stage build separa build-time de runtime (no dejar gcc, curl, tar en la imagen final).
- [ ] La imagen no incluye paquetes innecesarios (no `curl`, `wget`, `apt-get` en runtime salvo necesidad).

**Banderas rojas:**
- `FROM ubuntu:latest` sin pin.
- Imagen final con gigabytes de herramientas de build.

---

#### `SEC-DEPS-031` — Contenedor no corre como root
**Severidad:** high · **Tags:** `cis-docker` · **Aplica a:** infra

El proceso del contenedor corre como usuario no privilegiado.

**Dónde buscar:** `**/Dockerfile*`, `**/Containerfile`, `docker-compose*.{yml,yaml}`, `**/k8s/**/*.{yml,yaml}`
**Patrones:**
- `^USER\s+(\w+)`                                                              # USER esperado en Dockerfile (debe existir)
- `USER\s+root|USER\s+0\b`                                                     # USER root explícito
- `--privileged\b|privileged:\s*true`                                          # privileged true
- `runAsNonRoot:\s*false|runAsUser:\s*0`                                       # K8s securityContext root
- `allowPrivilegeEscalation:\s*true`                                          # K8s priv escalation
- `readOnlyRootFilesystem:\s*false`                                           # K8s rootfs writable
**Señal de N/A:** workload sin contenedor (Lambda zip, Cloud Function, binario standalone).

**Verificar:**
- [ ] `USER` no-root definido en el Dockerfile.
- [ ] El filesystem es read-only en runtime (`readOnlyRootFilesystem: true` en K8s).
- [ ] Capabilities reducidas (`drop: ALL`, añadir solo las necesarias).
- [ ] `allowPrivilegeEscalation: false`.

**Banderas rojas:**
- Ausencia de `USER` → container corre como root.
- `--privileged` en compose/K8s.

---

#### `SEC-DEPS-032` — Escaneo de imágenes en el pipeline
**Severidad:** high · **Aplica a:** ci-cd

Las imágenes se escanean antes de publicarse al registry.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `**/Jenkinsfile`, `**/azure-pipelines.yml`
**Patrones:**
- `trivy\s+(image|fs)|grype\b|docker\s+scout|snyk\s+container`                # escáneres esperados
- `aquasec/trivy-action|anchore/scan-action`                                  # GH Actions de escaneo
- `--severity\s+(CRITICAL|HIGH)`                                              # umbral de severidad
**Señal de N/A:** repo no produce imágenes de contenedor (sin Dockerfile ni pipeline de imagen).

**Verificar:**
- [ ] Escáner de imágenes (Trivy, Grype, Snyk Container, Docker Scout) corre en CI.
- [ ] Política clara sobre severidades bloqueantes.
- [ ] Se re-escanea periódicamente (vulnerabilidades nuevas contra imágenes ya publicadas).

---

#### `SEC-DEPS-033` — Secretos nunca en la imagen
**Severidad:** critical · **Aplica a:** infra

Los secretos no se copian, ENV-embeben, ni se arguments-embeben en la imagen.
Se inyectan en runtime.

**Dónde buscar:** `**/Dockerfile*`, `**/Containerfile`, `docker-compose*.{yml,yaml}`, `**/.dockerignore`
**Patrones:**
- `COPY\s+\.env\b|COPY\s+\.env\.\w+`                                          # COPY .env
- `ARG\s+\w*(KEY|SECRET|TOKEN|PASSWORD)\w*\s*=\s*\S+`                          # ARG con valor real
- `ENV\s+\w*(KEY|SECRET|TOKEN|PASSWORD)\w*=\S+`                                # ENV con secreto literal
- `--build-arg\s+\w*(KEY|SECRET|TOKEN|PASSWORD)`                               # build-arg de secreto
- `--mount=type=secret`                                                        # patrón seguro esperado (BuildKit)
**Señal de N/A:** repo sin Dockerfile (sin imágenes propias).

**Verificar:**
- [ ] No hay `COPY .env` ni `ARG API_KEY=...` con valor real.
- [ ] No se pasan secretos como `--build-arg` para que queden en capas.
- [ ] Los secretos se pasan con `--mount=type=secret` (BuildKit) o por runtime (env, volúmenes, vault).

**Banderas rojas:**
- `ENV DATABASE_URL=postgres://...` en Dockerfile.
- Secretos en `docker history <image>` visibles.

---

## E. Terceros embebidos en frontend

#### `SEC-DEPS-040` — Scripts externos con integridad (SRI)
**Severidad:** medium · **Tags:** `sri` · **Aplica a:** frontend

Los scripts y estilos cargados desde CDNs externos incluyen `integrity` (SRI).

**Dónde buscar:** `**/*.{html,htm,ejs,pug,hbs,jinja,j2,vue,jsx,tsx,svelte}`, `**/templates/**`, `**/views/**`, `**/public/index.html`
**Patrones:**
- `<script\s+[^>]*src\s*=\s*["']https?://[^"']+["'][^>]*>(?![\s\S]*integrity=)` # script externo sin integrity
- `<link\s+[^>]*href\s*=\s*["']https?://[^"']+["'][^>]*rel\s*=\s*["']stylesheet["'][^>]*>(?![\s\S]*integrity=)` # link externo sin integrity
- `cdn\.jsdelivr\.net.*@latest|unpkg\.com.*@latest|/dist/[\w.-]+\.js`         # versión flotante CDN
- `integrity\s*=\s*["']sha(256|384|512)-`                                      # patrón esperado
**Señal de N/A:** repo sin frontend HTML (API JSON pura, sin SSR/templates).

**Verificar:**
- [ ] `<script src="..." integrity="sha384-..." crossorigin="anonymous">`.
- [ ] Las versiones CDN son fijas, no `@latest`.
- [ ] Los orígenes CDN están en la allowlist del CSP.

---

#### `SEC-DEPS-041` — Tag managers y SDKs de terceros revisados
**Severidad:** medium · **Aplica a:** frontend

Analytics, chat, A/B testing SDKs: cada uno es superficie de ataque. Se revisan
y se limitan.

**Dónde buscar:** `**/*.{html,htm,ejs,jinja,vue,jsx,tsx,svelte}`, `**/templates/**`, `**/views/**`, `package.json`, `**/index.html`, `**/_app.{tsx,jsx}`
**Patrones:**
- `gtag\(\)|googletagmanager|analytics\.js|hotjar|fullstory|mixpanel|segment` # SDKs de analytics típicos
- `intercom|drift|crisp|tawk\.to|zendesk|freshchat`                           # SDKs de chat
- `optimizely|launchdarkly|split\.io|growthbook`                              # SDKs de A/B
- `<script\s+[^>]*src\s*=\s*["']https?://(?!.*integrity)`                     # script tercero sin SRI
**Señal de N/A:** la app no carga SDKs de terceros en el cliente.

**Verificar:**
- [ ] Lista documentada de terceros cargados en el frontend.
- [ ] Permisos y datos enviados a cada uno revisados.
- [ ] Se cargan tarde o se lazy-load cuando sea posible.
- [ ] Configuración del CSP contempla los orígenes.

---

## Checklist resumen

| ID                | Control                                               | Severidad |
| ----------------- | ----------------------------------------------------- | --------- |
| SEC-DEPS-001      | Dependencias fijadas y reproducibles                  | high      |
| SEC-DEPS-002      | Verificación de integridad                            | high      |
| SEC-DEPS-003      | Política de actualización                             | medium    |
| SEC-DEPS-004      | Escaneo automático de vulnerabilidades                | critical  |
| SEC-DEPS-005      | Dependencias mínimas y confiables                     | medium    |
| SEC-DEPS-010      | SBOM generado                                         | medium    |
| SEC-DEPS-011      | Firma de artefactos                                   | medium    |
| SEC-DEPS-020      | Control de transitivas                                | medium    |
| SEC-DEPS-021      | Prevención de dependency confusion                    | high      |
| SEC-DEPS-030      | Imágenes base minimales y pinned                      | high      |
| SEC-DEPS-031      | Contenedor no-root                                    | high      |
| SEC-DEPS-032      | Escaneo de imágenes                                   | high      |
| SEC-DEPS-033      | Secretos fuera de la imagen                           | critical  |
| SEC-DEPS-040      | Scripts externos con SRI                              | medium    |
| SEC-DEPS-041      | SDKs de terceros revisados                            | medium    |
