# 02 · API · Paginación, filtros y ordenamiento

> Paginación de listados, filtrado, ordenamiento, expansión de relaciones y
> proyección de campos.
>
> **Marcos de referencia:** JSON:API · Google API Design Guide · Microsoft REST API Guidelines.

---

## A. Paginación

#### `API-PAGE-001` — Paginación obligatoria en todos los listados
**Severidad:** high · **Tags:** `performance`, `dos` · **Aplica a:** api · backend

Cualquier endpoint que retorne colecciones está paginado, incluso si hoy tiene
pocos resultados. El tamaño por defecto es razonable; el máximo se impone.

**Verificar:**
- [ ] Todo endpoint de listado aplica paginación (no retorna colección entera).
- [ ] Tamaño por defecto razonable (ej: 20–50).
- [ ] Tamaño máximo enforced en el servidor (ej: 100).
- [ ] Página fuera de rango retorna 200 con array vacío + metadata correcta, no 404.

**Banderas rojas:**
- `SELECT * FROM table` sin `LIMIT` en handler de listado.
- Cliente puede pedir `per_page=10000`.

---

#### `API-PAGE-002` — Metadata de paginación completa
**Severidad:** medium · **Aplica a:** api

La respuesta incluye la información necesaria para que el cliente paginue sin
inferir nada.

**Verificar:**
- [ ] La respuesta lleva: página actual (o cursor), tamaño, total de items (si feasible), total de páginas (si feasible).
- [ ] Links a `next`, `prev`, `first`, `last` cuando sea posible.
- [ ] El formato de la metadata es consistente en toda la API.

**Ejemplo (offset-based):**
```json
{
  "items": [...],
  "meta": { "page": 2, "per_page": 20, "total": 157, "total_pages": 8 },
  "links": {
    "self":  "?page=2",
    "first": "?page=1",
    "prev":  "?page=1",
    "next":  "?page=3",
    "last":  "?page=8"
  }
}
```

---

#### `API-PAGE-003` — Cursor-based para colecciones grandes o mutables
**Severidad:** medium · **Tags:** `performance` · **Aplica a:** api · backend

Para datasets grandes o mutables, preferir cursor pagination a offset (que
sufre drift y tiene costos crecientes).

**Verificar:**
- [ ] Listados con > ~10k elementos o con inserciones frecuentes usan cursor.
- [ ] El cursor es opaco (base64 de (campo_orden, id) o similar), no un ID interno expuesto.
- [ ] Cursor inválido retorna 400 con mensaje claro.
- [ ] Hay soporte para `prev` cuando aplica (cursores bidireccionales).

**Banderas rojas:**
- `OFFSET 50000 LIMIT 20` en BD grande.
- Cursor que es el ID del último item (trivialmente enumerable).

---

#### `API-PAGE-004` — Deep pagination limitada o prohibida
**Severidad:** medium · **Tags:** `performance`, `dos` · **Aplica a:** api · backend

Offset muy profundo (`page=10000`) es costoso. Se limita la profundidad máxima
o se fuerza cursor.

**Verificar:**
- [ ] Hay límite duro: ej. `offset + per_page ≤ 10_000`.
- [ ] Más allá, el servidor responde con sugerencia de usar cursor o filtrar más.

---

## B. Filtros

#### `API-FILTER-001` — Filtros declarativos y documentados
**Severidad:** medium · **Aplica a:** api

Los filtros disponibles se documentan en OpenAPI. Filtros no soportados se
rechazan o ignoran de forma predecible.

**Verificar:**
- [ ] Cada endpoint documenta los filtros aceptados, su tipo y valores válidos.
- [ ] Parámetros desconocidos: política clara (ignorar o rechazar) y consistente.
- [ ] Los filtros complejos (ranges, operadores) usan sintaxis explícita y documentada.

**Ejemplo:**
```
GET /orders?status=paid&created_at_gte=2026-01-01&created_at_lte=2026-03-31
```

O estilo operador:

```
GET /orders?filter[status]=paid&filter[created_at][gte]=2026-01-01
```

---

#### `API-FILTER-002` — Filtros se aplican en la BD, no en memoria
**Severidad:** high · **Tags:** `performance`, `cwe-400` · **Aplica a:** backend

Los filtros se traducen a cláusulas SQL/consulta, no se implementan trayendo
toda la tabla y filtrando en código.

**Verificar:**
- [ ] Cada filtro agrega cláusula a la query (`WHERE` / equivalente).
- [ ] No hay patrones "cargar todo, filtrar en Python/JS".
- [ ] Los filtros tienen índices adecuados cuando son comunes.

**Banderas rojas:**
- `orders = db.query(Order).all(); filtered = [o for o in orders if o.status == status]`.
- Falta de índice en columnas usadas por filtros frecuentes.

---

#### `API-FILTER-003` — Filtros por campos sensibles protegidos
**Severidad:** high · **Tags:** `owasp-api1`, `idor` · **Aplica a:** backend

Los filtros no permiten bypass de autorización (ej: filtrar por `owner_id=OTRO`
y obtener datos ajenos).

