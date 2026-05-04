# 03 · Calidad de código · Funciones, complejidad y SOLID

> Reglas sobre tamaño y complejidad de funciones, principios SOLID, DRY y YAGNI.
>
> **Marcos de referencia:** Clean Code · SOLID (Robert C. Martin) · Refactoring (Martin Fowler).

---

## A. Funciones

#### `CODE-FN-001` — Funciones cortas y enfocadas
**Severidad:** medium · **Aplica a:** all

Cada función hace **una** cosa bien. Lo demás se extrae.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `if\s*\([^)]*\)\s*\{[\s\S]{600,}?\}` # cuerpos `if` enormes (proxy de función larga)
- `function\s+\w+[^{]*\{[\s\S]{2000,}?\n\}` # funciones JS muy largas
- `def\s+\w+\([^)]*\):[\s\S]{2000,}?(?=\n(?:def|class|\Z))` # funciones Python muy largas
- *(longitud y cohesión — revisión LLM-judge complementa)*
**Señal de N/A:** módulo trivial (script <50 LOC) o solo configuración declarativa.

**Verificar:**
- [ ] La mayoría de funciones caben en la pantalla (~30-50 líneas). Excepciones se justifican.
- [ ] Es posible nombrar lo que hace cada función en una frase simple.
- [ ] Las funciones largas se subdividen en pasos con nombres.

**Banderas rojas:**
- Funciones de > 100 líneas con múltiples responsabilidades.
- Métodos con varios "pasos" sin helpers.

---

#### `CODE-FN-002` — Parámetros limitados
**Severidad:** medium · **Aplica a:** all

Una función con muchos parámetros es difícil de entender y de probar.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `def\s+\w+\(([^,)]+,){5,}`         # función Python con >5 parámetros
- `function\s+\w+\(([^,)]+,){5,}`    # función JS con >5 parámetros
- `func\s+\w+\(([^,)]+,){5,}`        # función Go con >5 parámetros
- `\(\s*\w+\s*,\s*(true|false)\s*,\s*(true|false)` # booleanos posicionales
**Señal de N/A:** API trivial sin funciones expuestas (script de configuración).

**Verificar:**
- [ ] ≤ 4–5 parámetros. Si son más, pasarlos como objeto/dataclass.
- [ ] Parámetros posicionales usados solo cuando el orden es obvio (ej: `(x, y)`, `(start, end)`).
- [ ] Keyword-only arguments cuando el lenguaje lo permite para argumentos booleanos y opcionales.

**Banderas rojas:**
- `def update(user, name, email, role, active, verified, settings, ...)`.
- Booleanos posicionales: `send(msg, True, False, True)`.

---

#### `CODE-FN-003` — Sin "flag arguments"
**Severidad:** low · **Aplica a:** all

Los booleanos que cambian el comportamiento de una función suelen indicar que
son dos funciones distintas.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `def\s+\w+\([^)]*\b(is_|has_|should_|use_|enable_|disable_)\w+\s*[:=]\s*(True|False)` # flag bool en Python
- `function\s+\w+\([^)]*\b(is[A-Z]|has[A-Z]|should[A-Z])\w*\s*[:=]\s*(true|false)` # flag bool en JS/TS
- `if\s*\(\s*(is_|should_|use_)\w+\s*\)\s*\{[\s\S]{200,}?\}\s*else\s*\{[\s\S]{200,}?\}` # ramas grandes
**Señal de N/A:** funciones del proyecto no aceptan booleanos como argumento.

**Verificar:**
- [ ] Evitar booleanos que seleccionan ramas grandes dentro de la función.
- [ ] Preferir dos funciones pequeñas con intención clara (`send_email_now()` vs `schedule_email()`).

**Banderas rojas:**
- `def process(item, is_preview=False): if is_preview: ... else: ...` donde las ramas son 80% distintas.

---

#### `CODE-FN-004` — Complejidad ciclomática acotada
**Severidad:** medium · **Aplica a:** all

Las funciones muy anidadas son difíciles de leer y de testear.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `else\s+if[\s\S]{0,300}else\s+if[\s\S]{0,300}else\s+if` # cadena larga elif
- `^( {12,}|\t{4,})\S`               # indentación de 4+ niveles
- `\}\s*else\s*\{\s*return\b`        # else innecesario tras return
- `\}\s*else\s*\{\s*throw\b`         # else innecesario tras throw
**Señal de N/A:** lenguaje declarativo (SQL, YAML) sin control de flujo.

