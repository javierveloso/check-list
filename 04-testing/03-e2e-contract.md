# 04 · Testing · E2E, contract, performance y mutation

> Tests end-to-end, tests de contrato, de carga y mutation testing.

---

## A. E2E (end-to-end)

#### `TEST-E2E-001` — Cobertura de flujos críticos del usuario
**Severidad:** high · **Aplica a:** testing · frontend · backend

Los flujos principales tienen un test E2E que los ejercita de extremo a extremo.

**Dónde buscar:** `**/cypress/**`, `**/playwright/**`, `**/e2e/**`, `**/*.e2e.{ts,js}`, `**/tests/**/*.spec.ts`, `playwright.config.*`, `cypress.config.*`
**Patrones:**
- `(cy\.visit|page\.goto)\(['"]`           # navegación E2E
- `cy\.(login|loginAs)|page\.\w+\(['"].*login` # cobertura de login
- `(checkout|payment|upload|export)`       # flujos críticos por nombre
- `describe\(['"](critical|smoke|e2e)`     # suites etiquetadas
- `(cypress|playwright|@playwright/test|webdriverio|nightwatch)` # framework E2E presente

**Señal de N/A:** API-only sin frontend ni flujos navegables; o repo sin framework E2E (gap real).

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

**Dónde buscar:** `**/cypress/**`, `**/playwright/**`, `**/e2e/**`, `**/*.e2e.{ts,js}`, `**/*.spec.{ts,js}`
**Patrones:**
- `data-testid|data-test\b|data-cy`        # selectores estables (positivo)
- `getByRole\(|getByLabel\(|findByRole`    # queries por rol (positivo)
- `\.click\(\).*\[class\*=`                # selectores frágiles por clase
- `:nth-(child|of-type)\(`                 # selectores por posición
- `cy\.xpath\(|page\.locator\(['"]\/\/`    # XPath frágiles
- `cy\.contains\(['"][^'"]{30,}`           # contains con texto largo (frágil i18n)

**Señal de N/A:** sin tests E2E ni de UI.

**Verificar:**
- [ ] Se usan `data-testid` (o equivalente) para selectores.
- [ ] Se usan queries por rol/accesible name donde aplica (coincide con A11Y).
- [ ] Se evitan selectores por estructura (`:nth-child`, XPath frágil).

---

#### `TEST-E2E-003` — Datos de test aislados y reproducibles
**Severidad:** high · **Aplica a:** testing

Los E2E crean sus propios datos; no reutilizan usuarios compartidos entre runs.

**Dónde buscar:** `**/cypress/**`, `**/playwright/**`, `**/e2e/**`, `**/fixtures/**`
**Patrones:**
- `(admin|test|qa|user1|prueba)@`          # usuarios genéricos hardcodeados
- `cy\.task\(['"](createUser|seed)`        # creación dinámica (positivo)
- `(faker|nanoid|uuid)`                    # generación única por run
- `process\.env\.TEST_USER_PASSWORD`       # credenciales por env (revisar TTL)
- `cleanupAfter|teardown|afterEach\([\s\S]{0,200}delete` # cleanup explícito

**Señal de N/A:** sin tests E2E.

**Verificar:**
- [ ] Usuarios/datos se crean por ejecución (con cleanup o TTL).
- [ ] El estado inicial de la app no depende de seed frágil.
- [ ] Se puede correr la suite N veces sin intervención.

---

#### `TEST-E2E-004` — Manejo de flakiness
**Severidad:** high · **Tags:** `reliability` · **Aplica a:** testing

Los E2E son propensos a flakiness. Hay política clara y artefactos al fallar.

**Dónde buscar:** `**/cypress/**`, `**/playwright/**`, `**/e2e/**`, `playwright.config.*`, `cypress.config.*`, `.github/workflows/**`
**Patrones:**
- `cy\.wait\(\d+\)|page\.waitForTimeout\(\d+\)` # waits fijos (anti-pattern)
- `(waitFor|waitUntil|cy\.get\([^)]+\)\.should)` # waits explícitos (positivo)
- `retries\s*:\s*\d+|\.retry\(\d+\)`       # retry configurado
- `screenshot\s*:\s*['"](on|only-on-failure)|video\s*:\s*(on|true)` # artefactos al fallar
- `\.skip\b|\.only\b|describe\.skip|test\.skip` # tests deshabilitados/quarantine

**Señal de N/A:** sin tests E2E.

**Verificar:**
- [ ] Espera explícita (poll hasta condición) en vez de `sleep` fijo.
- [ ] Retry automático configurado con límite pequeño (1-2).
- [ ] Screenshot + video + logs del browser en cada fallo.
- [ ] Flaky tests se quarantenan y tienen issue abierto con plazo.

---

#### `TEST-E2E-005` — Idempotencia de la suite
**Severidad:** medium · **Aplica a:** testing

Correr la suite dos veces seguidas produce el mismo resultado.

