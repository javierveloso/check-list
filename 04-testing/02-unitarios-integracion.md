# 04 · Testing · Unitarios, integración y fixtures

> Tests unitarios, de integración, fixtures, factories y test data.

---

## A. Tests unitarios

#### `TEST-UNIT-001` — Unidad clara y alcance pequeño
**Severidad:** medium · **Aplica a:** testing

Un unit test prueba una unidad lógica (función pura, método pequeño) en
aislamiento.

**Verificar:**
- [ ] El test no cruza más de una clase/función.
- [ ] No toca base de datos, red, disco, ni tiempo real.
- [ ] Las dependencias no-triviales se sustituyen con dobles.
- [ ] Tiempo de ejecución típico < 10 ms por test.

**Banderas rojas:**
- "Unit test" que levanta el framework entero y hace HTTP.
- Unit tests que tardan segundos.

---

#### `TEST-UNIT-002` — Tests de funciones puras sin mocks
**Severidad:** medium · **Aplica a:** testing

Si la función es pura (sin I/O), no debería necesitar mocks. Si los necesita,
probablemente no es pura y hay un refactor pendiente.

**Verificar:**
- [ ] Las funciones de dominio/cálculo se testean con inputs/outputs directos.
- [ ] No se mockea lo que se está testeando.
- [ ] No se mockea código que uno controla (se refactoriza para no necesitarlo).

---

#### `TEST-UNIT-003` — Tests de lógica de errores
**Severidad:** high · **Aplica a:** testing

Los paths de error (excepciones, valores inválidos) se testean igual que los
felices.

**Verificar:**
- [ ] Cada excepción que la función puede lanzar tiene test.
- [ ] Los mensajes de error relevantes se verifican.
- [ ] Los wrappers que transforman excepciones se testean.

---

## B. Tests de integración

#### `TEST-INT-001` — Integración contra dependencias reales cuando sea viable
**Severidad:** high · **Aplica a:** testing

Las dependencias internas (BD, cache) se testean contra instancias reales,
no mocks — los mocks mienten.

**Verificar:**
- [ ] BD real (test container, testcontainers, ephemeral DB) en integración.
- [ ] Cache real (redis-like) cuando aplica.
- [ ] Solo se mockean APIs de terceros (no replicables localmente).
- [ ] Hay docker-compose / testcontainers que levanta la infra de tests.

**Banderas rojas:**
- "Integration tests" que mockean la BD con fakes custom.
- Mock de librería ORM que reescribe su comportamiento.

---

#### `TEST-INT-002` — Aislamiento entre tests de integración
**Severidad:** high · **Aplica a:** testing

Cada test de integración empieza desde un estado conocido y no contamina al
siguiente.

**Verificar:**
- [ ] Transacción que hace rollback al final de cada test (preferido).
- [ ] O: truncar tablas / crear DB por test (más lento pero válido).
- [ ] Los datos de prueba se crean en el test, no heredados de un seed global.
- [ ] Los tests se pueden correr en paralelo sin chocar (schemas, prefijos, etc.).

---

#### `TEST-INT-003` — Tests de endpoint cubriendo contratos
**Severidad:** high · **Aplica a:** testing · backend

Cada endpoint HTTP tiene test que cubre: happy path, auth, autorización,
validación, not found, rate limit, error interno.

**Verificar:**
- [ ] 200/201 para caso feliz con body verificado contra schema.
- [ ] 401 sin auth.
- [ ] 403 con auth pero sin permiso.
- [ ] 422/400 con payload inválido.
- [ ] 404 con recurso inexistente.
- [ ] 429 si aplica rate limit.
- [ ] 5xx no expone internals.
- [ ] El body y los headers se validan contra el contrato OpenAPI.

---

#### `TEST-INT-004` — Tests de BD validan queries reales
**Severidad:** medium · **Aplica a:** testing

Los tests de repositorios/DAOs ejercen las queries reales contra la BD real
(no mocks).

**Verificar:**
- [ ] Repositorio con tests que crean, leen, actualizan, eliminan.
- [ ] Se validan: constraints de unicidad, cascade deletes, triggers, funciones stored si las hay.
- [ ] Se verifica el uso de índices (EXPLAIN) en queries críticas (opcional pero útil).

---

## C. Fixtures y factories

#### `TEST-FIX-001` — Fixtures reutilizables y declarativas
**Severidad:** medium · **Aplica a:** testing

Las fixtures están centralizadas, tienen scope claro y son baratas de construir.

**Verificar:**
- [ ] Las fixtures comunes viven en un lugar común (conftest.py, setup files).
- [ ] Scope apropiado: function (por defecto), session (cuando se comparte sin mutación).
- [ ] Fixtures composables (uno usa otro).
- [ ] No hay duplicación de setup entre archivos de test.

---

#### `TEST-FIX-002` — Factories para objetos de dominio
**Severidad:** medium · **Aplica a:** testing

Los objetos de dominio se construyen con factories que dan valores por defecto
razonables y permiten overridear solo lo que importa.

**Verificar:**
- [ ] Factories (factory_boy, faker, Model Factories, FactoryBot) generan datos válidos.
- [ ] Los tests solo especifican los campos relevantes al comportamiento que verifican.
- [ ] Datos realistas (no "aaaa", sino valores con forma correcta).