**Verificar:**
- [ ] Complejidad ciclomática ≤ 10 por función (mayor indica necesidad de refactor).
- [ ] Máximo 2–3 niveles de indentación dentro de una función.
- [ ] Se usa early return ("guard clauses") para evitar pirámides de if-else.

**Banderas rojas:**
- Pirámides `if ... if ... if ... if ...` con varios niveles.
- `else` innecesario después de un `return` / `raise` / `throw`.

**Herramientas:** radon (Python), eslint-plugin-complexity, cyclomatic-complexity, sonar.

---

#### `CODE-FN-005` — Funciones puras cuando sea posible
**Severidad:** low · **Aplica a:** all

Las funciones sin side effects son más fáciles de testear y razonar.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `def\s+(calculate|validate|compute|transform|format)\w*\([^)]*\):[\s\S]{0,500}?(open\(|requests\.|httpx\.|\.execute\()` # cálculo mezclado con I/O
- `function\s+(calculate|validate|format)\w*[\s\S]{0,500}?(fetch\(|axios\.|fs\.)`
- `Date\.now\(\)|datetime\.now\(\)`  # tiempo dentro de funciones de cálculo (revisar)
- *(pureza — revisión LLM-judge)*
**Señal de N/A:** todo el módulo es I/O por diseño (CLI runner, script ETL trivial).

**Verificar:**
- [ ] La lógica de negocio (cálculos, validaciones, transformaciones) tiende a ser pura.
- [ ] Los efectos (I/O, escritura, randomness, tiempo) están concentrados en funciones identificables.
- [ ] Las funciones con I/O tienen nombres que lo delatan (`fetch_*`, `save_*`, `send_*`).

---

#### `CODE-FN-006` — Sin mutación de parámetros de entrada sin documentar
**Severidad:** medium · **Tags:** `bug-risk` · **Aplica a:** all

Modificar el argumento que el llamador te pasó es sorpresa. Si se hace, el
nombre lo refleja y la documentación lo aclara.

