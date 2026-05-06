# 01 · Seguridad · Hardening de contenedores

> Configuración defensiva de imágenes OCI y workloads en Kubernetes:
> privilegios, recursos, red, secretos y superficie de ataque mínima.
>
> **Marcos de referencia:** CIS Docker Benchmark · CIS Kubernetes Benchmark · NSA/CISA Kubernetes Hardening Guide · NIST SP 800-190.

---

## A. Privilegios y usuario

#### `SEC-CONTAINER-001` — Contenedores sin root (USER no-root en Dockerfile)
**Severidad:** high · **Tags:** `container` `cwe-250` · **Aplica a:** infra · ci-cd

El proceso principal del contenedor corre como usuario no privilegiado. Un
contenedor root puede escalar privilegios al host si hay una vulnerabilidad en
el runtime.

**Dónde buscar:** `**/Dockerfile*`, `**/Containerfile`, `docker-compose*.{yml,yaml}`, `**/k8s/**/*.{yml,yaml}`, `**/helm/**/*.{yml,yaml}`
**Patrones:**
- `^USER\s+root\b|^USER\s+0\b`                                                 # USER root explícito
- `--privileged\b|privileged:\s*true`                                           # modo privilegiado
- `runAsUser:\s*0\b|runAsNonRoot:\s*false`                                      # K8s securityContext root
- `allowPrivilegeEscalation:\s*true`                                            # K8s escalación de privilegios
- `^USER\s+(?!root|0)\w+`                                                       # patrón correcto esperado
**Señal de N/A:** workload serverless sin contenedor propio (Lambda zip, Cloud Function).

**Verificar:**
- [ ] `USER <nonroot>` definido en el Dockerfile (o en el FROM de la imagen base distroless).
- [ ] `runAsNonRoot: true` y `runAsUser: <uid>` en el `securityContext` del pod/container en K8s.
- [ ] `allowPrivilegeEscalation: false` en todos los containers.
- [ ] `capabilities.drop: ["ALL"]` con adición solo de capabilities estrictamente necesarias.

**Banderas rojas:**
- Ausencia de `USER` en el Dockerfile → el container corre como root por defecto.
- `privileged: true` en docker-compose o manifests K8s.
- `allowPrivilegeEscalation: true` sin justificación.

---

#### `SEC-CONTAINER-002` — Filesystem de contenedor read-only donde aplique
**Severidad:** medium · **Tags:** `container` · **Aplica a:** infra

El filesystem raíz del contenedor es de solo lectura. Los atacantes que logren
ejecución de código no pueden escribir binarios ni modificar configuración.

**Dónde buscar:** `**/Dockerfile*`, `docker-compose*.{yml,yaml}`, `**/k8s/**/*.{yml,yaml}`, `**/helm/**/*.{yml,yaml}`
**Patrones:**
- `readOnlyRootFilesystem:\s*true`                                              # patrón correcto en K8s
- `readOnlyRootFilesystem:\s*false`                                             # explícitamente deshabilitado
- `read_only:\s*true`                                                           # docker-compose read_only
- `tmpfs:\s*\n\s+-\s+/tmp|mountPath.*tmp.*readOnly:\s*false`                   # tmpfs para writes temporales
**Señal de N/A:** imagen que necesita escribir en el FS raíz por diseño irrenunciable (ej: servidor de base de datos con volúmenes montados en raíz).

**Verificar:**
- [ ] `readOnlyRootFilesystem: true` en el securityContext del container.
- [ ] Los directorios que necesitan escritura usan `emptyDir` o `tmpfs` montados en paths específicos.
- [ ] La aplicación no asume poder escribir en paths del FS raíz en runtime.

**Banderas rojas:**
- `readOnlyRootFilesystem: false` sin justificación documentada.
- Aplicación que escribe logs o archivos temp directamente en `/` o `/app` sin volumen.

---

## B. Recursos y red

#### `SEC-CONTAINER-003` — Resource limits (CPU/memory) definidos en todo pod
**Severidad:** high · **Tags:** `container` `dos` `cwe-400` · **Aplica a:** infra

