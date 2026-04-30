# 03 · Calidad de código · Funciones, complejidad y SOLID

> Reglas sobre tamaño y complejidad de funciones, principios SOLID, DRY y YAGNI.
>
> **Marcos de referencia:** Clean Code · SOLID (Robert C. Martin) · Refactoring (Martin Fowler).

---

## A. Funciones

#### `CODE-FN-001` — Funciones cortas y enfocadas
**Severidad:** medium · **Aplica a:** all

Cada función hace **una** cosa bien. Lo demás se extrae.

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

**Verificar:**
- [ ] Evitar booleanos que seleccionan ramas grandes dentro de la función.
- [ ] Preferir dos funciones pequeñas con intención clara (`send_email_now()` vs `schedule_email()`).

**Banderas rojas:**
- `def process(item, is_preview=False): if is_preview: ... else: ...` donde las ramas son 80% distintas.

---

#### `CODE-FN-004` — Complejidad ciclomática acotada
**Severidad:** medium · **Aplica a:** all

Las funciones muy anidadas son difíciles de leer y de testear.

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

**Verificar:**
- [ ] La lógica de negocio (cálculos, validaciones, transformaciones) tiende a ser pura.
- [ ] Los efectos (I/O, escritura, randomness, tiempo) están concentrados en funciones identificables.
- [ ] Las funciones con I/O tienen nombres que lo delatan (`fetch_*`, `save_*`, `send_*`).

---

#### `CODE-FN-006` — Sin mutación de parámetros de entrada sin documentar
**Severidad:** medium · **Tags:** `bug-risk` · **Aplica a:** all

Modificar el argumento que el llamador te pasó es sorpresa. Si se hace, el
nombre lo refleja y la documentación lo aclara.

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

**Verificar:**
- [ ] Hay un `BaseAppError` / equivalente y todas las excepciones heredan de él.
- [ ] Categorías claras: `ValidationError`, `AuthError`, `NotFoundError`, `ExternalServiceError`.
- [ ] Las excepciones cargan datos estructurados, no solo un string.

---

#### `CODE-ERR-004` — Errores en borde, no en cada capa
**Severidad:** medium · **Aplica a:** all

Las capas intermedias propagan; solo la capa frontera (HTTP handler,
command handler, worker entry) traduce a respuesta/log.

**Verificar:**
- [ ] Services/repositories no convierten excepciones en responses HTTP.
- [ ] Solo el borde (controller/handler) decide qué respuesta producir ante cada excepción.
- [ ] El logging de errores está centralizado.

---

#### `CODE-ERR-005` — Recursos liberados aunque haya excepción
**Severidad:** high · **Tags:** `resource-leak`, `cwe-404` · **Aplica a:** all

Conexiones, archivos, locks, etc., se liberan siempre.

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

**Verificar:**
- [ ] Nuevas variantes (nuevos proveedores, nuevos tipos de recurso) se agregan por extensión.
- [ ] Registros/maps/enums reemplazan cadenas largas de `if/elif/switch` cuando el número de casos crece.

**Banderas rojas:**
- `if type == "A": ... elif type == "B": ... elif ...` con 10 ramas que crecen con cada feature.

---

#### `CODE-SOLID-003` — Liskov Substitution
**Severidad:** medium · **Aplica a:** all

Una subclase debe poder reemplazar a su base sin romper el contrato.

**Verificar:**
- [ ] Las subclases cumplen las precondiciones/postcondiciones de la base.
- [ ] Las subclases no lanzan excepciones distintas no documentadas.
- [ ] No hay "smell": subclases que desactivan métodos con `NotImplementedError`.

---

#### `CODE-SOLID-004` — Interface Segregation
**Severidad:** low · **Aplica a:** all

Las interfaces son pequeñas y específicas; un cliente no debería depender de
métodos que no usa.

**Verificar:**
- [ ] Interfaces pequeñas (2-5 métodos), específicas al uso.
- [ ] Se prefieren varias interfaces chicas a una "fat interface".

---

#### `CODE-SOLID-005` — Dependency Inversion (inyección de dependencias)
**Severidad:** medium · **Aplica a:** all

Los componentes de alto nivel dependen de abstracciones, no de implementaciones
concretas. Las implementaciones se inyectan.

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
