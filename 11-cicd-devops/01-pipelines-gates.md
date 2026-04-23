# 11 · CI/CD · Pipelines y quality gates

> Pipelines de integración, linting, tests, seguridad, y control de calidad
> antes de merge.

---

## A. Pipelines

#### `CICD-PIPE-001` — Pipeline por PR con etapas fast-fail
**Severidad:** high · **Aplica a:** ci-cd

Cada PR dispara un pipeline que valida el cambio antes del merge, en etapas
ordenadas del más rápido al más lento.

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

**Verificar:**
- [ ] Lint en CI con la misma config que local (pre-commit idealmente).
- [ ] Formatter (prettier/black/etc.) falla si el código no está formateado.
- [ ] Typechecker (mypy/pyright/tsc/clippy/etc.) en strict mode.

---

#### `CICD-GATE-002` — Tests unit + integración obligatorios
**Severidad:** critical · **Aplica a:** ci-cd

Sin tests verdes, no hay merge.

(Cross con `TEST-STRAT-003`.)

**Verificar:**
- [ ] Tests unitarios y de integración corren en CI.
- [ ] Umbral de cobertura configurado.
- [ ] Tests flaky marcados como tales (no ignorados) y con issue abierto.

---

#### `CICD-GATE-003` — Análisis de seguridad
**Severidad:** high · **Aplica a:** ci-cd

SAST, SCA (dependency scanning) e IaC scanning corren en CI.

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

**Verificar:**
- [ ] Trivy/Grype/Snyk Container corre sobre la imagen final.
- [ ] Severidades altas/críticas fallan el build.
- [ ] Los ignores tienen fecha de revisión.

---

#### `CICD-GATE-005` — Tamaño de PR acotado (soft-gate)
**Severidad:** low · **Aplica a:** process

PRs gigantes son difíciles de revisar. Se promueve PRs pequeños.

**Verificar:**
- [ ] Convención documentada (ej: < 400 líneas cambiadas).
- [ ] PRs grandes se justifican o se dividen.
- [ ] CI puede alertar ante PRs muy grandes.

---

## C. Versionado y tags

#### `CICD-VER-001` — Versionado semántico
**Severidad:** medium · **Aplica a:** ci-cd

Los releases siguen SemVer (MAJOR.MINOR.PATCH) y los cambios se documentan.

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

**Verificar:**
- [ ] Imagen/paquete construido una vez por commit.
- [ ] Tag inmutable (ej: `v1.2.3` o `sha-...`).
- [ ] El deploy a prod usa el mismo tag testeado en staging.

---

## E. Developer experience

#### `CICD-DX-001` — Local parity con CI
**Severidad:** medium · **Aplica a:** process

Los checks de CI se pueden correr localmente (o con docker) antes de pushear.

**Verificar:**
- [ ] `make test`, `npm run ci`, script equivalente.
- [ ] Pre-commit/pre-push hooks opcionales (husky, pre-commit).
- [ ] `README` explica cómo correr todo.

---

#### `CICD-DX-002` — CI rápido (< 10 min ideal)
**Severidad:** medium · **Aplica a:** ci-cd

Feedback rápido aumenta la productividad.

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
| CICD-VER-001     | Versionado semántico                                | medium    |
| CICD-VER-002     | Conventional commits                                | low       |
| CICD-ENV-001     | Ambientes espejados                                 | high      |
| CICD-ENV-002     | Promoción de artefacto                              | high      |
| CICD-DX-001      | Local parity con CI                                 | medium    |
| CICD-DX-002      | CI rápido                                           | medium    |