Cada container tiene `requests` y `limits` de CPU y memoria definidos. Sin
límites, un container puede consumir todos los recursos del nodo (DoS efectivo).

**Dónde buscar:** `**/k8s/**/*.{yml,yaml}`, `**/helm/**/*.{yml,yaml}`, `docker-compose*.{yml,yaml}`, `**/kustomization.yaml`
**Patrones:**
- `resources:\s*\{\s*\}`                                                        # resources vacío
- `limits:\s*\n(?!\s+cpu|\s+memory)`                                           # limits sin cpu ni memory
- `cpu:\s*["']?\d+m["']?|memory:\s*["']?\d+[MmGgKk]i?["']?`                   # patrón correcto esperado
- `--memory\s+\d+[mg]|--cpus\s+[\d.]+`                                         # docker run con límites
- `mem_limit:|cpus:`                                                            # docker-compose limits
**Señal de N/A:** entorno de desarrollo local con un solo proceso (sin riesgo de DoS multi-tenant).

**Verificar:**
- [ ] Todos los containers tienen `resources.requests` y `resources.limits` definidos.
- [ ] Los `limits` de memoria son razonables para el workload (no infinitos ni genéricos).
- [ ] Existe un `LimitRange` en los namespaces para forzar defaults si se omiten.
- [ ] Hay `ResourceQuota` por namespace que acota el total consumible.

**Banderas rojas:**
- Containers sin `resources` definidos en un cluster multi-tenant.
- `limits.memory: "32Gi"` para un microservicio que usa <512MiB.

---

#### `SEC-CONTAINER-004` — Network policies restrictivas en Kubernetes
**Severidad:** high · **Tags:** `container` `k8s` · **Aplica a:** infra

Los namespaces de producción tienen `NetworkPolicy` que deniegan todo el tráfico
por defecto y permiten solo las rutas necesarias (ingress y egress explícitos).

**Dónde buscar:** `**/k8s/**/*.{yml,yaml}`, `**/helm/**/*.{yml,yaml}`, `**/kustomization.yaml`, `**/network-policy*.{yml,yaml}`
**Patrones:**
- `kind:\s*NetworkPolicy`                                                       # presencia esperada de NetworkPolicy
- `podSelector:\s*\{\s*\}[\s\S]*?policyTypes`                                  # deny-all (selector vacío)
- `namespaceSelector:|podSelector:`                                             # selectores de tráfico permitido
- `ingress:\s*\[\]|egress:\s*\[\]`                                              # deny explícito de todo el tráfico
**Señal de N/A:** entorno sin Kubernetes (ECS, instancias EC2/VM con firewall externo, serverless).

**Verificar:**
- [ ] Existe un `NetworkPolicy` de deny-all (ingress y egress) como base en cada namespace productivo.
- [ ] Solo los pods que necesitan comunicarse tienen policies de allow explícitas.
- [ ] La policy de egress limita las salidas a internet a lo necesario.
- [ ] Se usa un CNI que soporte NetworkPolicy (Calico, Cilium, Weave).

**Banderas rojas:**
- Namespaces de producción sin ninguna NetworkPolicy (tráfico libre entre todos los pods).
- NetworkPolicy que permite `0.0.0.0/0` en egress sin restricción de puertos.

---

## C. Imágenes y secretos

#### `SEC-CONTAINER-005` — Imágenes base mínimas y actualizadas
**Severidad:** high · **Tags:** `container` `supply-chain` · **Aplica a:** infra · ci-cd

Las imágenes usan bases mínimas (distroless, Alpine, Chainguard) para reducir la
superficie de ataque, y se actualizan ante CVEs en la imagen base.

**Dónde buscar:** `**/Dockerfile*`, `**/Containerfile`, `.github/workflows/**`, `.gitlab-ci.yml`
**Patrones:**
- `FROM\s+ubuntu\b|FROM\s+debian\b|FROM\s+centos\b|FROM\s+fedora\b`            # bases pesadas sin justificación
- `FROM\s+\S+:latest\b`                                                         # tag mutable
- `FROM\s+(?:gcr\.io/distroless|cgr\.dev/chainguard|alpine)\b`                 # bases mínimas esperadas
- `trivy\s+image|grype\b|docker\s+scout|snyk\s+container`                      # escaneo de imagen en CI
- `apt-get\s+install\s+[^\\]+(?<!&&\s*rm\s+-rf\s+/var/lib/apt/lists/\*)`      # install sin cleanup
**Señal de N/A:** repo sin Dockerfile ni imágenes propias.

