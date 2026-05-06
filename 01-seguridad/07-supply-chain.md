# 01 · Seguridad · Supply Chain

> Integridad del pipeline de construcción y distribución de software: SBOM,
> firma de artefactos, provenance y protección de la cadena de suministro.
>
> **Marcos de referencia:** SLSA framework · NIST SSDF · CISA Secure Supply Chain · OpenSSF Scorecard.

---

## A. SBOM y trazabilidad

#### `SEC-SUPPLY-001` — SBOM generado y versionado con el artefacto
**Severidad:** high · **Tags:** `supply-chain` `slsa` · **Aplica a:** backend · frontend · infra

Cada artefacto publicado incluye un SBOM (Software Bill of Materials) en formato
estándar que lista todas las dependencias directas y transitivas.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `**/Jenkinsfile`, `**/azure-pipelines.yml`, `**/Makefile`, `**/Dockerfile*`
**Patrones:**
- `syft\b|cyclonedx|spdx|cdxgen|bom\b`                                         # generadores SBOM
- `--format[\s=]+(spdx|cyclonedx|cdx)|sbom-format`                             # formato SBOM
- `\.sbom\.(json|xml)|sbom\.(spdx|cdx)\.json|\.cdx\.json`                      # artefactos SBOM esperados
- `actions/attest-sbom|anchore/sbom-action`                                    # GH Actions de SBOM
**Señal de N/A:** lib/SDK que solo publica source al registry público sin artefactos binarios.

**Verificar:**
- [ ] El pipeline genera un SBOM en formato estándar (SPDX 2.x o CycloneDX 1.4+) en cada release.
- [ ] El SBOM incluye dependencias transitivas, no solo directas.
- [ ] El SBOM se publica junto al artefacto (asset del release, OCI attestation, o en el registry).
- [ ] El SBOM tiene versión y timestamp del build.

**Banderas rojas:**
- Pipeline de release sin paso de generación de SBOM.
- SBOM que lista solo dependencias directas.

---

#### `SEC-SUPPLY-002` — Artefactos firmados digitalmente (cosign/sigstore)
**Severidad:** high · **Tags:** `supply-chain` `slsa` · **Aplica a:** ci-cd · infra

Los artefactos publicados (imágenes OCI, paquetes, binarios) se firman y la
firma se verifica en el deploy.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `**/Jenkinsfile`, `**/release*.{yml,yaml,sh}`, `**/Makefile`
**Patrones:**
- `cosign\s+(sign|verify|attest)|sigstore`                                      # cosign/sigstore
- `gpg\s+(--sign|--detach-sign|--verify)|gpg2\s+--sign`                        # firma GPG
- `slsa-framework/slsa-github-generator`                                        # SLSA generator
- `actions/attest|attest-build-provenance`                                      # GitHub Attestations
- `COSIGN_EXPERIMENTAL|SIGSTORE_`                                               # vars de entorno cosign
**Señal de N/A:** repo sin releases versionados ni artefactos publicados a un registry.

**Verificar:**
- [ ] Las imágenes OCI o paquetes se firman (cosign, GPG, Sigstore) en el pipeline de release.
- [ ] El proceso de deploy verifica la firma antes de arrancar el workload.
- [ ] Los tags de Git se firman en releases productivas (`git tag -s`).
- [ ] La clave privada de firma está en un secrets manager, no en el repo.

**Banderas rojas:**
- Pipeline de release sin paso de firma.
- Clave de firma hardcodeada en el workflow.
- Deploy que no verifica la firma antes de correr la imagen.

---

## B. Integridad del pipeline CI/CD

#### `SEC-SUPPLY-003` — Imágenes base verificadas por digest, no por tag
**Severidad:** critical · **Tags:** `supply-chain` `container` · **Aplica a:** infra · ci-cd

Los `FROM` en Dockerfiles y las referencias a imágenes base usan digest SHA256
inmutable, no tags mutables como `latest` o `v1.2`.

