# 04 · Testing · Estrategia y cobertura

> Estrategia de tests, pirámide/trofeo de testing, cobertura, principios FIRST
> y AAA.
>
> **Marcos de referencia:** Testing Trophy (Kent C. Dodds) · FIRST (R. C. Martin) · Arrange-Act-Assert.

---

## A. Estrategia

#### `TEST-STRAT-001` — Mezcla balanceada entre unit, integración y E2E
**Severidad:** high · **Aplica a:** testing

El proyecto tiene una combinación que prioriza tests de integración (ROI alto)
sin descuidar unit tests y una base mínima de E2E.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx,jsx}`, `**/__tests__/**`, `**/test/**`, `**/tests/**`, `*.{test,spec}.py`, `**/cypress/**`, `**/playwright/**`, `**/e2e/**`
**Patrones:**
- *(sin patrones mecánicos — revisión humana del ratio entre carpetas y nombres de suites)*

**Señal de N/A:** repositorio sin ninguna carpeta o archivo de tests detectable (proyecto sin suite).

**Verificar:**
- [ ] Distribución razonable (ejemplo — ajustar al contexto): ~50-60% integración, ~25-30% unit, ~10-15% E2E, ~5% estáticos.
- [ ] No hay una sola categoría dominando al 90%.
- [ ] Las pruebas más lentas (E2E) están aisladas en su propia suite.

**Banderas rojas:**
- Solo unit tests con muchos mocks — pasan los tests, explota producción.
- Solo E2E — suite lenta y frágil, feedback tardío.

---

#### `TEST-STRAT-002` — Cobertura como métrica, no como objetivo
**Severidad:** medium · **Aplica a:** testing

Se mide cobertura; se exige un mínimo. Pero no se persigue un porcentaje a costa
de tests sin valor.

**Dónde buscar:** `jest.config.*`, `vitest.config.*`, `pytest.ini`, `pyproject.toml`, `.coveragerc`, `setup.cfg`, `**/.github/workflows/**`, `**/sonar-project.properties`
**Patrones:**
- `coverageThreshold`            # umbral configurado en jest/vitest
- `--cov-fail-under=\d+`         # umbral en pytest-cov
- `branches?\s*[:=]\s*\d+`       # umbral de branches
- `--coverage`                   # cobertura activa en CI
- `coverage-?(ignore|exclude)`   # exclusiones documentadas

**Señal de N/A:** ningún archivo de configuración de testing en el repo (sin herramienta de cobertura instalable).

**Verificar:**
- [ ] Hay umbral mínimo de cobertura configurado (ej: 70% líneas, 80% branches).
- [ ] Áreas críticas (auth, pagos, datos sensibles) tienen cobertura alta (≥ 90%).
- [ ] El reporte de cobertura aparece en PRs.
- [ ] Las excepciones a la cobertura están documentadas (código trivial, generated code).

**Banderas rojas:**
- 100% cobertura con todos los tests que llaman a la función sin assert.
- Solo se mide "líneas", nunca "branches".

---

#### `TEST-STRAT-003` — Tests corren en el pipeline y bloquean merges
**Severidad:** critical · **Aplica a:** ci-cd

Los PRs no se mergean sin tests verdes.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `azure-pipelines.yml`, `.circleci/config.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`
**Patrones:**
- `(npm|yarn|pnpm|pytest|go|cargo)\s+(test|run\s+test)`   # tests en CI
- `required_status_checks|branch_protection`              # protección de rama
- `it\.skip|xit\(|describe\.skip|test\.skip|@pytest\.mark\.skip`  # tests deshabilitados
- `it\.only|fit\(|describe\.only|test\.only`              # focused tests commiteados
- `continue-on-error:\s*true`                             # tests no bloqueantes

**Señal de N/A:** repo sin pipelines de CI configurados (sin carpetas `.github/workflows`, `.gitlab-ci.yml`, etc.).

**Verificar:**
- [ ] CI corre todos los tests en cada push al PR.
- [ ] Tests fallidos bloquean el merge (branch protection).
- [ ] El pipeline tiene etapas (fast fail: lint → unit → integración → E2E).
- [ ] Flaky tests se marcan y reparan, no se ignoran.

---

## B. Principios FIRST

#### `TEST-FIRST-001` — Fast: los tests son rápidos
**Severidad:** medium · **Aplica a:** testing

La suite que se corre localmente debe ser rápida (< 30 s para unit), o dejará
de ejecutarse.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `jest.config.*`, `vitest.config.*`, `pytest.ini`
**Patrones:**
- `setTimeout\(.*,\s*\d{4,}\)`            # sleeps largos en tests
- `time\.sleep\(\s*[1-9]\d*`              # sleeps en pytest
- `await\s+sleep\(\s*\d{3,}`              # awaits con delays
- `--maxWorkers|workers\s*[:=]|--parallel|-n\s+auto`  # paralelismo configurado
- `--testTimeout|timeout\s*[:=]\s*\d{5,}` # timeouts altos en tests

**Señal de N/A:** sin suite de tests medible o sin métricas de duración.

**Verificar:**
- [ ] Suite de unit corre en segundos.
- [ ] Suite de integración en minutos, no horas.
- [ ] Los tests paralelos cuando el framework lo permite.
- [ ] Se identifican y optimizan los tests más lentos.

---

#### `TEST-FIRST-002` — Independent: orden y aislamiento
**Severidad:** high · **Aplica a:** testing

Los tests no dependen del orden ni del estado dejado por otros.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/conftest.py`, `**/setup.ts`, `jest.config.*`
**Patrones:**
- `beforeAll\(`                              # setup compartido (verificar afterAll)
- `let\s+\w+\s*;[\s\S]{0,200}beforeEach`     # variables de módulo mutadas
- `randomize\s*[:=]\s*true|--random-order`   # orden aleatorio activo
- `process\.env\.\w+\s*=`                    # mutación de env globales en tests
- `global\.\w+\s*=`                          # estado global modificado

**Señal de N/A:** sin tests detectables.

**Verificar:**
- [ ] Cada test configura su propio estado.
- [ ] Cleanup automático al final (fixture con teardown, transacción que rollback).
- [ ] Cambiar el orden no rompe la suite (`pytest --random-order`, Jest `randomize: true`).

**Banderas rojas:**
- Test B falla al correr solo, pasa después de A.
- Fixtures con estado global compartido que se acumula.

---

#### `TEST-FIRST-003` — Repeatable: deterministas
**Severidad:** high · **Tags:** `flaky-tests` · **Aplica a:** testing

El mismo test con la misma versión de código da el mismo resultado siempre.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`, `**/conftest.py`
**Patrones:**
- `new\s+Date\(\)|Date\.now\(\)|datetime\.now\(\)|time\.time\(\)`  # tiempo real sin freeze
- `Math\.random\(\)|random\.\w+\(`         # aleatoriedad sin seed
- `crypto\.randomUUID|uuid\.uuid4`         # UUIDs no inyectables
- `setTimeout\(.*,\s*\d{3,}\)|time\.sleep`  # sleeps para sincronizar
- `fetch\(['"]http|axios\.\w+\(['"]http`   # llamadas a red externa sin mock

**Señal de N/A:** sin tests detectables.

**Verificar:**
- [ ] Tiempo, randomness y IDs se inyectan / mockean.
- [ ] No dependen de red externa sin mocks (o están marcados como integración externa).
- [ ] Timezone y locale se fijan.
- [ ] Flaky tests tienen issue y plazo para arreglar.

**Banderas rojas:**
- `time.sleep(5)` para "esperar" algo asíncrono → race condition en CI.
- Orden de serialización (diccionarios) esperado.
- Tests que pasan en mac y fallan en linux.

---

#### `TEST-FIRST-004` — Self-validating: pasa o falla, sin inspección manual
**Severidad:** high · **Aplica a:** testing

Los tests hacen asserts explícitos. No imprimen y esperan que el humano mire.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`
**Patrones:**
- `console\.(log|warn|info)\(.*\)`         # prints en lugar de asserts
- `print\(`                                # prints en tests python
- `expect\(.*\)\.toBeTruthy\(\)|toBeFalsy` # asserts débiles
- `it\(['"][^'"]+['"]\s*,\s*(?:async\s+)?\(\s*\)\s*=>\s*\{\s*\}\)`  # test vacío
- `assert\s+True\b|assert\s+1\b`           # asserts triviales

**Señal de N/A:** sin tests detectables.

**Verificar:**
- [ ] Todos los tests tienen al menos un assert.
- [ ] No hay tests que "validan" imprimiendo a stdout.
- [ ] Los mensajes de error de assert son útiles para diagnosticar.

---

#### `TEST-FIRST-005` — Timely: escritos junto al código
**Severidad:** medium · **Aplica a:** testing

Los tests se escriben con el código, no "después, cuando haya tiempo". Ese
tiempo nunca llega.

**Dónde buscar:** `**/*.{ts,js,tsx,py}`, `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `.github/PULL_REQUEST_TEMPLATE.md`, `CONTRIBUTING.md`
**Patrones:**
- *(sin patrones mecánicos — revisión humana del histórico de PRs y políticas)*

**Señal de N/A:** repo sin historial de PRs ni convenciones documentadas.

**Verificar:**
- [ ] PRs con código nuevo incluyen tests.
- [ ] Hay un proceso para exigir tests en code review.
- [ ] Bug fixes agregan test de regresión.

---

## C. AAA y naming

#### `TEST-AAA-001` — Patrón Arrange-Act-Assert claro
**Severidad:** low · **Aplica a:** testing

Cada test distingue las tres fases (con líneas en blanco o comentarios si es
útil).

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`
**Patrones:**
- `expect\([\s\S]{0,200}expect\([\s\S]{0,200}expect\(`  # múltiples asserts intercalados
- `//\s*(arrange|act|assert)|#\s*(arrange|act|assert)`  # secciones marcadas
- `it\(['"][^'"]{120,}['"]`               # nombre de test demasiado largo (varios comportamientos)

**Señal de N/A:** sin tests detectables.

**Verificar:**
- [ ] Fase de setup (arrange) al principio.
- [ ] Una acción principal (act) clara.
- [ ] Asserts al final (assert).
- [ ] Si hay demasiado setup, se extrae a fixture/factory.

**Banderas rojas:**
- Tests con asserts mezclados con setup.
- Tests que hacen 10 operaciones y verifican todas.

---

#### `TEST-AAA-002` — Un comportamiento por test
**Severidad:** medium · **Aplica a:** testing

Un test verifica un único comportamiento/expectativa. Múltiples assertions sobre
el mismo comportamiento están bien; verificar múltiples comportamientos no.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`
**Patrones:**
- `it\(['"][^'"]+\s+and\s+[^'"]+['"]`     # nombre con "and" → varios comportamientos
- `test\(['"][^'"]+\s+y\s+[^'"]+['"]`     # nombre con "y" en español
- `it\(['"][^'"]+,\s*[^'"]+['"]`          # nombre con coma listando comportamientos

**Señal de N/A:** sin tests detectables.

**Verificar:**
- [ ] El nombre del test describe un único comportamiento.
- [ ] Si el test tiene "and" en el nombre, se considera dividirlo.
- [ ] Falla uno, queda claro qué comportamiento se rompió.

---

#### `TEST-AAA-003` — Nombres descriptivos
**Severidad:** medium · **Aplica a:** testing

El nombre del test cuenta la historia: contexto, acción, expectativa.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`
**Patrones:**
- `(it|test)\(['"]test\d+['"]`            # nombres genéricos test1/test2
- `(it|test)\(['"](foo|bar|baz|works|it works)['"]`  # nombres sin sentido
- `def\s+test_(foo|bar|works|it_works)\b` # idem en pytest
- `(it|test)\(['"][^'"]{1,15}['"]`        # nombres muy cortos sin contexto

**Señal de N/A:** sin tests detectables.

**Verificar:**
- [ ] Patrón: `test_<cuando>_<haciendo_algo>_<espera_esto>`.
- [ ] Ejemplos:
  - `test_login_with_invalid_password_returns_401`.
  - `test_analizar_seccion_con_riesgo_alto_marca_como_critica`.
  - `test_upload_pdf_larger_than_limit_rejects_with_413`.
- [ ] Nada de `test1`, `test_foo`, `test_it_works`.

**Banderas rojas:**
- Nombres genéricos sin contexto ni expectativa.

---

## D. Casos

#### `TEST-CASE-001` — Happy path, bordes, errores
**Severidad:** high · **Aplica a:** testing

Cada unidad con lógica tiene tests para: escenario feliz, casos borde y errores.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`
**Patrones:**
- `describe\(['"][^'"]+['"]\s*,[\s\S]{0,500}\bit\(`   # describe con un solo it (probable falta de bordes)
- `(toThrow|raises|assertRaises|pytest\.raises)`     # tests de errores presentes
- `(empty|null|undefined|None|edge|boundary|invalid|limit)` # nombres que cubren bordes
- `\.each\(\[|parametrize`                            # tests parametrizados (cubren múltiples casos)

**Señal de N/A:** sin tests detectables o módulos sin lógica condicional.

**Verificar:**
- [ ] Caso feliz (los inputs más comunes funcionan).
- [ ] Bordes: vacío, uno, muchos; límites de rango; nulos/opcionales.
- [ ] Errores: inputs inválidos, dependencias fallando, timeouts.
- [ ] Property-based tests donde tenga sentido (hipótesis pequeñas sobre un dominio grande).

---

#### `TEST-CASE-002` — Regresión: bug arreglado viene con test
**Severidad:** high · **Aplica a:** testing

Cada bug reportado resulta en un test que lo reproduce antes de arreglarlo.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `CHANGELOG.md`
**Patrones:**
- `regression\s+(for|test)|#\d+`          # tests enlazados a issues
- `bug\s*[:#]?\s*\d+|issue\s*[:#]?\s*\d+` # referencia a bug fix
- `fixes?\s+#\d+|closes?\s+#\d+`          # mensaje de commit con fix
- `repro(duce|duction)?`                  # tests de reproducción

**Señal de N/A:** repo nuevo sin historial de bugs ni issues cerradas.

**Verificar:**
- [ ] PR de bugfix incluye test que falla en main y pasa con el fix.
- [ ] El test enlaza al issue (`# regression for #1234`).

---

#### `TEST-CASE-003` — Matriz de autorización cubierta
**Severidad:** high · **Tags:** `security-testing` · **Aplica a:** backend

Para endpoints autenticados, hay tests para: sin auth, auth válida, auth
insuficiente, cross-tenant.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`, `**/e2e/**`, `**/integration/**`
**Patrones:**
- `expect\([^)]*\.status\)\.(toBe|toEqual)\(401\)`  # test de 401
- `expect\([^)]*\.status\)\.(toBe|toEqual)\(403\)`  # test de 403
- `assert\s+.*status_code\s*==\s*(401|403)`         # idem en pytest
- `(without|sin|no)[\s_]auth|unauthorized`          # naming de tests sin auth
- `cross[\s_-]?tenant|other[\s_]user|different[\s_]tenant`  # tests cross-tenant

**Señal de N/A:** API completamente pública sin endpoints autenticados.

**Verificar:**
- [ ] 401 sin credenciales.
- [ ] 403 con credenciales insuficientes.
- [ ] 200 con credenciales correctas.
- [ ] Intentos cross-tenant bloqueados.

---

## E. Cobertura de código

#### `TEST-COV-001` — Herramienta de cobertura activa
**Severidad:** medium · **Aplica a:** ci-cd

Se genera reporte de cobertura en cada build.

**Dónde buscar:** `package.json`, `pyproject.toml`, `setup.cfg`, `pytest.ini`, `jest.config.*`, `vitest.config.*`, `.github/workflows/**`, `codecov.yml`, `.coveragerc`
**Patrones:**
- `(coverage|nyc|c8|istanbul|jacoco|tarpaulin|pytest-cov)` # herramienta instalada
- `--coverage|--cov(=|\s)`                # flag de cobertura
- `codecov|coveralls|sonarcloud|sonarqube` # servicio de tracking
- `lcov|cobertura|html-report|coverage-summary`  # formato de reporte
- `branches?\s*[:=]`                      # cobertura de branches medida

**Señal de N/A:** sin tests ni configuración de cobertura.

**Verificar:**
- [ ] Herramienta integrada (coverage.py/pytest-cov, Istanbul, JaCoCo, c8, tarpaulin).
- [ ] El reporte se publica como artefacto o comentario en PR.
- [ ] Se miden branches, no solo líneas.
- [ ] La cobertura histórica se trackea (codecov, coveralls, SonarQube).

---

#### `TEST-COV-002` — Cobertura por área de riesgo
**Severidad:** medium · **Aplica a:** testing

Las áreas críticas tienen umbral propio, superior al general.

**Dónde buscar:** `jest.config.*`, `vitest.config.*`, `pyproject.toml`, `.coveragerc`, `pytest.ini`, `sonar-project.properties`
**Patrones:**
- `coverageThreshold[\s\S]{0,500}(auth|payment|crypto|billing)` # umbral por path crítico
- `coveragePathIgnorePatterns|--cov-config|omit\s*=`             # exclusiones explícitas
- `(auth|payments?|crypto|billing|security)/[\s\S]{0,200}\d{2,3}` # path crítico con porcentaje
- `generated|__generated__|\.pb\.|migrations`                     # exclusión de generated code

**Señal de N/A:** repo sin áreas críticas claras (sin auth/pagos/crypto).

**Verificar:**
- [ ] `auth/`, `payments/`, `cryptography/` exigen ≥ 90%.
- [ ] Los handlers que exponen endpoints ≥ 80%.
- [ ] Código generado o trivial excluido explícitamente.

---

## Checklist resumen

| ID                | Control                                           | Severidad |
| ----------------- | ------------------------------------------------- | --------- |
| TEST-STRAT-001    | Mezcla balanceada                                 | high      |
| TEST-STRAT-002    | Cobertura como métrica                            | medium    |
| TEST-STRAT-003    | Tests en pipeline bloqueante                      | critical  |
| TEST-FIRST-001    | Fast                                              | medium    |
| TEST-FIRST-002    | Independent                                       | high      |
| TEST-FIRST-003    | Repeatable (no flaky)                             | high      |
| TEST-FIRST-004    | Self-validating                                   | high      |
| TEST-FIRST-005    | Timely                                            | medium    |
| TEST-AAA-001      | Arrange-Act-Assert                                | low       |
| TEST-AAA-002      | Un comportamiento por test                        | medium    |
| TEST-AAA-003      | Nombres descriptivos                              | medium    |
| TEST-CASE-001     | Happy path + bordes + errores                     | high      |
| TEST-CASE-002     | Regresión con test                                | high      |
| TEST-CASE-003     | Matriz de autorización cubierta                   | high      |
| TEST-COV-001      | Herramienta de cobertura                          | medium    |
| TEST-COV-002      | Cobertura por área de riesgo                      | medium    |
