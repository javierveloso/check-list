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

**Verificar:**
- [ ] SBOM en formato estándar (SPDX, CycloneDX) generado por cada release.
- [ ] SBOM publicado junto al artefacto (asset del release, o en registro).
- [ ] El SBOM incluye dependencias transitivas.

---

#### `SEC-DEPS-011` — Firma de artefactos y releases
**Severidad:** medium · **Tags:** `slsa`, `sigstore` · **Aplica a:** ci-cd · infra

Los artefactos publicados (contenedores, paquetes, binarios) se firman y la
firma se verifica al desplegar.

**Verificar:**
- [ ] Los releases se firman (cosign, GPG, sigstore).
- [ ] El deploy verifica la firma antes de arrancar.
- [ ] Los tags de Git se firman en releases productivas.

---

## C. Dependencias transitivas y versiones sombra

#### `SEC-DEPS-020` — Control de dependencias transitivas
**Severidad:** medium · **Aplica a:** backend · frontend

Se audita el árbol completo (directas + transitivas), no solo las que declaramos.

**Verificar:**
- [ ] Los reportes de vulnerabilidades cubren dependencias transitivas.
- [ ] Hay un mecanismo para pinear overrides de versiones transitivas (npm `overrides`, Yarn `resolutions`, Poetry `~=`, etc.).
- [ ] Se revisan duplicados de versiones del mismo paquete en el lock file.

---

#### `SEC-DEPS-021` — Prevención de dependency confusion
**Severidad:** high · **Tags:** `supply-chain`, `typosquatting` · **Aplica a:** backend · frontend

Los paquetes privados tienen scope que evita que un atacante publique un paquete
homónimo en el registry público.

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

**Verificar:**
- [ ] Escáner de imágenes (Trivy, Grype, Snyk Container, Docker Scout) corre en CI.
- [ ] Política clara sobre severidades bloqueantes.
- [ ] Se re-escanea periódicamente (vulnerabilidades nuevas contra imágenes ya publicadas).

---

#### `SEC-DEPS-033` — Secretos nunca en la imagen
**Severidad:** critical · **Aplica a:** infra

Los secretos no se copian, ENV-embeben, ni se arguments-embeben en la imagen.
Se inyectan en runtime.

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

**Verificar:**
- [ ] `<script src="..." integrity="sha384-..." crossorigin="anonymous">`.
- [ ] Las versiones CDN son fijas, no `@latest`.
- [ ] Los orígenes CDN están en la allowlist del CSP.

---

#### `SEC-DEPS-041` — Tag managers y SDKs de terceros revisados
**Severidad:** medium · **Aplica a:** frontend

Analytics, chat, A/B testing SDKs: cada uno es superficie de ataque. Se revisan
y se limitan.

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
