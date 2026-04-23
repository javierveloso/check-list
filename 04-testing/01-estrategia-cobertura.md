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

**Verificar:**
- [ ] Suite de unit corre en segundos.
- [ ] Suite de integración en minutos, no horas.
- [ ] Los tests paralelos cuando el framework lo permite.
- [ ] Se identifican y optimizan los tests más lentos.

---

#### `TEST-FIRST-002` — Independent: orden y aislamiento
**Severidad:** high · **Aplica a:** testing

Los tests no dependen del orden ni del estado dejado por otros.

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

**Verificar:**
- [ ] Todos los tests tienen al menos un assert.
- [ ] No hay tests que "validan" imprimiendo a stdout.
- [ ] Los mensajes de error de assert son útiles para diagnosticar.

---

#### `TEST-FIRST-005` — Timely: escritos junto al código
**Severidad:** medium · **Aplica a:** testing

Los tests se escriben con el código, no "después, cuando haya tiempo". Ese
tiempo nunca llega.

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

**Verificar:**
- [ ] El nombre del test describe un único comportamiento.
- [ ] Si el test tiene "and" en el nombre, se considera dividirlo.
- [ ] Falla uno, queda claro qué comportamiento se rompió.

---

#### `TEST-AAA-003` — Nombres descriptivos
**Severidad:** medium · **Aplica a:** testing

El nombre del test cuenta la historia: contexto, acción, expectativa.

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

**Verificar:**
- [ ] Caso feliz (los inputs más comunes funcionan).
- [ ] Bordes: vacío, uno, muchos; límites de rango; nulos/opcionales.
- [ ] Errores: inputs inválidos, dependencias fallando, timeouts.
- [ ] Property-based tests donde tenga sentido (hipótesis pequeñas sobre un dominio grande).

---

#### `TEST-CASE-002` — Regresión: bug arreglado viene con test
**Severidad:** high · **Aplica a:** testing

Cada bug reportado resulta en un test que lo reproduce antes de arreglarlo.

**Verificar:**
- [ ] PR de bugfix incluye test que falla en main y pasa con el fix.
- [ ] El test enlaza al issue (`# regression for #1234`).

---

#### `TEST-CASE-003` — Matriz de autorización cubierta
**Severidad:** high · **Tags:** `security-testing` · **Aplica a:** backend

Para endpoints autenticados, hay tests para: sin auth, auth válida, auth
insuficiente, cross-tenant.

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

**Verificar:**
- [ ] Herramienta integrada (coverage.py/pytest-cov, Istanbul, JaCoCo, c8, tarpaulin).
- [ ] El reporte se publica como artefacto o comentario en PR.
- [ ] Se miden branches, no solo líneas.
- [ ] La cobertura histórica se trackea (codecov, coveralls, SonarQube).

---

#### `TEST-COV-002` — Cobertura por área de riesgo
**Severidad:** medium · **Aplica a:** testing

Las áreas críticas tienen umbral propio, superior al general.

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
