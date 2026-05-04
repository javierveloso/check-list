# 02 · API · Versionado, contratos y documentación

> Estrategias de versionado, compatibilidad retroactiva, deprecation y
> documentación con OpenAPI.
>
> **Marcos de referencia:** SemVer · Google API Evolution Guide · OpenAPI 3.1.

---

## A. Estrategia de versionado

#### `API-VER-001` — Versión explícita y estable
**Severidad:** high · **Aplica a:** api

La API declara una versión accesible y se compromete a mantener compatibilidad
dentro de esa versión.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/main.{ts,js,py,go}`, `**/app.{ts,js,py,go}`, `openapi*.{yaml,json}`
**Patrones:**
- `(get|post|put|delete|patch)\(['"]/v\d+/`     # ruta con /vN/ (positivo)
- `setGlobalPrefix\(['"]/?api/?v\d+`     # NestJS prefix con versión (positivo)
- `app\.use\(['"]/api/v\d+`     # Express con versión (positivo)
- `Accept[\s\S]{0,200}application/vnd\.[a-z]+\.v\d+`     # versionado por Accept header (positivo)
- `(get|post|put|delete|patch)\(['"]/(?!v\d+)[a-z]`     # ruta sin /vN/ (banderas)
- `info:\s*\n\s*version:\s*['"]?\d+\.\d+\.\d+`     # OpenAPI version declarada (positivo)
**Señal de N/A:** no hay handlers HTTP ni `openapi*` en el repo.

**Verificar:**
- [ ] Versión en la URL (`/v1`, `/v2`) o en header (`Accept: application/vnd.example.v1+json`), elegida y documentada.
- [ ] La versión se incrementa solo ante cambios breaking.
- [ ] La política de versionado está escrita en el repositorio.

**Banderas rojas:**
- API sin versión.
- Versiones que cambian semántica sin aviso a clientes.

---

#### `API-VER-002` — Breaking changes identificados y documentados
**Severidad:** high · **Aplica a:** api

El equipo tiene clara la lista de cambios que son breaking y los evita salvo
con un plan de migración.

**Dónde buscar:** `.github/workflows/**`, `**/CHANGELOG*`, `**/CONTRIBUTING*`, `**/docs/api/**`, `openapi*.{yaml,json}`
**Patrones:**
- `oasdiff|openapi-diff`     # herramienta de diff de contrato (positivo)
- `breaking[-_]change`     # marcador de breaking change (positivo)
- `additionalProperties:\s*true`     # OpenAPI: additionalProperties true (riesgo de breaking)
- `required:\s*\n(?:\s*-\s*\w+\n){5,}`     # campo requerido nuevo (cambio breaking típico)
**Señal de N/A:** no hay `openapi*` ni workflows de CI con diff de contrato.

**Ejemplos de **breaking**:**
- Eliminar campo de response.
- Renombrar campo.
- Cambiar tipo de campo.
- Agregar campo requerido a request.
- Cambiar semántica / default de un campo.
- Eliminar o renombrar endpoint.
- Cambiar código de estado para el mismo escenario.

**Ejemplos de **non-breaking**:**
- Agregar endpoint nuevo.
- Agregar campo opcional a request (con default).
- Agregar campo a response.
- Agregar valor nuevo a enum (si los clientes lo tratan como unknown, ver `API-VER-005`).

**Verificar:**
- [ ] Cada PR que toca API explicita si es breaking o no.
- [ ] Los breaking no se liberan sin versión nueva o feature flag + migración.

---

#### `API-VER-003` — Convivencia de versiones con ciclo de vida acotado
**Severidad:** medium · **Aplica a:** backend

Cuando sale una versión nueva, la anterior sigue funcionando por un tiempo
definido. No convivir "para siempre" todas las versiones.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/middleware/**`, `**/handlers/**`, `**/docs/api/**`
**Patrones:**
- `setHeader\(['"]Deprecation['"]`     # header Deprecation (positivo)
- `setHeader\(['"]Sunset['"]`     # header Sunset RFC 8594 (positivo)
- `setHeader\(['"]Link['"][\s\S]{0,200}rel=['"]deprecation['"]`     # Link rel deprecation (positivo)
- `(get|post|put|delete|patch)\(['"]/v[0-9]+/[\s\S]{0,500}(get|post|put|delete|patch)\(['"]/v[0-9]+/`     # múltiples versiones coexistiendo (verificar política)
**Señal de N/A:** solo existe una versión de la API en el repo (búsqueda de `/v\d+/` retorna ≤1 prefijo único).

**Verificar:**
- [ ] Política clara: ej. "v_n-1 se mantiene 12 meses tras salir v_n".
- [ ] Plan documentado de sunsetting.
- [ ] Headers `Deprecation`, `Sunset` (RFC 8594) en respuestas de versiones deprecadas.

---

#### `API-VER-004` — Deprecation visible al cliente
**Severidad:** medium · **Aplica a:** api

Los endpoints o campos deprecados lo informan al cliente.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/middleware/**`, `openapi*.{yaml,json}`
**Patrones:**
- `setHeader\(['"]Deprecation['"]\s*,`     # header emitido (positivo)
- `setHeader\(['"]Sunset['"]\s*,`     # Sunset emitido (positivo)
- `deprecated:\s*true`     # OpenAPI deprecated (positivo)
- `@Deprecated\b|@deprecated\b`     # decorator/JSDoc deprecated (positivo)
- `// TODO:?\s*deprecate|# TODO:?\s*deprecate`     # deprecación pendiente
**Señal de N/A:** no hay endpoints/campos marcados como deprecados ni intención de deprecar (búsqueda de `deprecated|Deprecation` no devuelve nada).

**Verificar:**
- [ ] Header `Deprecation: true` y `Sunset: <HTTP-date>` en endpoints deprecados.
- [ ] Enlace a docs de migración (`Link: <url>; rel="deprecation"`).
- [ ] OpenAPI marca el endpoint/field como `deprecated: true`.
- [ ] Se envían notificaciones a clientes que aún llaman (logs o emails al owner).

---

#### `API-VER-005` — Cliente y servidor tolerantes a campos desconocidos
**Severidad:** medium · **Tags:** `postel` · **Aplica a:** api · backend · frontend

**Servidor** rechaza campos desconocidos si fue la decisión (modo strict) o
los ignora de forma documentada. **Cliente** tolera campos nuevos en respuestas
sin romperse.

**Dónde buscar:** `**/dto/**`, `**/schemas/**`, `**/validators/**`, `**/services/**`, `**/clients/**`
**Patrones:**
- `\.strict\(\)`     # zod/yup strict (positivo si se busca rechazar)
- `extra\s*=\s*['"]?(forbid|allow|ignore)['"]?`     # Pydantic Config (positivo)
- `additionalProperties:\s*false`     # JSON Schema strict (positivo)
- `additionalProperties:\s*true`     # JSON Schema permisivo
- `Object\.keys\(\s*\w+\s*\)\.length\s*===\s*\d+`     # cliente asume cantidad fija de claves (frágil)
- `assert\s+set\(\w+\.keys\(\)\)\s*==\s*\{`     # asserción exacta de keys (frágil)
**Señal de N/A:** no hay DTOs/schemas ni clientes consumidores en el repo.

**Verificar:**
- [ ] Política documentada: strict (rechazar) o tolerant (ignorar) en inputs.
- [ ] Clientes no hacen assertions de "solo estos campos vienen" en responses.
- [ ] Enums desconocidos se manejan con `default` o valor "unknown" en cliente.

---

## B. Contratos y OpenAPI

#### `API-DOC-001` — OpenAPI como fuente de verdad
**Severidad:** high · **Aplica a:** api

El esquema OpenAPI (o equivalente) describe completamente la API. Se mantiene
en el repositorio y se valida en CI.

**Dónde buscar:** `openapi*.{yaml,json}`, `swagger*.{yaml,json}`, `**/api-spec*`, `.github/workflows/**`, `**/contract*`
**Patrones:**
- `openapi:\s*['"]?3\.[01]`     # versión OpenAPI 3.x (positivo)
- `additionalProperties:\s*true`     # schema laxo
- `type:\s*object\s*$(?![\s\S]{0,200}properties:)`     # object sin properties
- `\$ref:\s*['"]#/components/schemas/`     # uso de refs (positivo)
- `(spectral|swagger-cli|openapi-validator|prism)`     # validadores de contrato en CI (positivo)
**Señal de N/A:** no hay archivos `openapi*`/`swagger*` y la API es interna/no documentada.

**Verificar:**
- [ ] Existe `openapi.yaml` / `openapi.json` en el repo.
- [ ] Todo endpoint está documentado con `summary`, `description`, parámetros, body, responses y códigos.
- [ ] Los schemas de request/response están definidos (no `any`/`object` vacío).
- [ ] CI valida la coherencia entre el código y el contrato (o el contrato genera el código).

**Banderas rojas:**
- Endpoints productivos ausentes del contrato.
- Schemas con `additionalProperties: true` sin límites.

---

#### `API-DOC-002` — Ejemplos reales en el contrato
**Severidad:** medium · **Aplica a:** api

Cada endpoint incluye al menos un ejemplo de request y response, y ejemplos de
errores comunes.

**Dónde buscar:** `openapi*.{yaml,json}`, `swagger*.{yaml,json}`, `**/api-spec*`, `**/docs/**`
**Patrones:**
- `examples?:\s*\n`     # bloque examples en OpenAPI (positivo)
- `example:\s*['"\{\[]`     # campo example (positivo)
- `responses:\s*\n[\s\S]{0,500}['"]?4\d\d['"]?:[\s\S]{0,500}example`     # ejemplo de error 4xx (positivo)
**Señal de N/A:** no hay `openapi*`/`swagger*` en el repo.

**Verificar:**
- [ ] Todos los endpoints con body o response compleja tienen `examples`.
- [ ] Los ejemplos son válidos contra el schema (test de contrato).
- [ ] Los errores 4xx más comunes tienen ejemplo documentado.

---

#### `API-DOC-003` — Portal de documentación publicado
**Severidad:** medium · **Aplica a:** api

Los consumidores (internos o externos) tienen acceso a docs navegables
actualizadas.

**Dónde buscar:** `**/main.{ts,js,py,go}`, `**/app.{ts,js,py,go}`, `**/routes/**`, `**/middleware/**`, `.github/workflows/**`
**Patrones:**
- `SwaggerModule\.setup\(`     # NestJS Swagger (positivo)
- `swagger-ui-express|swaggerUi\.setup`     # Express Swagger UI
- `redoc|stoplight|rapidoc`     # otros portales (positivo)
- `setup_swagger|FastAPI\([^)]*docs_url`     # Python docs (positivo)
- `SwaggerModule\.setup\([^)]*\)(?![\s\S]{0,300}(NODE_ENV|production|auth))`     # Swagger sin guard de entorno
**Señal de N/A:** no hay `openapi*`/`swagger*` ni framework con docs UI en el repo.

**Verificar:**
- [ ] Swagger UI / Redoc / Stoplight desplegado para cada entorno (dev, staging).
- [ ] En producción, el acceso está controlado si la API es privada.
- [ ] Los docs se regeneran automáticamente en cada release.

---

#### `API-DOC-004` — Autenticación documentada
**Severidad:** medium · **Aplica a:** api

El contrato documenta cómo autenticarse (esquemas, scopes, flujos OAuth).

**Dónde buscar:** `openapi*.{yaml,json}`, `swagger*.{yaml,json}`, `**/api-spec*`
**Patrones:**
- `securitySchemes:\s*\n`     # bloque securitySchemes (positivo)
- `security:\s*\n\s*-`     # security aplicado a operación (positivo)
- `(bearerAuth|oauth2|apiKey|openIdConnect)`     # esquemas declarados (positivo)
- `scopes:\s*\n`     # scopes OAuth listados (positivo)
**Señal de N/A:** no hay `openapi*` en el repo o la API no requiere autenticación.

**Verificar:**
- [ ] `components.securitySchemes` definido.
- [ ] Cada endpoint especifica `security`.
- [ ] Los scopes requeridos están listados por endpoint.

---

## C. Compatibilidad y pruebas de contrato

#### `API-CONTRACT-001` — Tests de contrato en CI
**Severidad:** high · **Tags:** `testing`, `breaking-change-detection` · **Aplica a:** api · ci-cd

El CI detecta cambios breaking en el contrato antes de mergear.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `**/Jenkinsfile*`, `azure-pipelines*.yml`, `package.json`
**Patrones:**
- `oasdiff|openapi-diff|openapi-changes`     # herramienta de diff (positivo)
- `npx\s+openapi[-_]diff|npm\s+run\s+contract`     # comandos en CI
- `spectral\s+lint`     # linter de OpenAPI (positivo)
- `breaking[-_]change[s]?`     # job/script de detección
**Señal de N/A:** no hay `openapi*`/`swagger*` ni archivos de CI en el repo.

**Verificar:**
- [ ] Herramienta que compara OpenAPI anterior vs nuevo (openapi-diff, oasdiff) corre en CI.
- [ ] Breaking changes fallan el pipeline salvo override explícito con issue asociado.
- [ ] Los clientes generados se regeneran con el contrato nuevo.

**Banderas rojas:**
- No hay diff automatizado del contrato.
- Breaking changes se descubren en producción al romper clientes.

---

#### `API-CONTRACT-002` — Consumer-driven contract tests cuando aplica
**Severidad:** medium · **Tags:** `pact` · **Aplica a:** backend · frontend

Para APIs consumidas por servicios internos, los consumidores publican el
contrato que esperan (Pact u similar) y el productor lo verifica.

**Dónde buscar:** `**/pact*`, `**/contracts/**`, `.github/workflows/**`, `package.json`, `pom.xml`, `build.gradle`
**Patrones:**
- `@pact-foundation/pact|pact-jvm|pactum`     # librerías Pact (positivo)
- `pact_broker|pact-broker`     # broker (positivo)
- `verifyPacts\(\)|verify_pacts`     # verificación productor (positivo)
- `MessagePact|HttpPact`     # tipos Pact
**Señal de N/A:** no hay servicios internos consumidores conocidos (búsqueda de `pact|contract.*test` no devuelve nada y el repo es un único servicio).

**Verificar:**
- [ ] Cada consumidor publica sus expectativas.
- [ ] El productor ejecuta la suite de contratos en su pipeline.
- [ ] Cambios breaking rompen el pipeline del productor con contexto del consumidor afectado.

---

#### `API-CONTRACT-003` — SDK/cliente generado mantenido al día
**Severidad:** medium · **Aplica a:** api

Si se distribuye cliente oficial, se regenera y publica junto a cada release.

**Dónde buscar:** `**/clients/**`, `**/sdk/**`, `**/generated/**`, `package.json`, `.github/workflows/**`, `openapi*.{yaml,json}`
**Patrones:**
- `openapi-generator|openapi-typescript|swagger-codegen|orval|kubb`     # generadores de cliente (positivo)
- `\bnpm\s+publish\b|cargo\s+publish|twine\s+upload`     # publicación de clientes
- `// generated|# generated|@generated`     # marcas de código generado (positivo)
**Señal de N/A:** la API no distribuye SDK/cliente oficial (no hay `clients/`, `sdk/` ni generadores configurados).

**Verificar:**
- [ ] Cliente(s) oficial(es) se generan desde el contrato.
- [ ] La versión del cliente corresponde a la versión de la API.
- [ ] Los clientes publicados se prueban en un entorno de smoke-test.

---

## D. Headers de control de evolución

#### `API-VER-010` — Request-Id / Trace en cada respuesta
**Severidad:** medium · **Tags:** `observability` · **Aplica a:** api

Cada respuesta incluye un identificador que permite correlacionar con logs y
trazas.

**Dónde buscar:** `**/middleware/**`, `**/interceptors/**`, `**/handlers/**`, `**/main.{ts,js,py,go}`, `**/app.{ts,js,py,go}`
**Patrones:**
- `setHeader\(['"]X-Request-Id['"]`     # header X-Request-Id (positivo)
- `setHeader\(['"]Traceparent['"]|setHeader\(['"]traceparent['"]`     # W3C trace context (positivo)
- `(express-request-id|cls-rtracer|nestjs-pino|pino-http)`     # librerías de request id (positivo)
- `uuid\(\)[\s\S]{0,200}request[-_]?id|nanoid\(\)[\s\S]{0,200}request[-_]?id`     # generación de request id
- `req\.headers\[['"]x-request-id['"]\]\s*\|\|\s*uuid`     # respeta el del cliente o genera (positivo)
**Señal de N/A:** no hay handlers HTTP ni middleware en el repo.

**Verificar:**
- [ ] `X-Request-Id` o `Traceparent` en toda respuesta.
- [ ] El mismo ID aparece en el log correspondiente.
- [ ] Los clientes pueden incluir `X-Request-Id` y el servidor lo respeta (o lo referencia).

(Ver `10-observabilidad/03-trazas-alertas.md`.)

---

## Checklist resumen

| ID                | Control                                                 | Severidad |
| ----------------- | ------------------------------------------------------- | --------- |
| API-VER-001       | Versión explícita                                       | high      |
| API-VER-002       | Breaking changes identificados                          | high      |
| API-VER-003       | Convivencia de versiones acotada                        | medium    |
| API-VER-004       | Deprecation visible                                     | medium    |
| API-VER-005       | Tolerancia a campos desconocidos                        | medium    |
| API-DOC-001       | OpenAPI como fuente de verdad                           | high      |
| API-DOC-002       | Ejemplos reales                                         | medium    |
| API-DOC-003       | Portal de docs                                          | medium    |
| API-DOC-004       | Autenticación documentada                               | medium    |
| API-CONTRACT-001  | Tests de contrato en CI                                 | high      |
| API-CONTRACT-002  | Consumer-driven contract tests                          | medium    |
| API-CONTRACT-003  | SDK/cliente mantenido                                   | medium    |
| API-VER-010       | Request-Id en cada respuesta                            | medium    |
