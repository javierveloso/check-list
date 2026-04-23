# 04 · Testing · E2E, contract, performance y mutation

> Tests end-to-end, tests de contrato, de carga y mutation testing.

---

## A. E2E (end-to-end)

#### `TEST-E2E-001` — Cobertura de flujos críticos del usuario
**Severidad:** high · **Aplica a:** testing · frontend · backend

Los flujos principales tienen un test E2E que los ejercita de extremo a extremo.

**Verificar:**
- [ ] Lista escrita de flujos críticos (login, checkout, upload+procesar, export).
- [ ] Cada flujo tiene un test E2E.
- [ ] La suite E2E corre en CI en el entorno más parecido a producción posible.
- [ ] Se ejecuta al menos en cada release (idealmente en cada PR con etiqueta).

**Banderas rojas:**
- "Nuestra cobertura E2E son los propios devs haciendo click manual".

---

#### `TEST-E2E-002` — Selectores estables (data-testid)
**Severidad:** medium · **Aplica a:** testing · frontend

Los selectores de tests E2E/UI no dependen de clases CSS, posición o texto
que cambian con frecuencia.

**Verificar:**
- [ ] Se usan `data-testid` (o equivalente) para selectores.
- [ ] Se usan queries por rol/accesible name donde aplica (coincide con A11Y).
- [ ] Se evitan selectores por estructura (`:nth-child`, XPath frágil).

---

#### `TEST-E2E-003` — Datos de test aislados y reproducibles
**Severidad:** high · **Aplica a:** testing

Los E2E crean sus propios datos; no reutilizan usuarios compartidos entre runs.

**Verificar:**
- [ ] Usuarios/datos se crean por ejecución (con cleanup o TTL).
- [ ] El estado inicial de la app no depende de seed frágil.
- [ ] Se puede correr la suite N veces sin intervención.

---

#### `TEST-E2E-004` — Manejo de flakiness
**Severidad:** high · **Tags:** `reliability` · **Aplica a:** testing

Los E2E son propensos a flakiness. Hay política clara y artefactos al fallar.

**Verificar:**
- [ ] Espera explícita (poll hasta condición) en vez de `sleep` fijo.
- [ ] Retry automático configurado con límite pequeño (1-2).
- [ ] Screenshot + video + logs del browser en cada fallo.
- [ ] Flaky tests se quarantenan y tienen issue abierto con plazo.

---

#### `TEST-E2E-005` — Idempotencia de la suite
**Severidad:** medium · **Aplica a:** testing

Correr la suite dos veces seguidas produce el mismo resultado.

**Verificar:**
- [ ] No hay estado residual.
- [ ] Cleanup completo al final de cada test.
- [ ] Se puede ejecutar en paralelo sin colisionar (usuarios distintos, tenants distintos, namespaces).

---

## B. Tests de contrato

#### `TEST-CONTRACT-001` — Validación continua del contrato OpenAPI
**Severidad:** high · **Aplica a:** testing · api

El contrato OpenAPI se valida contra el código y contra los clientes.

**Verificar:**
- [ ] El pipeline valida que el servidor responde conforme al schema (ejemplo: schemathesis, dredd).
- [ ] Un test falla si se agrega endpoint sin documentar o viceversa.
- [ ] Los ejemplos en el contrato se verifican como válidos.

---

#### `TEST-CONTRACT-002` — Pact / consumer-driven contract tests
**Severidad:** medium · **Aplica a:** testing

Para integraciones entre servicios internos, los consumidores publican sus
expectativas.

(Ver `02-api-diseno/04-versionado-contratos.md` `API-CONTRACT-002`.)

---

## C. Tests de propiedad y fuzz

#### `TEST-PROP-001` — Property-based testing en lógica no trivial
**Severidad:** medium · **Tags:** `property-testing` · **Aplica a:** testing

Para funciones con espacio de entrada grande (parsers, validators, operaciones
matemáticas), se usan tests basados en propiedades.

**Verificar:**
- [ ] Uso de Hypothesis (Python), fast-check (JS), QuickCheck (Haskell/Scala), proptest (Rust) cuando aplica.
- [ ] Las propiedades son invariantes reales, no solo repetición.

**Ejemplo de propiedad:** `parse(serialize(x)) == x` para cualquier `x` válido.

---

#### `TEST-FUZZ-001` — Fuzz testing en superficies de parseo
**Severidad:** medium · **Tags:** `security-testing` · **Aplica a:** backend

Los parsers de formatos complejos (protobuf, JSON custom, binarios) pasan por
fuzzing para encontrar crashes y vulnerabilidades.