**Dónde buscar:** `**/cypress/**`, `**/playwright/**`, `**/e2e/**`, `playwright.config.*`, `cypress.config.*`
**Patrones:**
- `(beforeAll|afterAll|after\(|before\(|beforeEach|afterEach)` # hooks de setup/cleanup
- `workers\s*:\s*\d+|--workers|fullyParallel\s*:\s*true` # paralelismo configurado
- `tenant|namespace|prefix|suffix|generateId` # aislamiento por run
- `cy\.task\(['"]cleanup|deleteUser|teardown`  # cleanup explícito
- `cy\.fixture\(['"]seed`                  # seeds globales (revisar)

**Señal de N/A:** sin tests E2E.

**Verificar:**
- [ ] No hay estado residual.
- [ ] Cleanup completo al final de cada test.
- [ ] Se puede ejecutar en paralelo sin colisionar (usuarios distintos, tenants distintos, namespaces).

---

## B. Tests de contrato

#### `TEST-CONTRACT-001` — Validación continua del contrato OpenAPI
**Severidad:** high · **Aplica a:** testing · api

El contrato OpenAPI se valida contra el código y contra los clientes.

**Dónde buscar:** `**/openapi*.{json,yaml,yml}`, `**/swagger*.{json,yaml,yml}`, `.github/workflows/**`, `**/*.{test,spec}.{ts,js,py}`
**Patrones:**
- `(schemathesis|dredd|prism|portman|openapi-validator)` # tools de validación
- `toMatchSchema|matchesOpenAPI|expect.*\.toMatchOpenApiSpec` # asserts contra OpenAPI
- `openapi:\s*['"]?3\.|swagger:\s*['"]?2\.` # contrato OpenAPI presente
- `examples?\s*:\s*\{`                     # ejemplos en el contrato
- `chai-openapi-response-validator|jest-openapi` # validadores en suite

**Señal de N/A:** sin contrato OpenAPI/Swagger publicado.

**Verificar:**
- [ ] El pipeline valida que el servidor responde conforme al schema (ejemplo: schemathesis, dredd).
- [ ] Un test falla si se agrega endpoint sin documentar o viceversa.
- [ ] Los ejemplos en el contrato se verifican como válidos.

---

#### `TEST-CONTRACT-002` — Pact / consumer-driven contract tests
**Severidad:** medium · **Aplica a:** testing

Para integraciones entre servicios internos, los consumidores publican sus
expectativas.

**Dónde buscar:** `**/pacts/**`, `**/contracts/**`, `**/*.pact.{ts,js,py}`, `package.json`, `pyproject.toml`
**Patrones:**
- `(@pact-foundation/pact|pactum|pact-python|pact-ruby)` # libs de Pact
- `new\s+Pact\(|PactV3\(`                  # consumer test
- `pact-broker|pactflow`                   # broker configurado
- `(provider|consumer)Verification`        # verificación de contrato

**Señal de N/A:** monolito sin integración entre servicios internos.

(Ver `02-api-diseno/04-versionado-contratos.md` `API-CONTRACT-002`.)

---

## C. Tests de propiedad y fuzz

#### `TEST-PROP-001` — Property-based testing en lógica no trivial
**Severidad:** medium · **Tags:** `property-testing` · **Aplica a:** testing