**Dónde buscar:** `**/*.{py,js,ts,tsx,jsx,java,cs,rb}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `def\s+\w+\([^)]*=\s*\[\s*\]`      # default mutable Python (lista)
- `def\s+\w+\([^)]*=\s*\{\s*\}`      # default mutable Python (dict/set)
- `def\s+\w+\([^)]*=\s*set\(\)`      # default mutable Python (set)
- `\.push\(|\.append\(|\.shift\(|\.pop\(` # mutación de colecciones (revisar argumento)
**Señal de N/A:** lenguajes con inmutabilidad por defecto (Rust sin `&mut`, Haskell, Elm).

**Verificar:**
- [ ] La función documenta si muta parámetros.
- [ ] En lenguajes donde se pueden pasar inmutables, se prefiere retornar un valor nuevo.
- [ ] No hay default mutables (`def f(items=[])` en Python — bug clásico).

**Banderas rojas:**
- Funciones que llenan una lista pasada por referencia silenciosamente.
- `def f(items=[])`, `def f(cache={})` en Python.

---

## B. Manejo de errores

#### `CODE-ERR-001` — Excepciones específicas, no catch-all
**Severidad:** high · **Tags:** `reliability` · **Aplica a:** all

Se capturan las excepciones específicas que se pueden manejar. Las genéricas
se propagan.

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,java,cs,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `except\s*:\s*\n\s*pass`           # except: pass silencioso
- `except\s+Exception\s*(?:as\s+\w+)?\s*:\s*\n\s*pass`
- `catch\s*\([^)]*\)\s*\{\s*\}`      # catch vacío JS/Java/C#
- `except\s+BaseException\b`         # captura demasiado amplia Python
- `catch\s*\(\s*\w+\s*:\s*any\s*\)`  # catch any en TS
**Señal de N/A:** lenguaje sin excepciones (Go con error returns explícitos, Rust con Result).

**Verificar:**
- [ ] `except Exception` / `catch (e: any)` solo en el nivel más alto o con re-raise.
- [ ] Nunca `except:` vacío o `catch` que silencie todo sin log.
- [ ] `pass` en excepciones requiere comentario explicando por qué es aceptable.

**Banderas rojas:**
- `except: pass`, `catch(e) {}` sin log ni re-throw.
- Capturar excepciones muy genéricas en middle layers.

---

#### `CODE-ERR-002` — Stack traces preservados al re-lanzar
**Severidad:** medium · **Aplica a:** all

Al convertir una excepción en otra, se preserva el stack original.

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,java,cs,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `raise\s+\w+\(str\(e\)\)`          # Python: pierde stack
- `raise\s+\w+\([^)]*\)(?!\s+from\s)` # Python: raise sin `from`
- `throw\s+new\s+\w+\([^)]*\)(?![^;]*cause)` # JS sin `{ cause: e }`
- `throw\s+new\s+\w+\(\s*e\.getMessage\(\)\s*\)` # Java pierde stack
**Señal de N/A:** lenguajes sin chained exceptions o con stack siempre preservado por defecto.

**Verificar:**
- [ ] Python: `raise MyError(...) from e`.
- [ ] JavaScript: `throw new Error(msg, { cause: e })`.
- [ ] Java: `throw new MyException(msg, e)`.
- [ ] Los logs de error incluyen stack trace completo.

**Banderas rojas:**
- `except Exception as e: raise MyError(str(e))` — se pierde el trace.
- Logs de error sin stack trace.

---

#### `CODE-ERR-003` — Excepciones custom con jerarquía clara
**Severidad:** low · **Aplica a:** all

Las excepciones de la aplicación heredan de una raíz común y están organizadas
por dominio.

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,java,cs,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `class\s+\w+(?:Error|Exception)\(Exception\)` # Python heredando directo de Exception
- `class\s+\w+Error\s+extends\s+Error\b`         # JS/TS heredando de Error
- `raise\s+Exception\(`              # uso directo de Exception en vez de custom
- `throw\s+new\s+Error\(`            # uso directo de Error en vez de custom
**Señal de N/A:** app trivial / script donde no se modela el dominio con excepciones.

**Verificar:**
- [ ] Hay un `BaseAppError` / equivalente y todas las excepciones heredan de él.
- [ ] Categorías claras: `ValidationError`, `AuthError`, `NotFoundError`, `ExternalServiceError`.
- [ ] Las excepciones cargan datos estructurados, no solo un string.

---

#### `CODE-ERR-004` — Errores en borde, no en cada capa
**Severidad:** medium · **Aplica a:** all

Las capas intermedias propagan; solo la capa frontera (HTTP handler,
command handler, worker entry) traduce a respuesta/log.

**Dónde buscar:** `**/services/**`, `**/repositories/**`, `**/domain/**`, `**/usecases/**`, `**/*.{py,ts,tsx,js,go,java,cs}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `services?/[^.]+\.(py|ts|js).*\bres(?:ponse)?\.(json|status|send)` # response HTTP en service
- `HTTPException|HttpResponse|res\.status\(`     # construcción de respuesta HTTP fuera de handlers
- `from\s+(fastapi|express|flask|django\.http)\s+import` # imports de framework HTTP
**Señal de N/A:** monolito sin separación de capas (script CLI, lambda monofile).

**Verificar:**
- [ ] Services/repositories no convierten excepciones en responses HTTP.
- [ ] Solo el borde (controller/handler) decide qué respuesta producir ante cada excepción.
- [ ] El logging de errores está centralizado.

---

#### `CODE-ERR-005` — Recursos liberados aunque haya excepción
**Severidad:** high · **Tags:** `resource-leak`, `cwe-404` · **Aplica a:** all

Conexiones, archivos, locks, etc., se liberan siempre.

**Dónde buscar:** `**/*.{py,ts,tsx,js,jsx,java,cs,go,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `\bopen\([^)]+\)(?!\s*\.__|\s*as\s)` # open() sin `with` ni asignación a context manager Python
- `\.acquire\(\)(?![\s\S]{0,500}finally)` # lock acquire sin finally cercano
- `new\s+FileInputStream\(`           # Java: stream sin try-with-resources cercano
- `connect\(\)(?![\s\S]{0,300}(close|defer|finally))` # conexión sin cierre
**Señal de N/A:** código sin recursos que requieran cleanup (pure compute / immutable data only).

**Verificar:**
- [ ] Uso de `with` / `using` / `defer` / `try-finally` / RAII.
- [ ] No hay archivos abiertos sin cerrar en paths de error.
- [ ] Sessions/transactions con cierre garantizado.

**Banderas rojas:**
- `open(...)` sin `with` y sin `try-finally`.
- Locks adquiridos sin release en el finally.

---

## C. Principios SOLID

#### `CODE-SOLID-001` — Single Responsibility
**Severidad:** medium · **Aplica a:** all

Cada módulo/clase/función tiene una sola razón para cambiar.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `class\s+\w+[\s\S]{3000,}?\n\}`    # clases enormes (proxy de SRP roto)
- `\b(utils?|helpers?|misc|common)\.(py|ts|js)` # archivos genéricos basurero
- *(SRP — revisión LLM-judge necesaria para detectar mezcla de responsabilidades)*
**Señal de N/A:** módulo trivial (un archivo, una función, sin clases).

**Verificar:**
- [ ] Un cambio en una regla de negocio debería tocar pocos lugares, no muchos.
- [ ] Los módulos no mezclan HTTP, dominio, persistencia y presentación.
- [ ] Archivos no exceden ~300-500 líneas salvo justificación.

**Banderas rojas:**
- Una clase que valida, persiste, envía emails y formatea HTML.
- Archivo `utils.py` gigante con decenas de funciones no relacionadas.

---

#### `CODE-SOLID-002` — Open/Closed
**Severidad:** low · **Aplica a:** all

Se puede extender el comportamiento sin modificar el código existente (ej:
agregar una nueva estrategia sin reescribir la clase base).

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `if\s+type\s*==\s*["']\w+["'][\s\S]{0,200}elif\s+type\s*==[\s\S]{0,200}elif\s+type\s*==` # cadena type==
- `switch\s*\([^)]+\)\s*\{[\s\S]{2000,}?\}`  # switch enorme
- `else\s+if[\s\S]{0,300}else\s+if[\s\S]{0,300}else\s+if[\s\S]{0,300}else\s+if` # ≥4 elif
- *(extensibilidad — revisión LLM-judge complementa)*
**Señal de N/A:** sin variabilidad de comportamiento (un solo path de ejecución por diseño).

**Verificar:**
- [ ] Nuevas variantes (nuevos proveedores, nuevos tipos de recurso) se agregan por extensión.
- [ ] Registros/maps/enums reemplazan cadenas largas de `if/elif/switch` cuando el número de casos crece.

**Banderas rojas:**
- `if type == "A": ... elif type == "B": ... elif ...` con 10 ramas que crecen con cada feature.

---

#### `CODE-SOLID-003` — Liskov Substitution
**Severidad:** medium · **Aplica a:** all

Una subclase debe poder reemplazar a su base sin romper el contrato.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `raise\s+NotImplementedError`      # subclase desactiva método heredado (smell)
- `throw\s+new\s+NotSupportedException` # equivalente Java/.NET
- `throw\s+new\s+Error\(["']Not implemented` # JS/TS
- `@override[\s\S]{0,50}raise\s+\w+Error` # override que solo lanza error
**Señal de N/A:** sin jerarquía de herencia (composición pura, sin clases base extendidas).

**Verificar:**
- [ ] Las subclases cumplen las precondiciones/postcondiciones de la base.
- [ ] Las subclases no lanzan excepciones distintas no documentadas.
- [ ] No hay "smell": subclases que desactivan métodos con `NotImplementedError`.

---

#### `CODE-SOLID-004` — Interface Segregation
**Severidad:** low · **Aplica a:** all

Las interfaces son pequeñas y específicas; un cliente no debería depender de
métodos que no usa.

**Dónde buscar:** `**/*.{ts,tsx,go,java,cs,kt}`, `**/*.py` (excluir `node_modules`, `dist`, `build`, `.venv`)
**Patrones:**
- `interface\s+\w+\s*\{[\s\S]{800,}?\}` # interface fat (TS/Java/Go)
- `class\s+\w+\(Protocol\)[\s\S]{800,}?\n\)` # Protocol Python con muchos miembros
- `abstract\s+class\s+\w+[\s\S]{1500,}?\n\}` # clases abstractas enormes
**Señal de N/A:** lenguajes sin interfaces explícitas (JS sin TS) o módulo sin abstracciones.

**Verificar:**
- [ ] Interfaces pequeñas (2-5 métodos), específicas al uso.
- [ ] Se prefieren varias interfaces chicas a una "fat interface".

---

#### `CODE-SOLID-005` — Dependency Inversion (inyección de dependencias)
**Severidad:** medium · **Aplica a:** all

Los componentes de alto nivel dependen de abstracciones, no de implementaciones
concretas. Las implementaciones se inyectan.

**Dónde buscar:** `**/services/**`, `**/usecases/**`, `**/*.{ts,tsx,js,jsx,py,go,java,cs,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `def\s+__init__\(self[^)]*\):[\s\S]{0,200}self\.\w+\s*=\s*\w+Client\(` # crea cliente concreto en init
- `constructor\s*\([^)]*\)\s*\{[\s\S]{0,200}this\.\w+\s*=\s*new\s+\w+Client\(` # equivalente JS/TS
- `os\.getenv\(|process\.env\.`      # lectura de env en medio de la lógica
- `new\s+\w+(Repository|Service|Client)\(\s*\)` # instanciación dura
**Señal de N/A:** funciones puras sin dependencias I/O o configuración externa.

**Verificar:**
- [ ] Los servicios reciben sus dependencias (clientes HTTP, repos, etc.) por constructor/parámetro, no las crean internamente.
- [ ] La configuración entra por inyección/argumentos, no por lectura global dentro del módulo.
- [ ] Los tests pueden inyectar dobles.

**Banderas rojas:**
- `class FooService: def __init__(self): self.client = HttpClient()` — imposible mockear sin monkey patch.
- Lectura de `os.getenv(...)` en medio de lógica de negocio.

---

## D. DRY y YAGNI

#### `CODE-DRY-001` — Duplicación significativa se extrae
**Severidad:** medium · **Aplica a:** all

Cuando tres (o dos obvios) bloques de código son casi iguales, se extraen. Pero
no se abstrae prematuramente.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `try\s*:\s*\n[\s\S]{0,400}except\s+\w+[\s\S]{0,300}logger\.(error|exception)` # patrón try/except/log que probablemente se repite
- `res(?:ponse)?\.status\(\d+\)\.json\(\{` # construcción HTTP repetida en handlers
- *(duplicación — `jscpd`, `pmd cpd`, `dupfinder` detectan mejor que regex)*
**Señal de N/A:** base de código pequeña (<500 LOC) donde la duplicación no es viable aún.

**Verificar:**
- [ ] No hay bloques de > 5–10 líneas duplicados literalmente en múltiples lugares.
- [ ] Patrones comunes (logging, error handling, validación) viven en util compartida.
- [ ] Se distingue coincidencia accidental de verdadera reutilización (la regla de tres).

**Banderas rojas:**
- El mismo try/except replicado 20 veces.
- Handlers HTTP que repiten la misma construcción de respuesta.

**Herramientas:** jscpd, dupfinder, PMD CPD, sonar duplication.

---

#### `CODE-YAGNI-001` — Sin sobre-ingeniería
**Severidad:** medium · **Aplica a:** all

No se agrega abstracción para un caso de uso hipotético.

**Dónde buscar:** `**/*.{ts,tsx,js,jsx,py,go,rs,java,cs,rb,php,kt}` (excluir `node_modules`, `dist`, `build`, `.venv`, `**/tests/**`)
**Patrones:**
- `\b\w*Factory\w*Factory\b`         # factory de factory
- `\bAbstract\w+Factory\b`           # abstract factory
- `\b(deprecated|unused|legacy|old|backup)\b.*\.(py|ts|js|java)` # archivos zombi
- *(over-engineering — revisión LLM-judge necesaria; un grep no detecta YAGNI)*
**Señal de N/A:** proyecto pequeño/inicial sin presión de escalabilidad.

**Verificar:**
- [ ] Las interfaces con una sola implementación se justifican (tests son válidos).
- [ ] Los parámetros que siempre se pasan con el mismo valor se eliminan.
- [ ] Features dead que nadie consume se remueven.

**Banderas rojas:**
- Factory de factories de factories.
- Plugins/hooks elaborados sin un segundo consumidor real.
- Config options que no se usan ni documentan.

---

## E. Estructura del proyecto

#### `CODE-STRUCT-001` — Capas separadas y dependencias en una dirección
**Severidad:** high · **Aplica a:** backend

El proyecto tiene capas claras (por ejemplo: handlers → services → repositories
→ dominio) y las dependencias fluyen hacia adentro (Clean/Hexagonal).

**Dónde buscar:** `**/domain/**`, `**/entities/**`, `**/models/**`, `**/*.{ts,tsx,js,jsx,py,go,java,cs}`, `**/.dependency-cruiser*`, `**/madge*`, `**/dpdm*`
**Patrones:**
- `domain/.*\b(from\s+(fastapi|express|django|flask)|import\s+.*(express|fastapi))` # framework HTTP en dominio
- `(entities?|models?)/[^.]+\.(py|ts|js).*(execute|raw_sql|\.query\()` # SQL en entidades
- `@OneToMany[\s\S]{0,100}@ManyToOne[\s\S]{0,400}@OneToMany` # ORM con cruces probablemente cíclicos
- `from\s+\.\.\w+\s+import\s+\w+`    # imports relativos cross-layer (revisar)
**Señal de N/A:** monolito script sin capas / proyecto frontend puro sin backend.

**Verificar:**
- [ ] La dirección de dependencias está definida y documentada.
- [ ] No hay imports cíclicos.
- [ ] El dominio no conoce HTTP ni SQL específicos.
- [ ] Los adaptadores (DB, HTTP client) implementan interfaces del dominio.

**Banderas rojas:**
- El modelo de dominio importa `fastapi`, `express`, `django.http`.
- Query SQL en un handler HTTP sin pasar por un repo.
- Módulo A importa B, B importa C, C importa A — en TypeScript/Node.js los circular imports hacen que módulos se resuelvan como `undefined` en tiempo de ejecución, generando bugs difíciles de reproducir.
- ORM entities con referencias cruzadas directas que crean dependencias circulares al cargar (TypeORM, Sequelize).

**Herramientas:** `madge --circular src/` · `dependency-cruiser --validate` · `dpdm --circular` (TypeScript/Node.js) · `pydeps --noshow` (Python).

---

#### `CODE-STRUCT-002` — Co-locación razonable
**Severidad:** low · **Aplica a:** all

Los archivos que cambian juntos viven cerca.

**Dónde buscar:** `**/*.test.{ts,tsx,js,jsx}`, `**/test_*.py`, `**/*_test.go`, `**/utils/**`, `**/helpers/**`
**Patrones:**
- `utils?/[^/]+\.(py|ts|js)$`        # carpeta utils con muchos archivos heterogéneos
- `^src/utils/.*\.(py|ts|js)$`       # idem
- *(co-locación — revisión estructural manual + LLM-judge)*
**Señal de N/A:** repo monoarchivo o estructura aún no establecida (proyecto nuevo).

**Verificar:**
- [ ] Los tests están junto al código o en carpeta espejo consistente.
- [ ] Los componentes de UI tienen sus estilos y utilidades en una carpeta.
- [ ] No hay un `utils/` gigante que acumula todo.

---

## Checklist resumen

| ID                  | Control                                          | Severidad |
| ------------------- | ------------------------------------------------ | --------- |
| CODE-FN-001         | Funciones cortas                                 | medium    |
| CODE-FN-002         | Parámetros limitados                             | medium    |
| CODE-FN-003         | Sin flag arguments                               | low       |
| CODE-FN-004         | Complejidad ciclomática ≤ 10                     | medium    |
| CODE-FN-005         | Funciones puras cuando es posible                | low       |
| CODE-FN-006         | Sin mutación sorpresa                            | medium    |
| CODE-ERR-001        | Excepciones específicas                          | high      |
| CODE-ERR-002        | Stack preservado al re-lanzar                    | medium    |
| CODE-ERR-003        | Jerarquía de excepciones custom                  | low       |
| CODE-ERR-004        | Errores en el borde                              | medium    |
| CODE-ERR-005        | Recursos liberados en excepción                  | high      |
| CODE-SOLID-001      | Single Responsibility                            | medium    |
| CODE-SOLID-002      | Open/Closed                                      | low       |
| CODE-SOLID-003      | Liskov Substitution                              | medium    |
| CODE-SOLID-004      | Interface Segregation                            | low       |
| CODE-SOLID-005      | Dependency Inversion                             | medium    |
| CODE-DRY-001        | Duplicación significativa extraída               | medium    |
| CODE-YAGNI-001      | Sin sobre-ingeniería                             | medium    |
| CODE-STRUCT-001     | Capas con dependencia unidireccional             | high      |
| CODE-STRUCT-002     | Co-locación razonable                            | low       |
