# 14 · Documentación · Código y API

> Docstrings, README, API docs, changelog.

---

## A. Documentación en el código

#### `DOC-CODE-001` — API pública documentada
**Severidad:** medium · **Aplica a:** all

Cada símbolo público (función, clase, módulo) tiene docstring que explica qué
hace y por qué.

(Ver `CODE-DOC-001`.)

---

#### `DOC-CODE-002` — Tipos y contratos explícitos
**Severidad:** medium · **Aplica a:** all

Type hints / tipos estáticos son la primera línea de documentación.

(Ver `CODE-TYPE-001`.)

---

#### `DOC-CODE-003` — Comentarios explican el "por qué"
**Severidad:** low · **Aplica a:** all

(Ver `CODE-DOC-002`.)

---

## B. README y docs del repo

#### `DOC-README-001` — README con lo mínimo imprescindible
**Severidad:** high · **Aplica a:** all

El README permite a alguien nuevo entender qué es el proyecto, cómo correrlo,
y dónde encontrar más.

**Verificar:**
- [ ] Título y descripción corta del propósito.
- [ ] Requisitos (versiones, servicios externos).
- [ ] Cómo correr local (1-command idealmente).
- [ ] Cómo correr tests.
- [ ] Cómo desplegar / link a docs de deploy.
- [ ] Link a documentación más extensa si existe.
- [ ] Licencia y cómo contribuir.

---

#### `DOC-README-002` — .env.example y configuración documentada
**Severidad:** high · **Aplica a:** all

Las variables de entorno están listadas con descripción.

**Verificar:**
- [ ] `.env.example` con todas las variables necesarias.
- [ ] Cada variable tiene comentario de para qué sirve y ejemplo de valor.
- [ ] Se separan las obligatorias de las opcionales.
- [ ] Se indica qué secretos deben venir del vault.

---

#### `DOC-README-003` — Estructura del repo explicada
**Severidad:** medium · **Aplica a:** all

El repo tiene sección que explica la estructura de carpetas a alto nivel.

**Verificar:**
- [ ] Mapa de carpetas principales con explicación de 1 línea.
- [ ] Si hay monorepo, cada paquete tiene su propio README.

---

## C. API docs

#### `DOC-API-001` — OpenAPI / schema fuente de verdad
**Severidad:** high · **Aplica a:** api

(Ver `API-DOC-001`.)

---

#### `DOC-API-002` — Ejemplos completos por endpoint
**Severidad:** medium · **Aplica a:** api

(Ver `API-DOC-002`.)

---

#### `DOC-API-003` — Errores comunes documentados con ejemplos
**Severidad:** medium · **Aplica a:** api

Cada endpoint documenta los errores 4xx y 5xx que puede devolver, con ejemplo.

**Verificar:**
- [ ] `responses` en OpenAPI incluyen los errores relevantes.
- [ ] Estructura de error documentada en un solo lugar, referenciada desde cada endpoint.
- [ ] Relación código de error → razón → acción documentada.

---

#### `DOC-API-004` — Guías de uso más allá de la referencia
**Severidad:** medium · **Aplica a:** api

Además de la referencia (qué hace cada endpoint), hay guías (cómo hacer X).

**Verificar:**
- [ ] Guías para casos de uso comunes (autenticarse, subir archivo, manejar async).
- [ ] Tutorial "hello world" para un integrador nuevo.
- [ ] Ejemplos en múltiples lenguajes si el proyecto lo amerita.

---

## D. Changelog y release notes

#### `DOC-CHANGE-001` — Changelog mantenido
**Severidad:** medium · **Aplica a:** all

Cada release tiene entrada en el changelog con cambios, breaking y migración.

**Verificar:**
- [ ] `CHANGELOG.md` estilo Keep a Changelog o similar.
- [ ] Versiones siguen SemVer.
- [ ] Breaking changes destacados.
- [ ] Links a PRs/issues para contexto.

---

#### `DOC-CHANGE-002` — Release notes para usuarios
**Severidad:** medium · **Aplica a:** product · content

Además del changelog técnico, hay comunicación al usuario final.

**Verificar:**
- [ ] "What's new" accesible en el producto.
- [ ] Breaking changes comunicados con anticipación.
- [ ] Feature flags comunicados cuando se lanzan en GA.

---

## E. Onboarding y docs operacionales

#### `DOC-ON-001` — Onboarding para devs nuevos
**Severidad:** medium · **Aplica a:** process

Existe docs/checklist para que un dev nuevo sea productivo en < 1 semana.

**Verificar:**
- [ ] Checklist de setup (acceso, cuentas, herramientas).
- [ ] Código guía donde empezar a leer.
- [ ] "Good first issues" etiquetados.
- [ ] Canal de apoyo / buddy.

---

#### `DOC-ON-002` — Docs operacionales accesibles
**Severidad:** medium · **Aplica a:** infra · process

(Ver `OBS-RUN-001` para runbooks.)

**Verificar:**
- [ ] Cómo hacer un release.
- [ ] Cómo rollback.
- [ ] Cómo escalar / shrink.
- [ ] Contactos de emergencia.

---

## Checklist resumen

| ID                | Control                                          | Severidad |
| ----------------- | ------------------------------------------------ | --------- |
| DOC-CODE-001      | API pública con docstring                        | medium    |
| DOC-CODE-002      | Tipos explícitos                                 | medium    |
| DOC-CODE-003      | Comentarios explican por qué                     | low       |
| DOC-README-001    | README mínimo                                    | high      |
| DOC-README-002    | .env.example documentado                         | high      |
| DOC-README-003    | Estructura del repo explicada                    | medium    |
| DOC-API-001       | OpenAPI fuente de verdad                         | high      |
| DOC-API-002       | Ejemplos por endpoint                            | medium    |
| DOC-API-003       | Errores documentados                             | medium    |
| DOC-API-004       | Guías de uso                                     | medium    |
| DOC-CHANGE-001    | Changelog                                        | medium    |
| DOC-CHANGE-002    | Release notes al usuario                         | medium    |
| DOC-ON-001        | Onboarding para devs                             | medium    |
| DOC-ON-002        | Docs operacionales                               | medium    |