Para funciones con espacio de entrada grande (parsers, validators, operaciones
matemáticas), se usan tests basados en propiedades.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`, `**/parsers/**`, `**/validators/**`
**Patrones:**
- `(hypothesis|fast-check|jsverify|@fast-check/jest|proptest|quickcheck)` # libs property-based
- `fc\.(assert|property|forAll)|hypothesis\.given` # invocación de property tests
- `@given\(|@hypothesis|st\.(integers|text|lists)` # estrategias de hypothesis
- `parse|serialize|validate|encode|decode` # candidatos típicos

**Señal de N/A:** sin parsers, validators o lógica con espacio de entrada amplio.

**Verificar:**
- [ ] Uso de Hypothesis (Python), fast-check (JS), QuickCheck (Haskell/Scala), proptest (Rust) cuando aplica.
- [ ] Las propiedades son invariantes reales, no solo repetición.

**Ejemplo de propiedad:** `parse(serialize(x)) == x` para cualquier `x` válido.

---

#### `TEST-FUZZ-001` — Fuzz testing en superficies de parseo
**Severidad:** medium · **Tags:** `security-testing` · **Aplica a:** backend

Los parsers de formatos complejos (protobuf, JSON custom, binarios) pasan por
fuzzing para encontrar crashes y vulnerabilidades.

**Dónde buscar:** `**/fuzz/**`, `**/parsers/**`, `**/decoders/**`, `**/__fuzz__/**`, `.github/workflows/**`
**Patrones:**
- `(libfuzzer|atheris|jazzer|afl|cargo-fuzz|go-fuzz|FuzzedDataProvider)` # tools de fuzz
- `fn\s+fuzz_\w+|def\s+TestOneInput\b|FuzzTarget` # entrypoints de fuzz
- `corpus/|seeds/|fuzz_targets/`           # corpus presente
- `oss-fuzz|ClusterFuzz`                   # integración con fuzzing público

**Señal de N/A:** sin parsers de formatos complejos en el sistema (solo JSON estándar).

**Verificar:**
- [ ] Fuzz integrado (libFuzzer, atheris, jazzer, AFL++) en corpus representativo.
- [ ] Crashes se reproducen y se incorporan como tests de regresión.

---

## D. Performance y carga

#### `TEST-PERF-001` — Benchmarks para rutas críticas
**Severidad:** medium · **Aplica a:** testing · backend

Las rutas críticas tienen benchmarks y se detecta regresión.

**Dónde buscar:** `**/benchmarks/**`, `**/*.bench.{ts,js,py}`, `**/*_bench.go`, `**/benches/**`, `.github/workflows/**`
**Patrones:**
- `(pytest-benchmark|jmh|criterion|benchstat|tinybench|@vitest/bench|mitata)` # libs benchmark
- `bench\(['"]|@benchmark\b|func\s+Benchmark\w+` # benchmarks declarados
- `threshold|baseline|regression` # umbrales
- `benchmark[\s\S]{0,500}\.compare`        # comparativa baseline

**Señal de N/A:** sin rutas críticas con presupuesto de latencia explícito.

**Verificar:**
- [ ] Existe suite de benchmarks (pytest-benchmark, jmh, criterion, benchstat).
- [ ] Umbrales definidos; regresión > N% alerta en el PR.
- [ ] Los resultados se trackean en el tiempo.

---

#### `TEST-LOAD-001` — Tests de carga programados
**Severidad:** medium · **Aplica a:** testing

Antes de grandes releases, se corre carga contra el entorno de staging.

**Dónde buscar:** `**/load-tests/**`, `**/k6/**`, `**/locust/**`, `**/*.load.{js,ts,py}`, `Makefile`, `.github/workflows/**`
**Patrones:**
- `(import\s+.*\bk6\b|from\s+locust|gatling|wrk|artillery|ddosify)` # frameworks
- `vus\s*:|virtualUsers|users:\s*\d+`      # usuarios concurrentes
- `(p95|p99|p\(95\)|p\(99\))`              # SLOs de latencia
- `thresholds\s*:|check\(`                 # criterios de aprobación
- `ramp_up|stages\s*:|spawn_rate`          # escalonado de carga

**Señal de N/A:** producto interno con baja concurrencia y sin SLOs de carga.

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

**Dónde buscar:** `**/billing/**`, `**/auth/**`, `**/payments/**`, `stryker.conf.*`, `**/mutation*.{json,yaml}`, `pyproject.toml`, `package.json`
**Patrones:**
- `(stryker|mutmut|pitest|cosmic-ray|cargo-mutants|infection)` # tools de mutation
- `mutationScore|mutation_score|threshold` # configuración de score
- `@stryker-mutator/`                      # paquete instalado
- `--mutate|mutate:`                       # paths a mutar

**Señal de N/A:** sin módulos críticos identificados o equipo sin capacidad para correrlo.

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

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `.semgrep.yml`, `sonar-project.properties`, `.snyk`, `**/codeql/**`
**Patrones:**
- `(semgrep|codeql|snyk|sonarqube|sonarcloud|bandit|brakeman|gosec)` # SAST
- `(zap|owasp-zap|nuclei|burp|nikto|wapiti)` # DAST
- `(checkov|tfsec|kubesec|trivy|terrascan)` # IaC scanning
- `severity:\s*(critical|high|medium)`     # política de severidad
- `dependabot|renovate|snyk\.io/.*test`    # dependency scanning

**Señal de N/A:** sin pipelines de CI o sin código en repos públicos (project interno aislado).

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

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/security/**`, `**/integration/**`, `**/e2e/**`
**Patrones:**
- `\.status\)\.(toBe|toEqual)\(401\)`      # tests de auth requerida
- `\.status\)\.(toBe|toEqual)\(429\)`      # tests de rate limit
- `(X-Frame-Options|Content-Security-Policy|Strict-Transport-Security)` # headers verificados
- `cross[\s_-]?tenant|other[\s_]tenant|isolation` # aislamiento entre tenants
- `(bruteforce|brute-force|rate[_\s-]?limit).*test` # tests de fuerza bruta

**Señal de N/A:** sin endpoints autenticados ni multi-tenant.

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

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `**/cypress/**`, `**/playwright/**`, `lighthouserc*.{json,js}`, `.github/workflows/**`
**Patrones:**
- `(@axe-core/playwright|@axe-core/react|cypress-axe|jest-axe|pa11y|@axe-core/cli)` # libs a11y
- `lighthouseci|lhci|@lhci/cli|lighthouse-ci` # Lighthouse CI
- `axe\.run\(\)|injectAxe\(\)|checkA11y\(\)` # uso en tests
- `accessibility:\s*\d+|\bcategories.*accessibility` # presupuesto Lighthouse
- `aria-(label|describedby|labelledby)`    # uso de ARIA en componentes

**Señal de N/A:** API-only sin frontend; o producto interno sin requisitos de accesibilidad.

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
