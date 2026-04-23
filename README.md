# Checklist v2 — Code Review Kit

Catálogo modular de checklists de **code review**, diseñado para ser consumido por un agente
de revisión automatizada (LLM) **y** por revisores humanos.

- Agnóstico de lenguaje/framework: los controles están redactados en términos de
  **comportamiento esperado** y **señales de problema**, no de API de una librería concreta.
- Cada control tiene un **ID estable**, una **severidad**, y **banderas rojas** accionables.
- Dividido en módulos pequeños (200-400 líneas) para que el agente cargue solo lo relevante.
- Un **índice maestro** (`index.yaml`) permite consumo programático.

---

## Estructura

```
checklist-v2/
├── README.md                  ← Este archivo (guía de uso)
├── index.yaml                 ← Catálogo estructurado de TODOS los controles
├── _templates/
│   └── control-template.md    ← Plantilla para agregar nuevos controles
├── 01-seguridad/              ← OWASP Top 10, auth, criptografía, headers, archivos
├── 02-api-diseno/             ← REST, versionado, paginación, idempotencia
├── 03-calidad-codigo/         ← Estilo, naming, SOLID, complejidad, errores
├── 04-testing/                ← Estrategia, unit, integración, E2E, mocks
├── 05-rendimiento/            ← Frontend (CWV), backend async, BD, caché
├── 06-proteccion-datos/       ← GDPR-style, PII, consentimiento, retención
├── 07-ia-llm/                 ← Prompts, seguridad, costos, hallucinations
├── 08-usabilidad-ux/          ← Nielsen, feedback, formularios, estados UI
├── 09-accesibilidad/          ← WCAG 2.2 AA (perceptible, operable, comprensible, robusto)
├── 10-observabilidad/         ← Logs, métricas RED/USE, tracing, SLOs, alertas
├── 11-cicd-devops/            ← Pipelines, quality gates, releases, rollback
├── 12-arquitectura/           ← Principios de diseño, resiliencia, fronteras
├── 13-base-datos/             ← Esquema, migraciones, índices, transacciones
└── 14-documentacion/          ← Código, API, ADRs, documentación operacional
```

Cada categoría contiene 2–4 archivos `.md`, cada uno con entre 10 y 30 controles agrupados.

---

## Convención de IDs

Formato: `<CATEGORÍA>-<SUBCATEGORÍA>-<NNN>`

Ejemplos:

| ID                | Categoría       | Subcategoría        |
| ----------------- | --------------- | ------------------- |
| `SEC-AUTH-001`    | Seguridad       | Autenticación       |
| `SEC-INPUT-014`   | Seguridad       | Validación entrada  |
| `API-REST-007`    | API             | Diseño REST         |
| `PERF-DB-003`     | Performance     | Base de datos       |
| `A11Y-KBD-005`    | Accesibilidad   | Teclado             |
| `LLM-PROMPT-002`  | IA/LLM          | Prompts             |
| `DATA-RET-004`    | Protección datos| Retención           |

Los IDs son **estables** — no se reutilizan ni renumeran cuando se eliminan controles.

---

## Niveles de severidad

| Severidad    | Cuándo usarla                                                              | Acción del agente            |
| ------------ | -------------------------------------------------------------------------- | ---------------------------- |
| `critical`   | Riesgo directo de brecha, pérdida de datos, vulnerabilidad explotable      | Bloquear merge               |
| `high`       | Bug funcional serio, impacto en producción probable                        | Exigir cambios antes de merge|
| `medium`     | Mejora importante de mantenibilidad/performance, sin riesgo inmediato      | Comentario fuerte, no bloqueo|
| `low`        | Mejora de estilo o consistencia                                            | Sugerencia (nit)             |
| `info`       | Buenas prácticas, no obligatorio                                           | Comentario informativo       |

---

## Formato de cada control

