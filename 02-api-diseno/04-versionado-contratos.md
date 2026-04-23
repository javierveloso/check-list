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

**Verificar:**
- [ ] Política clara: ej. "v_n-1 se mantiene 12 meses tras salir v_n".
- [ ] Plan documentado de sunsetting.
- [ ] Headers `Deprecation`, `Sunset` (RFC 8594) en respuestas de versiones deprecadas.

---

#### `API-VER-004` — Deprecation visible al cliente
**Severidad:** medium · **Aplica a:** api

Los endpoints o campos deprecados lo informan al cliente.

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

**Verificar:**
- [ ] Todos los endpoints con body o response compleja tienen `examples`.
- [ ] Los ejemplos son válidos contra el schema (test de contrato).
- [ ] Los errores 4xx más comunes tienen ejemplo documentado.

---

#### `API-DOC-003` — Portal de documentación publicado
**Severidad:** medium · **Aplica a:** api

Los consumidores (internos o externos) tienen acceso a docs navegables
actualizadas.

**Verificar:**
- [ ] Swagger UI / Redoc / Stoplight desplegado para cada entorno (dev, staging).
- [ ] En producción, el acceso está controlado si la API es privada.
- [ ] Los docs se regeneran automáticamente en cada release.

---

#### `API-DOC-004` — Autenticación documentada
**Severidad:** medium · **Aplica a:** api

El contrato documenta cómo autenticarse (esquemas, scopes, flujos OAuth).

**Verificar:**
- [ ] `components.securitySchemes` definido.
- [ ] Cada endpoint especifica `security`.
- [ ] Los scopes requeridos están listados por endpoint.

---

## C. Compatibilidad y pruebas de contrato

#### `API-CONTRACT-001` — Tests de contrato en CI
**Severidad:** high · **Tags:** `testing`, `breaking-change-detection` · **Aplica a:** api · ci-cd

El CI detecta cambios breaking en el contrato antes de mergear.

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

**Verificar:**
- [ ] Cada consumidor publica sus expectativas.
- [ ] El productor ejecuta la suite de contratos en su pipeline.
- [ ] Cambios breaking rompen el pipeline del productor con contexto del consumidor afectado.

---

#### `API-CONTRACT-003` — SDK/cliente generado mantenido al día
**Severidad:** medium · **Aplica a:** api

Si se distribuye cliente oficial, se regenera y publica junto a cada release.

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
