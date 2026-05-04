# 04 · Testing · Unitarios, integración y fixtures

> Tests unitarios, de integración, fixtures, factories y test data.

---

## A. Tests unitarios

#### `TEST-UNIT-001` — Unidad clara y alcance pequeño
**Severidad:** medium · **Aplica a:** testing

Un unit test prueba una unidad lógica (función pura, método pequeño) en
aislamiento.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`, `**/unit/**`
**Patrones:**
- `request\(app\)|supertest|TestClient\(`   # HTTP en supuesto unit test
- `Test(ing)?Module\.create|@nestjs/testing` # framework completo levantado
- `new\s+(Pool|Client)\(|createConnection`  # conexiones reales en unit
- `axios\.\w+\(['"]http|fetch\(['"]http`    # red real en unit
- `fs\.(read|write)FileSync|open\(['"]\.\.?/` # acceso a disco real

**Señal de N/A:** repo sin tests categorizados como unit (carpeta `unit/` o convención).

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

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`
**Patrones:**
- `jest\.mock\(['"]\.\.?/`                  # mock de módulo propio (refactor candidate)
- `vi\.mock\(['"]\.\.?/`                    # idem vitest
- `monkeypatch\.setattr\(['"]\.\.?\w+\.`    # monkeypatch de módulo propio en pytest
- `mock\.patch\(['"]\w+\.(?!aws|google|stripe|openai)` # patch de módulo no-tercero

**Señal de N/A:** sin tests detectables o solo tests de integración.

**Verificar:**
- [ ] Las funciones de dominio/cálculo se testean con inputs/outputs directos.
- [ ] No se mockea lo que se está testeando.
- [ ] No se mockea código que uno controla (se refactoriza para no necesitarlo).

---

#### `TEST-UNIT-003` — Tests de lógica de errores
**Severidad:** high · **Aplica a:** testing

Los paths de error (excepciones, valores inválidos) se testean igual que los
felices.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`
**Patrones:**
- `expect\([^)]+\)\.(toThrow|rejects\.toThrow)` # tests de throw
- `pytest\.raises\(|assertRaises\(`             # tests de excepciones
- `\.toThrowError\(|\.toThrow\(['"]`            # verificación de mensaje de error
- `try\s*\{[\s\S]{0,200}fail\(`                 # patrón try/fail (anti-pattern pero indica intención)
- `(throws|raises|errors|fails|invalid|rejects)` # naming de tests de error

**Señal de N/A:** funciones sin paths de error (puramente totales).

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

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/integration/**`, `docker-compose*.yml`, `**/testcontainers/**`
**Patrones:**
- `jest\.mock\(['"](pg|mysql|prisma|typeorm|mongoose|redis|ioredis)['"]` # mock de driver BD
- `mock\.patch\(['"](sqlalchemy|psycopg|asyncpg|redis)\.` # idem python
- `testcontainers|TestContainer|@testcontainers` # uso de containers reales
- `pg-mem|sqlite[\s_]?memory|inmemory[\s_]?db` # BD fake
- `docker-compose[\.-]test|docker-compose\.ci`  # infra de tests

**Señal de N/A:** sin dependencias internas (BD/cache) en el sistema.

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

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/integration/**`, `**/conftest.py`, `**/setup.ts`
**Patrones:**
- `(beforeEach|afterEach|beforeAll|afterAll)` # hooks de setup/cleanup
- `TRUNCATE|DELETE FROM|DROP\s+(TABLE|SCHEMA)` # limpieza explícita
- `(BEGIN|START\s+TRANSACTION)[\s\S]{0,500}(ROLLBACK)` # rollback transaccional
- `seed\(|fixtures?\.load|loadFixtures`     # carga de seeds (revisar si globales)
- `process\.env\.\w+\s*=`                   # mutación de env entre tests

**Señal de N/A:** sin tests de integración detectables.

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

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/integration/**`, `**/e2e/**`, `**/api/**`
**Patrones:**
- `\.status\)\.(toBe|toEqual)\(20[01]\)`   # tests de happy path
- `\.status\)\.(toBe|toEqual)\(401\)`      # tests de auth
- `\.status\)\.(toBe|toEqual)\(40[34]\)`   # tests de 403/404
- `\.status\)\.(toBe|toEqual)\(42[29]\)`   # tests de validation/rate limit
- `(supertest|TestClient|request\(app\))`  # cliente HTTP de test
- `openapi|schema\.validate|toMatchSchema` # validación contra contrato

**Señal de N/A:** repo sin endpoints HTTP (solo CLI o lib pura).

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

**Dónde buscar:** `**/repositories/**`, `**/dao/**`, `**/*.repository.{test,spec}.ts`, `*repository*test*.py`, `**/integration/**`
**Patrones:**
- `(EXPLAIN|ANALYZE)\s+(SELECT|UPDATE|DELETE)` # uso de EXPLAIN en tests
- `UNIQUE\s+constraint|UniqueConstraintError|IntegrityError` # validación de constraints
- `ON\s+DELETE\s+CASCADE`                  # tests de cascade
- `jest\.mock\(['"](pg|prisma|typeorm)['"]` # antipatrón: mock del driver
- `repository\.\w+\(`                      # llamadas a repositorios (verificar si reales)

**Señal de N/A:** sin capa de repositorios o DAOs en el código.

**Verificar:**
- [ ] Repositorio con tests que crean, leen, actualizan, eliminan.
- [ ] Se validan: constraints de unicidad, cascade deletes, triggers, funciones stored si las hay.
- [ ] Se verifica el uso de índices (EXPLAIN) en queries críticas (opcional pero útil).

---

## C. Fixtures y factories

#### `TEST-FIX-001` — Fixtures reutilizables y declarativas
**Severidad:** medium · **Aplica a:** testing

Las fixtures están centralizadas, tienen scope claro y son baratas de construir.

**Dónde buscar:** `**/conftest.py`, `**/fixtures/**`, `**/__fixtures__/**`, `**/test-utils/**`, `**/setup.ts`, `**/jest.setup.*`
**Patrones:**
- `@pytest\.fixture\(scope=['"](session|module|function)['"]` # scope explícito
- `@pytest\.fixture(?!\(scope)`             # fixture sin scope (por defecto function)
- `beforeAll\(`                              # setup compartido en JS
- `export\s+(const|function)\s+(create|make|build)\w+`  # factories exportadas
- `import\s+\{[^}]+\}\s+from\s+['"][^'"]*fixtures` # reuso de fixtures

**Señal de N/A:** sin tests detectables.

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

**Dónde buscar:** `**/factories/**`, `**/__fixtures__/**`, `**/test-utils/**`, `*.factory.{ts,js}`, `*_factory.py`
**Patrones:**
- `(factory_boy|FactoryBot|fishery|model[_-]?factory|fakerjs|@faker-js/faker)` # libs de factories
- `class\s+\w+Factory\b|defineFactory\(`    # factories declaradas
- `faker\.(name|email|phone|address|company)` # datos realistas
- `\{\s*name:\s*['"]['"]|name:\s*['"]a+['"]` # datos pobres ("aaaa")
- `email:\s*['"][a-z]@[a-z]\.[a-z]+['"]`    # emails poco realistas

**Señal de N/A:** sin objetos de dominio (proyecto puramente funcional/CRUD trivial).

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

**Dónde buscar:** `**/fixtures/**`, `**/__fixtures__/**`, `**/test-data/**`, `**/testdata/**`, `.gitattributes`
**Patrones:**
- `filter=lfs`                              # uso de git-lfs en .gitattributes
- `\.(pdf|png|jpg|jpeg|zip|tar|gz)\s*$`     # binarios en fixtures
- `download(File|Asset)|fetchFixture`       # descargas en CI (anti-pattern)
- `generateTestPdf|createTestImage`         # generación determinística

**Señal de N/A:** sin necesidad de archivos binarios en tests (solo strings/JSON inline).

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

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/adapters/**`, `**/clients/**`, `**/ports/**`
**Patrones:**
- `monkeypatch\.setattr\(['"](httpx|requests|urllib|aiohttp)\.` # mock de librería HTTP
- `jest\.mock\(['"](aws-sdk|@aws-sdk|axios|node-fetch|googleapis)['"]` # mock profundo de librería
- `mock\.patch\(['"](boto3|google\.cloud|stripe)\.`  # idem python
- `interface\s+\w+(Client|Port|Adapter)\b` # interface alrededor de I/O
- `class\s+Fake\w+(Client|Adapter)\b`      # implementación fake del adaptador

**Señal de N/A:** sin librerías externas significativas para mockear.

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

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`, `**/test-utils/**`
**Patrones:**
- `jest\.fn\(\)|vi\.fn\(\)|sinon\.(stub|spy|mock)`  # creación de dobles
- `\.mockReturnValue|\.mockResolvedValue`          # stubs (valores fijos)
- `expect\([^)]+\)\.(toHaveBeenCalled|toHaveBeenCalledWith)` # mocks (verificación)
- `class\s+InMemory\w+|class\s+Fake\w+`            # fakes
- `jest\.spyOn\(|sinon\.spy`                       # spies

**Señal de N/A:** sin tests con dobles (solo tests puros).

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

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__mocks__/**`, `**/mocks/**`, `package.json`, `pyproject.toml`
**Patrones:**
- `(nock|msw|wiremock|mockttp|@mswjs/data)` # libs JS de mock HTTP
- `(respx|httpretty|responses|aioresponses|pytest-httpx)` # libs Python
- `setupServer\(|rest\.(get|post|put|delete)` # setup de MSW
- `nock\(['"]http`                          # interceptor nock
- `monkeypatch\.setattr\(['"](httpx|requests)` # antipatrón

**Señal de N/A:** sin código que haga llamadas HTTP salientes.

**Verificar:**
- [ ] Herramienta dedicada de mock HTTP activa en la suite.
- [ ] Se verifican: URL, método, headers relevantes, body.
- [ ] Errores (timeouts, 500, JSON inválido) también se simulan.

---

#### `TEST-MOCK-004` — Reloj, UUID, aleatorios controlables en tests
**Severidad:** medium · **Aplica a:** testing

Los tests que dependen de tiempo o aleatoriedad usan provider inyectable.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/__tests__/**`, `**/clock.{ts,py}`, `**/time-provider.*`
**Patrones:**
- `freezegun|freeze_time|sinon\.useFakeTimers|jest\.useFakeTimers|vi\.useFakeTimers` # libs de freeze
- `Date\.now\(\)|new\s+Date\(\)`            # uso directo de tiempo (no inyectado)
- `Math\.random\(\)|crypto\.randomUUID\(\)|uuid\.uuid4\(\)` # aleatoriedad/UUID directos
- `class\s+\w*Clock\b|interface\s+\w*Clock\b` # provider de tiempo inyectable
- `setTimeout\(.*,\s*\d+\)`                 # sleeps en tests para sincronizar

**Señal de N/A:** sin tests sensibles a tiempo o aleatoriedad.

**Verificar:**
- [ ] `freezegun`, `sinon.useFakeTimers`, `jest.useFakeTimers`, etc., cuando aplica.
- [ ] UUID determinístico en tests (secuencia fija, función inyectable).
- [ ] Tests no usan `sleep()` para sincronizar (usan eventos / awaits explícitos).

---

## E. Estructura y naming de tests

#### `TEST-STRUCT-001` — Organización espejo del código
**Severidad:** low · **Aplica a:** testing

Los tests reflejan la estructura de carpetas del código.

**Dónde buscar:** `**/*.{test,spec}.{ts,js,tsx}`, `*.{test,spec}.py`, `**/tests/**`, `**/__tests__/**`, `src/**`
**Patrones:**
- *(sin patrones mecánicos — comparación visual de árbol src/ vs tests/)*

**Señal de N/A:** repo sin estructura de carpetas (proyecto plano sin src/).

**Verificar:**
- [ ] `src/auth/login.py` → `tests/auth/test_login.py`.
- [ ] O co-locación: `src/auth/login.py` + `src/auth/login_test.py`.
- [ ] Uno u otro consistentemente, no ambos.

---

#### `TEST-STRUCT-002` — Helpers compartidos entre tests
**Severidad:** low · **Aplica a:** testing

Las utilidades comunes (login de prueba, creación de datos, asserts específicos)
viven en un módulo de tests.

**Dónde buscar:** `**/test-utils/**`, `**/test-helpers/**`, `**/tests/helpers/**`, `**/conftest.py`, `**/setup.ts`
**Patrones:**
- `export\s+(async\s+)?(function|const)\s+(loginAs|createUser|setupTest)` # helpers exportados
- `import\s+\{[^}]+\}\s+from\s+['"][^'"]*(test-utils|helpers|conftest)`  # reuso de helpers
- `function\s+loginAs\s*\([\s\S]{0,500}\}[\s\S]{0,200}function\s+loginAs` # duplicación
- `@pytest\.fixture[\s\S]{0,200}def\s+(login|create_user|auth_client)`    # fixtures comunes

**Señal de N/A:** suite muy pequeña (< 5 archivos de test).

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