```markdown
#### `SEC-AUTH-001` — Hash de contraseñas con algoritmo moderno
**Severidad:** critical · **Tags:** `owasp-a07`, `cwe-256` · **Aplica a:** backend

Las contraseñas deben almacenarse únicamente como hashes bcrypt/argon2/scrypt
con factor de costo moderno. Nunca MD5, SHA-1, ni SHA-2 crudo.

**Verificar:**
- [ ] Las contraseñas nunca se almacenan ni se loguean en texto plano.
- [ ] El algoritmo de hashing es bcrypt, argon2 o scrypt.
- [ ] El factor de costo/iteraciones es apropiado al hardware actual.
- [ ] La comparación de hashes es de tiempo constante.

**Banderas rojas (red flags):**
- Funciones de hash rápidas (MD5, SHA-1, SHA-256 crudo) aplicadas a passwords.
- Comparación de hashes con `==` en lenguajes donde no es tiempo constante.
- Secretos/salts globales hardcodeados en el código.

**Referencias:** OWASP ASVS 2.4 · CWE-256 · NIST SP 800-63B §5.1.1.2
```

---

## Cómo debe usarlo un **agente de code review**

1. **Cargar `index.yaml`** para obtener el catálogo completo de controles.
2. **Seleccionar los módulos relevantes** al diff bajo revisión (ej: cambios en archivos
   de autenticación → cargar `01-seguridad/01-autenticacion.md`).
3. **Para cada control**, buscar **banderas rojas** en el diff y evaluar si los
   ítems "Verificar" se cumplen.
4. **Producir hallazgos** con el siguiente formato (una entrada por violación):

```yaml
- control_id: SEC-AUTH-001
  severity: critical
  file: backend/auth/register.py
  line: 42
  evidence: |
    hashlib.sha256(password.encode()).hexdigest()
  explanation: |
    Se está hasheando la contraseña con SHA-256 directo, sin salt ni KDF.
    Si la BD se filtra, las contraseñas son recuperables con ataques de diccionario.
  suggestion: |
    Usar bcrypt o argon2. En Python: `from passlib.hash import bcrypt`.
  confidence: high
```

5. **Agregar un resumen** al final: por categoría y severidad, cuántos hallazgos.
6. **No inventar controles** fuera del catálogo — si detecta algo que no está,
   reportarlo como `OTHER` y sugerir crearlo.

---

## Cómo debe usarlo un **revisor humano**

1. Leer el README del módulo correspondiente al cambio.
2. Marcar cada control con uno de:
   - `[x]` verificado, sin problemas
   - `[!]` problema detectado (dejar comentario en el PR referenciando el ID)
   - `[~]` no aplica
3. Priorizar los controles `critical` y `high` primero.

---

## Cómo agregar un **nuevo control**

1. Copiar `_templates/control-template.md`.
2. Asignar un ID siguiendo la convención. Verificar que no esté ya tomado en
   `index.yaml`.
3. Añadir el control al archivo `.md` apropiado.
4. Añadir una entrada en `index.yaml`.
5. Si creas una categoría nueva, documentarla aquí y en el índice.

---

## Cómo agregar una **nueva categoría**

1. Crear carpeta `NN-nombre/`.
2. Elegir un prefijo de 2–5 letras para los IDs (ej: `OBS` para observabilidad).
3. Agregar la categoría en `index.yaml` bajo `categories:`.
4. Documentarla en la sección **Estructura** de este README.

---

## Fuentes y estándares de referencia

- **Seguridad:** OWASP API Security Top 10 (2023), OWASP Web Top 10 (2021), OWASP ASVS 4.0, CWE Top 25, SANS Top 25
- **API:** Richardson Maturity Model, JSON:API, OpenAPI 3.1, RFC 7231, RFC 7807, Google API Design Guide, Microsoft REST API Guidelines
- **Código:** Clean Code (R.C. Martin), SOLID, Effective Software Testing, Refactoring (Fowler)
- **Privacidad:** GDPR (UE), CCPA (EE.UU.), LGPD (Brasil), Ley 19.628 y Ley 21.719 (Chile)
- **Accesibilidad:** WCAG 2.2 AA (W3C), ARIA 1.2
- **UX:** Nielsen Norman Group 10 heurísticas
- **Observabilidad:** Google SRE book (SLOs), OpenTelemetry, RED/USE methods
- **Testing:** Testing Trophy (Kent C. Dodds), FIRST, AAA
- **IA/LLM:** OWASP Top 10 for LLM Applications, NIST AI RMF, Anthropic/OpenAI safety guidelines

---

## Versionado del propio catálogo

Este catálogo sigue versionado semántico:

- `MAJOR`: cambios breaking (eliminación de controles, cambio de estructura de IDs).
- `MINOR`: nuevos controles o categorías.
- `PATCH`: correcciones de redacción, nuevas referencias.

Versión actual: **2.0.0** (ver `index.yaml`).