**Dónde buscar:** `**/Dockerfile*`, `**/Containerfile`, `docker-compose*.{yml,yaml}`, `.github/workflows/**`, `**/k8s/**/*.{yml,yaml}`, `**/helm/**`
**Patrones:**
- `FROM\s+\S+:latest\b`                                                         # FROM :latest
- `FROM\s+[\w./:-]+(?<!@sha256:[a-f0-9]{64})\s*$`                              # FROM sin digest
- `image:\s+\S+:latest\b`                                                       # image: latest en compose/k8s
- `FROM\s+\S+@sha256:[a-f0-9]{64}`                                              # patrón correcto esperado
**Señal de N/A:** repo sin contenedores propios (deploy a PaaS/serverless sin Dockerfile).

**Verificar:**
- [ ] Todos los `FROM` usan digest: `FROM ubuntu@sha256:abc123...`.
- [ ] El tag puede coexistir como referencia legible pero el digest es el que ancla.
- [ ] Las imágenes en manifests de K8s/Helm también usan digest en producción.
- [ ] Hay un proceso (Dependabot, Renovate) que actualiza los digests periódicamente.

**Banderas rojas:**
- `FROM ubuntu:latest` o `FROM node:20` sin digest en Dockerfiles productivos.
- `image: nginx:latest` en manifests de Kubernetes de producción.

---

#### `SEC-SUPPLY-004` — Pipeline de CI protegido contra script injection
**Severidad:** critical · **Tags:** `supply-chain` `cwe-78` · **Aplica a:** ci-cd

Los workflows de CI no interpolan directamente variables de eventos externos
(títulos de PR, nombres de ramas, body de issues) en comandos shell.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `**/Jenkinsfile`, `**/azure-pipelines.yml`, `**/bitbucket-pipelines.yml`
**Patrones:**
- `run:[\s\S]*?\$\{\{[^}]*github\.(event\.pull_request\.(title|body|head\.ref)|head\.ref|ref_name)[^}]*\}\}`  # interpolación directa en run
- `echo\s+"\$\{\{\s*github\.event\.[^}]+\}\}"`                                 # echo de evento en shell
- `run:.*\$\{\{\s*inputs\.\w+\s*\}\}`                                          # input interpolado directamente en run
- `env:\s*\n\s+\w+:\s*\$\{\{\s*github\.event\.[^}]*\}\}`                       # patrón seguro via env var
**Señal de N/A:** repo sin CI configurado.

**Verificar:**
- [ ] Los valores de eventos externos se asignan a variables de entorno y se referencian via `$VAR`, nunca via `${{ }}` directamente en `run:`.
- [ ] Los inputs de workflows se validan antes de usarse en comandos.
- [ ] No hay `run: echo "${{ github.event.pull_request.title }}"` ni equivalentes.

**Banderas rojas:**
- `run: git checkout ${{ github.head.ref }}` sin sanitizar.
- Interpolación directa de `github.event.issue.body` en comandos shell.

---

#### `SEC-SUPPLY-005` — Actions/scripts de CI fijados a commit hash
**Severidad:** high · **Tags:** `supply-chain` · **Aplica a:** ci-cd

Las GitHub Actions de terceros y scripts externos referencian un commit hash
específico, no una etiqueta o rama mutable.

**Dónde buscar:** `.github/workflows/**`, `.github/actions/**`
**Patrones:**
- `uses:\s+\S+@v\d+(?!\.\d)`                                                   # uses: @vN sin hash (tag mayor mutable)
- `uses:\s+\S+@main|uses:\s+\S+@master`                                        # uses: @main/@master
- `uses:\s+\S+@[a-f0-9]{40}`                                                   # patrón correcto esperado
- `uses:\s+\S+@v\d+\.\d+\.\d+`                                                 # tag semver (aceptable con revisión)
**Señal de N/A:** repo sin GitHub Actions (solo GitLab CI, Jenkins u otro sistema sin este mecanismo).

**Verificar:**
- [ ] Todas las `uses:` de terceros referencian un commit hash de 40 caracteres.
- [ ] Las acciones propias (del mismo org) pueden usar tags si el repo es de confianza.
- [ ] Hay un proceso (Dependabot para Actions, Renovate) que actualiza los hashes periódicamente.