**Verificar:**
- [ ] Fuzz integrado (libFuzzer, atheris, jazzer, AFL++) en corpus representativo.
- [ ] Crashes se reproducen y se incorporan como tests de regresión.

---

## D. Performance y carga

#### `TEST-PERF-001` — Benchmarks para rutas críticas
**Severidad:** medium · **Aplica a:** testing · backend

Las rutas críticas tienen benchmarks y se detecta regresión.

**Verificar:**
- [ ] Existe suite de benchmarks (pytest-benchmark, jmh, criterion, benchstat).
- [ ] Umbrales definidos; regresión > N% alerta en el PR.
- [ ] Los resultados se trackean en el tiempo.

---

#### `TEST-LOAD-001` — Tests de carga programados
**Severidad:** medium · **Aplica a:** testing

Antes de grandes releases, se corre carga contra el entorno de staging.

**Verificar:**
- [ ] Escenario de carga documentado (k6, locust, gatling, wrk).
- [ ] Se evalúan: latencia p95/p99, error rate, throughput sostenido.
- [ ] Hay criterios de aprobación claros.

---

## E. Mutation testing

#### `TEST-MUT-001` — Mutation testing en módulos críticos
**Severidad:** low · **Tags:** `test-quality` · **Aplica a:** testing

Para módulos de negocio críticos (billing, auth), se corre mutation testing
para verificar la calidad de los tests, no solo la cobertura.

**Verificar:**
- [ ] Herramienta (mutmut, stryker, pitest, cargo-mutants) disponible.
- [ ] Se corre al menos periódicamente en módulos priorizados.
- [ ] Mutation score se reporta.

**Nota:** mutation testing suele ser lento; no se corre en cada PR.

---

## F. Tests de seguridad automatizados

#### `TEST-SEC-001` — DAST/SAST en el pipeline
**Severidad:** high · **Aplica a:** ci-cd

Escaneos de seguridad automáticos corren en el pipeline o en cadencia.

**Verificar:**
- [ ] SAST (static) sobre el código (Semgrep, CodeQL, Snyk Code, Sonar).
- [ ] DAST (dynamic) contra staging (ZAP, Burp Community, Nuclei).
- [ ] IaC scanning si hay Terraform/K8s (Checkov, tfsec, kubesec).
- [ ] Resultados triados con política clara de severidad.

(Ver también `11-cicd-devops/02-quality-gates.md`.)

---

#### `TEST-SEC-002` — Tests para reglas específicas (auth, autorización)
**Severidad:** high · **Aplica a:** testing · backend

Los controles de seguridad del Checklist v2 se reflejan en tests automatizados
cuando es posible.

**Verificar:**
- [ ] Tests que verifican que los endpoints requieren auth (recorre rutas).
- [ ] Tests que verifican rate limiting activo en rutas de auth.
- [ ] Tests que verifican headers de seguridad en respuestas.
- [ ] Tests que verifican aislamiento entre tenants.

---

## G. Tests de accesibilidad

#### `TEST-A11Y-001` — Scanners automáticos en CI
**Severidad:** medium · **Aplica a:** testing · frontend

Los tests automatizados de accesibilidad (axe, Lighthouse CI, Pa11y) corren en
CI.

**Verificar:**
- [ ] Axe-core o similar en tests E2E / unit de componentes.
- [ ] Lighthouse CI con presupuesto de accesibilidad.
- [ ] Violations críticas fallan el build.

(Ver `09-accesibilidad/` para los controles de usuario.)

---

## Checklist resumen

| ID                  | Control                                            | Severidad |
| ------------------- | -------------------------------------------------- | --------- |
| TEST-E2E-001        | Cobertura de flujos críticos                       | high      |
| TEST-E2E-002        | Selectores estables                                | medium    |
| TEST-E2E-003        | Datos aislados y reproducibles                     | high      |
| TEST-E2E-004        | Manejo de flakiness                                | high      |
| TEST-E2E-005        | Idempotencia de la suite                           | medium    |
| TEST-CONTRACT-001   | Validación continua del contrato                   | high      |
| TEST-CONTRACT-002   | Consumer-driven contract (→ API)                   | medium    |
| TEST-PROP-001       | Property-based en lógica no trivial                | medium    |
| TEST-FUZZ-001       | Fuzz en superficies de parseo                      | medium    |
| TEST-PERF-001       | Benchmarks para rutas críticas                     | medium    |
| TEST-LOAD-001       | Tests de carga programados                         | medium    |
| TEST-MUT-001        | Mutation testing en módulos críticos               | low       |
| TEST-SEC-001        | DAST/SAST en pipeline                              | high      |
| TEST-SEC-002        | Tests para reglas de seguridad                     | high      |
| TEST-A11Y-001       | Scanners de a11y automáticos                       | medium    |