**Banderas rojas:**
- Cada test crea objetos con `User(name="", email="x@x", age=0, ...)` repitiendo 15 campos.

---

#### `TEST-FIX-003` — Test data files: mínimos y versionados
**Severidad:** low · **Aplica a:** testing

Los archivos de test (PDFs, imágenes, payloads de referencia) están
versionados y son lo más pequeños posible.

**Verificar:**
- [ ] Directorio de fixtures (`tests/fixtures/`) con nombres descriptivos.
- [ ] Archivos commiteados (no se generan en CI) pero pequeños.
- [ ] Los binarios grandes se gestionan con git-lfs o se generan determinísticamente.

---

## D. Mocking

#### `TEST-MOCK-001` — Mockear en el borde, no la librería
**Severidad:** high · **Aplica a:** testing

Se mockea al nivel más alto/simple posible — el adaptador que envuelve la
librería, no la librería misma. Más resiliente a cambios de la librería.

**Verificar:**
- [ ] Existen interfaces/protocolos alrededor de I/O externo (`EmailClient`, `LLMClient`).
- [ ] En tests se pasa un doble de esa interface.
- [ ] No se mockean métodos internos de librerías.

**Banderas rojas:**
- `monkeypatch.setattr("httpx.AsyncClient.get", ...)`.
- `jest.mock("aws-sdk")` con reescritura profunda.

---

#### `TEST-MOCK-002` — Uso adecuado de mocks, fakes y spies
**Severidad:** medium · **Aplica a:** testing

Se distingue qué tipo de doble usar según el caso.

**Verificar:**
- [ ] **Stub**: devuelve valores fijos (para pasar al sistema bajo test).
- [ ] **Mock**: verifica que fue llamado cierta manera (para interacciones importantes).
- [ ] **Fake**: implementación simplificada real (in-memory repo).
- [ ] **Spy**: observa llamadas sin alterar comportamiento.
- [ ] No se abusa de mocks donde un fake/stub es más claro.

---

#### `TEST-MOCK-003` — Mocks de HTTP con librería dedicada
**Severidad:** medium · **Aplica a:** testing

Los tests que verifican interacción HTTP usan librería especializada
(respx, nock, WireMock, MSW), no monkey patch.

**Verificar:**
- [ ] Herramienta dedicada de mock HTTP activa en la suite.
- [ ] Se verifican: URL, método, headers relevantes, body.
- [ ] Errores (timeouts, 500, JSON inválido) también se simulan.

---

#### `TEST-MOCK-004` — Reloj, UUID, aleatorios controlables en tests
**Severidad:** medium · **Aplica a:** testing

Los tests que dependen de tiempo o aleatoriedad usan provider inyectable.

**Verificar:**
- [ ] `freezegun`, `sinon.useFakeTimers`, `jest.useFakeTimers`, etc., cuando aplica.
- [ ] UUID determinístico en tests (secuencia fija, función inyectable).
- [ ] Tests no usan `sleep()` para sincronizar (usan eventos / awaits explícitos).

---

## E. Estructura y naming de tests

#### `TEST-STRUCT-001` — Organización espejo del código
**Severidad:** low · **Aplica a:** testing

Los tests reflejan la estructura de carpetas del código.

**Verificar:**
- [ ] `src/auth/login.py` → `tests/auth/test_login.py`.
- [ ] O co-locación: `src/auth/login.py` + `src/auth/login_test.py`.
- [ ] Uno u otro consistentemente, no ambos.

---

#### `TEST-STRUCT-002` — Helpers compartidos entre tests
**Severidad:** low · **Aplica a:** testing

Las utilidades comunes (login de prueba, creación de datos, asserts específicos)
viven en un módulo de tests.

**Verificar:**
- [ ] `tests/helpers/`, `tests/utils/` o conftest central.
- [ ] No se copia-pega el mismo helper en decenas de archivos.

---

## Checklist resumen

| ID                | Control                                              | Severidad |
| ----------------- | ---------------------------------------------------- | --------- |
| TEST-UNIT-001     | Unidad clara y aislada                               | medium    |
| TEST-UNIT-002     | Funciones puras sin mocks                            | medium    |
| TEST-UNIT-003     | Lógica de errores testeada                           | high      |
| TEST-INT-001      | Integración con dependencias reales                  | high      |
| TEST-INT-002      | Aislamiento entre tests                              | high      |
| TEST-INT-003      | Endpoints con tests de contrato                      | high      |
| TEST-INT-004      | Queries reales validadas                             | medium    |
| TEST-FIX-001      | Fixtures reutilizables                               | medium    |
| TEST-FIX-002      | Factories con defaults razonables                    | medium    |
| TEST-FIX-003      | Fixtures mínimos y versionados                       | low       |
| TEST-MOCK-001     | Mockear en el borde                                  | high      |
| TEST-MOCK-002     | Uso adecuado de dobles                               | medium    |
| TEST-MOCK-003     | Mocks HTTP con librería dedicada                     | medium    |
| TEST-MOCK-004     | Reloj/UUID/aleatorios controlables                   | medium    |
| TEST-STRUCT-001   | Organización espejo                                  | low       |
| TEST-STRUCT-002   | Helpers compartidos                                  | low       |
