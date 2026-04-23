# 14 · Documentación · ADRs, diagramas y docs operacional

> Architecture Decision Records, diagramas C4, runbooks, glosarios de dominio.

---

## A. Architecture Decision Records (ADRs)

#### `DOC-ADR-001` — ADRs para decisiones significativas
**Severidad:** medium · **Aplica a:** documentation · process

Las decisiones de arquitectura, tecnologías, trade-offs importantes se
documentan como ADRs.

**Verificar:**
- [ ] Carpeta `/docs/adr/` o similar con ADRs numerados.
- [ ] Cada ADR tiene: contexto, decisión, consecuencias, alternativas consideradas.
- [ ] Formato consistente (Michael Nygard template u similar).
- [ ] Status: proposed / accepted / deprecated / superseded.
- [ ] ADRs superseded enlazan al que los reemplaza.

**Ejemplos de decisiones que merecen ADR:**
- Elección de BD (Postgres vs Mongo).
- Lenguaje/framework principal.
- Estrategia de multi-tenancy.
- Patrón de autenticación.
- Estrategia de deploy.

---

#### `DOC-ADR-002` — ADRs actualizados con la realidad
**Severidad:** low · **Aplica a:** documentation

Los ADRs reflejan lo que realmente se hizo, no planes abandonados sin rastro.

**Verificar:**
- [ ] Si una decisión cambia, se abre un nuevo ADR que supersede al anterior.
- [ ] No se editan ADRs aceptados (son históricos).
- [ ] Revisión anual de ADRs vs realidad.

---

## B. Diagramas

#### `DOC-DIAG-001` — Diagramas C4 (al menos Context y Container)
**Severidad:** medium · **Aplica a:** documentation

Existen diagramas estilo C4 que muestran el sistema a distintos niveles.

**Verificar:**
- [ ] **Context**: el sistema en su entorno, usuarios y sistemas externos.
- [ ] **Container**: aplicaciones, servicios, BDs del sistema.
- [ ] **Component** (opcional): componentes dentro de un container.
- [ ] **Code** (opcional, raras veces útil más allá del IDE).

---

#### `DOC-DIAG-002` — Diagramas en formato editable, no imágenes estáticas
**Severidad:** low · **Aplica a:** documentation

Los diagramas viven como texto (Mermaid, PlantUML, Structurizr, D2) para que
evolucionen con el sistema.

**Verificar:**
- [ ] Formato text-based versionable.
- [ ] Render automático en la wiki/docs.
- [ ] Fuentes commiteadas junto al código que describen.

---

#### `DOC-DIAG-003` — Diagramas de flujo críticos documentados
**Severidad:** medium · **Aplica a:** documentation

Flujos complejos (onboarding, checkout, ingestión de datos) tienen diagrama
de secuencia o flujo.

**Verificar:**
- [ ] Diagrama por flujo crítico.
- [ ] Muestra componentes involucrados, datos y puntos de fallo.
- [ ] Actualizado cuando cambia el flujo.

---

## C. Documentación operacional

#### `DOC-OPS-001` — Runbooks por alerta crítica
**Severidad:** medium · **Aplica a:** documentation · observability

(Ver `OBS-RUN-001`.)

---

#### `DOC-OPS-002` — Playbook de incidentes
**Severidad:** medium · **Aplica a:** process

Procedimiento claro ante incidentes: detección → contención → mitigación →
comunicación → post-mortem.

**Verificar:**
- [ ] Roles definidos (incident commander, comms, ops).
- [ ] Canales (war room, status page).
- [ ] Plantilla de post-mortem.
- [ ] Se ensaya (game days).

---

#### `DOC-OPS-003` — Procedimientos de soporte
**Severidad:** low · **Aplica a:** process

Para casos comunes del equipo de soporte, hay procedimientos escritos.