**Verificar:**
- [ ] La etapa final del Dockerfile usa una imagen base mínima (distroless, alpine, Chainguard o similar).
- [ ] Multi-stage build separa las herramientas de build de la imagen de runtime.
- [ ] Un escáner (Trivy, Grype, Snyk) corre sobre la imagen en CI y bloquea ante CVEs critical/high.
- [ ] Las imágenes base se actualizan periódicamente (Dependabot para Docker, Renovate).

**Banderas rojas:**
- `FROM ubuntu:20.04` con decenas de paquetes instalados en la imagen final.
- Pipeline sin escaneo de vulnerabilidades de imagen.
- Imagen con herramientas de build (gcc, make, curl) en producción sin necesidad.

---

#### `SEC-CONTAINER-006` — Secretos montados como volumes o secrets manager, no env vars
**Severidad:** high · **Tags:** `container` `cwe-798` · **Aplica a:** infra

Los secretos (contraseñas, tokens, claves) se inyectan al runtime via secretos
de Kubernetes o un secrets manager externo, nunca como variables de entorno
planas ni en la imagen.

**Dónde buscar:** `**/Dockerfile*`, `**/Containerfile`, `docker-compose*.{yml,yaml}`, `**/k8s/**/*.{yml,yaml}`, `**/helm/**/*.{yml,yaml}`, `**/.env*`
**Patrones:**
- `ENV\s+\w*(KEY|SECRET|TOKEN|PASSWORD|PASS|PWD|API_KEY)\w*=\S+`               # secreto en ENV de Dockerfile
- `value:\s*["'][A-Za-z0-9+/=]{20,}["']`                                      # valor literal largo en manifest (posible secreto)
- `- name:\s+\w*(KEY|SECRET|TOKEN|PASSWORD)\w*\s*\n\s+value:\s*\S+`           # env var con valor literal en K8s
- `secretKeyRef:|valueFrom:\s*\n\s+secretKeyRef:`                              # patrón correcto esperado
- `COPY\s+\.env\b`                                                             # .env copiado a la imagen
**Señal de N/A:** entorno de desarrollo local sin secrets manager (aceptable con `.env` ignorado en `.gitignore`).

**Verificar:**
- [ ] No hay secretos en variables `ENV` del Dockerfile con valores reales.
- [ ] Los manifests de K8s usan `secretKeyRef` o `envFrom.secretRef` para las credenciales.
- [ ] Los secretos se montan como volúmenes cuando la app los lee como archivos.
- [ ] Se usa un secrets manager externo (Vault, AWS Secrets Manager, GCP Secret Manager) con CSI driver o sidecar.
- [ ] `.env` está en `.dockerignore` y `.gitignore`.

**Banderas rojas:**
- `ENV DATABASE_URL=postgres://user:pass@host/db` en Dockerfile.
- Manifest de K8s con `value: "sk-prod-ABC123..."` en texto plano.
- `COPY .env /app/.env` en Dockerfile productivo.

---

## Checklist resumen

| ID                  | Control                                               | Severidad |
| ------------------- | ----------------------------------------------------- | --------- |
| SEC-CONTAINER-001   | Contenedores sin root (USER no-root)                  | high      |
| SEC-CONTAINER-002   | Filesystem read-only donde aplique                    | medium    |
| SEC-CONTAINER-003   | Resource limits definidos en todo pod                 | high      |
| SEC-CONTAINER-004   | Network policies restrictivas en Kubernetes           | high      |
| SEC-CONTAINER-005   | Imágenes base mínimas y actualizadas                  | high      |
| SEC-CONTAINER-006   | Secretos como volumes/secrets manager, no env vars    | high      |
