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

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/repositories/**`, `**/services/**`
**Patrones:**
- `\.find\(\s*\)(?![\s\S]{0,100}\.(limit|take|paginate))`     # find() sin limit
- `\.findAll\(\s*\)(?![\s\S]{0,100}\.(limit|take|paginate))`     # findAll() sin limit
- `SELECT\s+[^;]*\s+FROM\s+\w+(?![\s\S]{0,200}\b(LIMIT|OFFSET|FETCH)\b)`     # SELECT sin LIMIT (heurística)
- `\.query\(['"]SELECT\s[^'"]+['"](?![\s\S]{0,200}LIMIT)`     # query SQL inline sin LIMIT
- `per_page\s*=\s*int\(req\.args\.get\(['"]per_page['"][^)]*\)\)(?![\s\S]{0,200}min\(|max\()`     # per_page sin clamp
- `Model\.objects\.all\(\)(?![\s\S]{0,150}\[:)`     # Django all() sin slice
**Señal de N/A:** no hay handlers que devuelvan listas (búsqueda de `findAll|\.all\(\)|\.find\(\)` sin filtros no devuelve nada).

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

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/responses/**`, `openapi*.{yaml,json}`
**Patrones:**
- `meta\s*:\s*\{[\s\S]{0,200}\b(page|per_page|total)\b`     # metadata de paginación (positivo)
- `links\s*:\s*\{[\s\S]{0,200}(next|prev|first|last)`     # links de paginación (positivo)
- `setHeader\(['"]Link['"]\s*,[\s\S]{0,200}rel=['"]next['"]`     # Link header next (positivo)
- `res\.json\(\s*\{\s*['"](items|results|data)['"]\s*:[\s\S]{0,200}\}\s*\)(?![\s\S]{0,200}(meta|total|next))`     # lista sin metadata
**Señal de N/A:** no hay endpoints de listado en el repo.

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

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/repositories/**`, `**/services/**`
**Patrones:**
- `OFFSET\s+\d{4,}`     # OFFSET >= 1000 hardcodeado
- `\.skip\(\s*\d{4,}\s*\)`     # skip >= 1000
- `\boffset\s*=\s*\(?\s*page\s*[-*]\s*1\s*\)?\s*\*\s*per_page\b`     # cálculo de offset por página (típico de offset-based)
- `cursor\s*[:=]\s*req\.(query|params)\.cursor`     # cursor en uso (positivo)
- `Buffer\.from\([^)]+\)\.toString\(['"]base64['"]\)[\s\S]{0,200}cursor`     # cursor opaco base64 (positivo)
- `cursor\s*=\s*item\.id\b`     # cursor que es el ID directo (no opaco)
**Señal de N/A:** no hay endpoints de listado con paginación en el repo.

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

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/middleware/**`, `**/validators/**`
**Patrones:**
- `if\s*\(\s*offset\s*[+]\s*\w+\s*>\s*\d{4,}`     # límite duro de offset+page
- `Math\.min\(\s*\w+\s*,\s*\d{3,4}\s*\)[\s\S]{0,200}page`     # clamp de page
- `page\s*=\s*max\(.*min\(`     # clamp Python
- `MAX_(OFFSET|PAGE|DEEP_PAGINATION)`     # constante de límite (positivo)
**Señal de N/A:** no hay endpoints de listado con paginación offset en el repo.

**Verificar:**
- [ ] Hay límite duro: ej. `offset + per_page ≤ 10_000`.
- [ ] Más allá, el servidor responde con sugerencia de usar cursor o filtrar más.

---

## B. Filtros

#### `API-FILTER-001` — Filtros declarativos y documentados
**Severidad:** medium · **Aplica a:** api

Los filtros disponibles se documentan en OpenAPI. Filtros no soportados se
rechazan o ignoran de forma predecible.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `openapi*.{yaml,json}`
**Patrones:**
- `req\.query\b(?![\s\S]{0,200}(zod|joi|yup|class-validator|pydantic|schema))`     # query usado sin schema
- `for\s+\w+\s+in\s+req\.query`     # iteración libre sobre query (filtros dinámicos sin allowlist)
- `\.\.\.\s*req\.query\b`     # spread de query directo
- `parameters:\s*\[(?![\s\S]{0,1000}name:\s*['"]filter)`     # OpenAPI sin filtros declarados
**Señal de N/A:** no hay endpoints con query params de filtro en el repo.

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

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/controllers/**`, `**/handlers/**`, `**/dao/**`
**Patrones:**
- `\.all\(\)[\s\S]{0,100}\.filter\(`     # Django all() seguido de filter en Python
- `\[\w+\s+for\s+\w+\s+in\s+\w+\s+if\s+\w+\.(status|owner|type)\s*==`     # list comp sobre query result
- `\.find\(\s*\{?\s*\}?\s*\)[\s\S]{0,200}\.filter\(`     # Mongoose find().filter en JS
- `\.findAll\([^)]*\)(?![\s\S]{0,200}where)[\s\S]{0,200}\.filter\(`     # Sequelize findAll luego .filter
- `result\s*=\s*await\s+\w+\.find\(\)[\s\S]{0,200}filtered\s*=`     # patrón cargar todo, filtrar en memoria
**Señal de N/A:** no hay capa de servicios/repositorios con queries en el repo.

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

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/controllers/**`, `**/handlers/**`
**Patrones:**
- `where\s*:\s*\{?\s*owner_?id\s*:\s*req\.(query|params|body)\.owner_?id`     # owner_id desde el cliente
- `where\s*:\s*\{?\s*tenant_?id\s*:\s*req\.(query|params|body)\.tenant_?id`     # tenant_id desde el cliente
- `\.filter\(\s*owner_?id\s*=\s*request\.(GET|POST|args|json)\.get`     # Python: filter por owner del cliente
- `\.\.\.\s*req\.query[\s\S]{0,200}\.find\(`     # spread directo a find (cliente puede pasar cualquier filtro)
- `req\.user\.id|current_user\.id|getCurrentUser\(`     # owner se toma del usuario autenticado (positivo)
**Señal de N/A:** no hay endpoints de listado con filtros, o no hay autenticación.

**Verificar:**
- [ ] El filtro por ownership se **agrega** en el servidor, no se pide al cliente.
- [ ] Los filtros por IDs sensibles (admin-only) solo están disponibles para quienes tienen permiso.
- [ ] No se pueden sobreescribir filtros de seguridad con parámetros del cliente.

---

## C. Ordenamiento

#### `API-SORT-001` — Ordenamiento controlado por allowlist
**Severidad:** high · **Tags:** `cwe-89`, `performance` · **Aplica a:** backend

Solo se puede ordenar por campos en allowlist, y estos campos tienen índice.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/controllers/**`, `**/handlers/**`
**Patrones:**
- `ORDER\s+BY\s+\$\{[^}]+\}|ORDER\s+BY\s+["'`]\s*\+`     # ORDER BY con interpolación (SQLi)
- `orderBy\s*:\s*req\.(query|params|body)\.(sort|order|sortBy)`     # orderBy directo del cliente
- `\.order_by\(\s*request\.(GET|POST|args)\.get\(['"]sort`     # Python: order_by con input directo
- `ALLOWED_SORT_FIELDS|SORT_ALLOWLIST|SORTABLE_FIELDS`     # allowlist (positivo)
- `if\s+sort_field\s+not\s+in\s+(ALLOWED|VALID|SORTABLE)`     # validación allowlist (positivo)
**Señal de N/A:** no hay endpoints con parámetro de ordenamiento en el repo.

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

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `openapi*.{yaml,json}`
**Patrones:**
- `\.split\(\s*['"],['"]\s*\)[\s\S]{0,100}sort`     # parsing de sort multi-campo (positivo)
- `req\.query\.sort[\s\S]{0,200}\.startsWith\(['"]-['"]\)`     # detección de prefijo "-" para desc (positivo)
**Señal de N/A:** la API no soporta orden multi-campo (búsqueda de `sort.*,` no devuelve nada).

**Ejemplo:** `sort=-priority,created_at` (prioridad desc, luego fecha asc).

---

## D. Búsqueda

#### `API-SEARCH-001` — Búsqueda textual con sanitización
**Severidad:** medium · **Tags:** `cwe-89`, `redos` · **Aplica a:** backend

La búsqueda textual es segura contra inyección y ataques de expresión regular.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/controllers/**`, `**/handlers/**`, `**/search/**`
**Patrones:**
- `LIKE\s+['"]%\$\{[^}]+\}%['"]|LIKE\s+['"]%\s*\+\s*\w+\s*\+\s*%['"]`     # LIKE con interpolación
- `new\s+RegExp\(\s*req\.(query|body|params)`     # RegExp construido desde input
- `re\.compile\(\s*request\.(GET|POST|args|json)\.get`     # Python regex desde input
- `\.\$regex\s*:\s*req\.(query|params|body)`     # Mongoose $regex desde cliente
- `to_tsquery\(|websearch_to_tsquery\(|plainto_tsquery\(`     # Postgres FTS seguro (positivo)
- `re2\.compile|RE2\.match`     # uso de RE2 (positivo, lineal)
**Señal de N/A:** no hay endpoints de búsqueda textual en el repo.

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

**Dónde buscar:** `**/migrations/**`, `**/schema*.{sql,prisma}`, `**/services/**`, `**/repositories/**`, `**/search/**`
**Patrones:**
- `CREATE\s+INDEX[\s\S]{0,200}USING\s+(GIN|gin|GIST|gist)`     # índices GIN/GIST (positivo)
- `pg_trgm|gin_trgm_ops|tsvector`     # extensiones FTS Postgres (positivo)
- `(elasticsearch|opensearch|meilisearch|typesense|algolia)`     # motor externo (positivo)
- `LIKE\s+['"]%[\s\S]{0,100}%['"]`     # LIKE con leading wildcard (no usa índice)
- `ILIKE\s+['"]%`     # ILIKE con wildcard inicial
**Señal de N/A:** no hay endpoints de búsqueda textual en el repo.

**Verificar:**
- [ ] Índices adecuados existen (`GIN tsvector`, trigram, ElasticSearch, etc.).
- [ ] Las búsquedas no hacen secuencial scan en producción.

---

## E. Expansión y proyección

#### `API-INC-001` — Expansión de relaciones explícita (include)
**Severidad:** low · **Aplica a:** api

Si la API soporta expandir relaciones (traer datos relacionados), el cliente
lo pide explícitamente.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/services/**`, `**/repositories/**`, `openapi*.{yaml,json}`
**Patrones:**
- `req\.query\.(include|expand|with|embed)\b`     # parámetro de expansión (positivo)
- `\.populate\(\s*req\.(query|params)\.populate`     # Mongoose populate desde cliente directo
- `include\s*:\s*\{[\s\S]{0,500}include\s*:\s*\{[\s\S]{0,500}include\s*:`     # Prisma include anidado >=3 niveles
- `joinedload[\s\S]{0,200}joinedload[\s\S]{0,200}joinedload`     # SQLAlchemy joinedload anidado
**Señal de N/A:** la API no expone parámetros de inclusión (búsqueda de `include|expand|with|embed` en query no devuelve nada).

**Verificar:**
- [ ] `?include=customer,items` expande relaciones documentadas.
- [ ] Por defecto las relaciones NO se expanden (evitar responses pesados).
- [ ] La expansión está limitada a profundidad/cantidad razonable.

---

#### `API-PROJ-001` — Proyección de campos (fields)
**Severidad:** low · **Aplica a:** api

El cliente puede pedir solo ciertos campos para reducir payload.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/services/**`, `**/repositories/**`, `openapi*.{yaml,json}`
**Patrones:**
- `req\.query\.fields\b|req\.query\['fields'\]`     # parámetro fields (positivo)
- `\.select\(\s*req\.(query|body)\.fields`     # select del cliente (verificar allowlist)
- `\bfields\s*=\s*request\.GET\.get\(['"]fields['"]\)`     # Django/DRF
- `SparseFieldset|sparse_fieldset`     # JSON:API sparse fieldsets (positivo)
**Señal de N/A:** la API no soporta proyección de campos (búsqueda de `fields=` en query no devuelve nada).

**Verificar:**
- [ ] `?fields=id,name,created_at` (o `?fields[orders]=...` estilo JSON:API) soportado donde aporta valor.
- [ ] La proyección se traduce a `SELECT` eficiente en BD.

---

## F. Respuestas de listado: consistencia

#### `API-LIST-001` — Estructura de listado uniforme
**Severidad:** medium · **Aplica a:** api

Toda lista paginada usa la misma estructura en toda la API.

**Dónde buscar:** `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `**/responses/**`, `openapi*.{yaml,json}`
**Patrones:**
- `res\.json\(\s*\{\s*['"]items['"]`     # estructura items
- `res\.json\(\s*\{\s*['"]results['"]`     # estructura results
- `res\.json\(\s*\{\s*['"]data['"]`     # estructura data
- `res\.json\(\s*\[`     # array desnudo (sin envoltura)
- `(?:items|results|data)\s*:\s*null`     # array como null
**Señal de N/A:** no hay handlers de listado en el repo.

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