**Verificar:**
- [ ] Cómo resetear una cuenta.
- [ ] Cómo extender una suscripción manualmente.
- [ ] Cómo reproducir bugs comunes.
- [ ] Cuándo escalar a ingeniería.

---

## D. Glosario y dominio

#### `DOC-DOM-001` — Glosario del dominio (Ubiquitous Language)
**Severidad:** medium · **Aplica a:** documentation

Los términos del dominio están definidos en un glosario compartido.

**Verificar:**
- [ ] Glosario en el repo/wiki.
- [ ] Los términos se usan consistentemente en código, UI, docs, soporte.
- [ ] Se actualiza cuando aparecen términos nuevos.
- [ ] Alineado con el lenguaje del cliente, no jerga interna.

---

## E. Seguridad y cumplimiento

#### `DOC-COMP-001` — Política de privacidad accesible
**Severidad:** critical · **Aplica a:** legal · frontend

(Ver `DATA-TRANS-001`.)

---

#### `DOC-COMP-002` — Documentación de cumplimiento
**Severidad:** medium · **Aplica a:** legal · documentation

Los procedimientos que exige el régimen aplicable (GDPR, SOC2, ISO 27001,
HIPAA) están documentados.

**Verificar:**
- [ ] Registro de tratamientos.
- [ ] Políticas de seguridad.
- [ ] Procedimiento de respuesta a brechas.
- [ ] Inventario de sub-procesadores.
- [ ] Evidencia auditable cuando aplica.

---

#### `DOC-COMP-003` — Threat model actualizado
**Severidad:** medium · **Tags:** `security` · **Aplica a:** security · documentation

El threat model del sistema se revisa periódicamente.

**Verificar:**
- [ ] Threat model documentado (STRIDE, LINDDUN u otro).
- [ ] Assets identificados.
- [ ] Superficies de ataque mapeadas.
- [ ] Mitigaciones documentadas.
- [ ] Revisión al menos anual o cuando cambia la arquitectura.

---

## F. Documentación de datos

#### `DOC-DATA-001` — Data dictionary / catálogo
**Severidad:** medium · **Aplica a:** data · documentation

Las tablas y campos importantes están documentados.

**Verificar:**
- [ ] Descripción por tabla y columna importante.
- [ ] Clasificación de sensibilidad (ver `DATA-INV-002`).
- [ ] Relación con otras tablas.
- [ ] Ejemplos / rangos esperados.

---

#### `DOC-DATA-002` — Pipelines y transformaciones documentadas
**Severidad:** medium · **Aplica a:** data

Si hay ETL/ELT, está documentado: fuentes, transformaciones, destinos.

**Verificar:**
- [ ] Cada pipeline tiene owner y descripción.
- [ ] Dependencias y schedule visibles.
- [ ] SLAs declarados.

---

## Checklist resumen

| ID             | Control                                           | Severidad |
| -------------- | ------------------------------------------------- | --------- |
| DOC-ADR-001    | ADRs para decisiones significativas               | medium    |
| DOC-ADR-002    | ADRs actualizados                                 | low       |
| DOC-DIAG-001   | Diagramas C4                                      | medium    |
| DOC-DIAG-002   | Diagramas como texto                              | low       |
| DOC-DIAG-003   | Diagramas de flujos críticos                      | medium    |
| DOC-OPS-001    | Runbooks (→ observabilidad)                       | medium    |
| DOC-OPS-002    | Playbook de incidentes                            | medium    |
| DOC-OPS-003    | Procedimientos de soporte                         | low       |
| DOC-DOM-001    | Glosario del dominio                              | medium    |
| DOC-COMP-001   | Política de privacidad                            | critical  |
| DOC-COMP-002   | Documentación de cumplimiento                     | medium    |
| DOC-COMP-003   | Threat model                                      | medium    |
| DOC-DATA-001   | Data dictionary                                   | medium    |
| DOC-DATA-002   | Pipelines documentadas                            | medium    |