**Banderas rojas:**
- `uses: actions/checkout@main`.
- `uses: third-party/action@v3` sin comentario con el hash equivalente.

---

## C. Revisión y gobernanza

#### `SEC-SUPPLY-006` — Revisión humana de PRs que modifican dependencias
**Severidad:** medium · **Tags:** `supply-chain` · **Aplica a:** process · ci-cd

Los cambios en lockfiles, manifests de dependencias e imágenes base pasan por
revisión humana antes del merge.

**Dónde buscar:** `.github/CODEOWNERS`, `.github/PULL_REQUEST_TEMPLATE*`, `.github/workflows/**`, `.github/dependabot.{yml,yaml}`, `renovate.json`
**Patrones:**
- `CODEOWNERS.*package(-lock)?\.json|CODEOWNERS.*requirements|CODEOWNERS.*Dockerfile` # owners de archivos de deps
- `auto-merge:\s*true|auto_merge`                                               # auto-merge habilitado (revisar si hay review requerida)
- `required-reviewers?:\s*\d+`                                                 # reviewers requeridos en branch protection
- `package(-lock)?\.json|pnpm-lock\.yaml|yarn\.lock|poetry\.lock|Cargo\.lock`   # archivos de lock (presencia esperada)
**Señal de N/A:** repo personal sin colaboradores, con una sola persona haciendo todos los cambios.

**Verificar:**
- [ ] Los archivos de lockfile y manifests tienen owners definidos en CODEOWNERS.
- [ ] Branch protection requiere al menos 1 reviewer humano para PRs que modifican dependencias.
- [ ] El auto-merge de Dependabot/Renovate solo aplica a parches de bajo riesgo (patch/minor), no a majors.
- [ ] El CI completo corre sobre PRs de dependencias antes del merge.

**Banderas rojas:**
- Auto-merge sin revisión en dependencias con acceso a producción.
- Sin CODEOWNERS para lockfiles.

---

#### `SEC-SUPPLY-007` — Provenance SLSA nivel 2 o superior
**Severidad:** medium · **Tags:** `supply-chain` `slsa` · **Aplica a:** ci-cd · infra

Los artefactos tienen provenance verificable que acredita cómo y desde dónde
fueron construidos, siguiendo el framework SLSA.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `**/Jenkinsfile`
**Patrones:**
- `slsa-framework/slsa-github-generator`                                        # generador SLSA oficial
- `actions/attest-build-provenance`                                             # GH Attestations
- `provenance:\s*true|generate-provenance`                                      # flags de provenance
- `predicate-type.*slsa\.dev/provenance`                                        # predicado SLSA en attestation
**Señal de N/A:** repo interno sin artefactos publicados externamente ni compliance regulatorio de supply chain.

**Verificar:**
- [ ] El pipeline genera provenance SLSA (nivel 2: build en CI, nivel 3: build hermético).
- [ ] El provenance se adjunta al artefacto (OCI attestation, bundle Sigstore).
- [ ] El provenance incluye: repo origen, ref, workflow, inputs, digest del artefacto.
- [ ] El consumer puede verificar el provenance antes de usar el artefacto.

**Banderas rojas:**
- Artefactos publicados a registries externos sin ningún provenance adjunto.
- Builds que no son reproducibles ni auditables.

---

## Checklist resumen

| ID              | Control                                               | Severidad |
| --------------- | ----------------------------------------------------- | --------- |
| SEC-SUPPLY-001  | SBOM generado y versionado con el artefacto           | high      |
| SEC-SUPPLY-002  | Artefactos firmados digitalmente                      | high      |
| SEC-SUPPLY-003  | Imágenes base verificadas por digest                  | critical  |
| SEC-SUPPLY-004  | Pipeline protegido contra script injection            | critical  |
| SEC-SUPPLY-005  | Actions/scripts de CI fijados a commit hash           | high      |
| SEC-SUPPLY-006  | Revisión humana de PRs de dependencias                | medium    |
| SEC-SUPPLY-007  | Provenance SLSA nivel 2 o superior                    | medium    |