**Verificar:**
- [ ] El filtro por ownership se **agrega** en el servidor, no se pide al cliente.
- [ ] Los filtros por IDs sensibles (admin-only) solo están disponibles para quienes tienen permiso.
- [ ] No se pueden sobreescribir filtros de seguridad con parámetros del cliente.

---

## C. Ordenamiento

#### `API-SORT-001` — Ordenamiento controlado por allowlist
**Severidad:** high · **Tags:** `cwe-89`, `performance` · **Aplica a:** backend

Solo se puede ordenar por campos en allowlist, y estos campos tienen índice.

**Verificar:**
- [ ] El campo de `sort` se valida contra allowlist.
- [ ] Los campos permitidos tienen índice en BD.
- [ ] Ordenamiento inverso explícito (`sort=-created_at` o `order=desc`).
- [ ] Hay orden por defecto estable (ej: `created_at DESC, id DESC`) que no depende del engine.

**Banderas rojas:**
- `ORDER BY ${user_input}` con input directo (SQLi + full table scan).
- Orden por defecto que rompe paginación (resultados duplicados/faltantes entre páginas).

---

#### `API-SORT-002` — Orden multi-campo con sintaxis explícita
**Severidad:** low · **Aplica a:** api

Si se soporta orden múltiple, la sintaxis es clara.

**Ejemplo:** `sort=-priority,created_at` (prioridad desc, luego fecha asc).

---

## D. Búsqueda

#### `API-SEARCH-001` — Búsqueda textual con sanitización
**Severidad:** medium · **Tags:** `cwe-89`, `redos` · **Aplica a:** backend

La búsqueda textual es segura contra inyección y ataques de expresión regular.

**Verificar:**
- [ ] Input se pasa por funciones de construcción de query full-text del motor (no concatenado).
- [ ] Caracteres reservados del motor se escapan.
- [ ] Longitud mínima y máxima documentadas.
- [ ] Regex del usuario, si se aceptan, se evalúan con timeout o motor lineal (RE2).

---

#### `API-SEARCH-002` — Índices apropiados para búsqueda
**Severidad:** medium · **Tags:** `performance` · **Aplica a:** backend

Las búsquedas usan índices adecuados al volumen: trigram, fulltext, motor de
búsqueda externo si es necesario.

**Verificar:**
- [ ] Índices adecuados existen (`GIN tsvector`, trigram, ElasticSearch, etc.).
- [ ] Las búsquedas no hacen secuencial scan en producción.

---

## E. Expansión y proyección

#### `API-INC-001` — Expansión de relaciones explícita (include)
**Severidad:** low · **Aplica a:** api

Si la API soporta expandir relaciones (traer datos relacionados), el cliente
lo pide explícitamente.

**Verificar:**
- [ ] `?include=customer,items` expande relaciones documentadas.
- [ ] Por defecto las relaciones NO se expanden (evitar responses pesados).
- [ ] La expansión está limitada a profundidad/cantidad razonable.

---

#### `API-PROJ-001` — Proyección de campos (fields)
**Severidad:** low · **Aplica a:** api

El cliente puede pedir solo ciertos campos para reducir payload.

**Verificar:**
- [ ] `?fields=id,name,created_at` (o `?fields[orders]=...` estilo JSON:API) soportado donde aporta valor.
- [ ] La proyección se traduce a `SELECT` eficiente en BD.

---

## F. Respuestas de listado: consistencia

#### `API-LIST-001` — Estructura de listado uniforme
**Severidad:** medium · **Aplica a:** api

Toda lista paginada usa la misma estructura en toda la API.

**Verificar:**
- [ ] Decisión única: `items`, `data`, `results` — lo que sea, uniforme.
- [ ] Metadata de paginación siempre en el mismo lugar (`meta` / top-level).
- [ ] Arrays vacíos siempre como `[]`, no `null`.

**Banderas rojas:**
- Un endpoint retorna `{"data": [...]}`, otro `{"results": [...]}`, otro directamente `[...]`.

---

## Checklist resumen

| ID               | Control                                               | Severidad |
| ---------------- | ----------------------------------------------------- | --------- |
| API-PAGE-001     | Paginación obligatoria                                | high      |
| API-PAGE-002     | Metadata de paginación completa                       | medium    |
| API-PAGE-003     | Cursor para colecciones grandes                       | medium    |
| API-PAGE-004     | Deep pagination limitada                              | medium    |
| API-FILTER-001   | Filtros declarativos documentados                     | medium    |
| API-FILTER-002   | Filtros aplicados en BD                               | high      |
| API-FILTER-003   | Filtros por campos sensibles protegidos               | high      |
| API-SORT-001     | Ordenamiento con allowlist                            | high      |
| API-SORT-002     | Orden multi-campo claro                               | low       |
| API-SEARCH-001   | Búsqueda textual sanitizada                           | medium    |
| API-SEARCH-002   | Índices apropiados para búsqueda                      | medium    |
| API-INC-001      | Include explícito                                     | low       |
| API-PROJ-001     | Proyección de campos                                  | low       |
| API-LIST-001     | Estructura de listado uniforme                        | medium    |
