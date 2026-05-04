# 14 · Documentación · ADRs, diagramas y docs operacional

> Architecture Decision Records, diagramas C4, runbooks, glosarios de dominio.

---

## A. Architecture Decision Records (ADRs)

#### `DOC-ADR-001` — ADRs para decisiones significativas
**Severidad:** medium · **Aplica a:** documentation · process

Las decisiones de arquitectura, tecnologías, trade-offs importantes se
documentan como ADRs.

**Dónde buscar:** `docs/adr/**`, `**/adr/**`, `**/decisions/**`, `docs/architecture/decisions/**`
**Patrones:**
- `^#\s*(ADR|\d{4})[-:\s]`     # encabezado típico de ADR
- `^##?\s*(Context|Contexto|Decision|Decisión|Consequences|Consecuencias|Alternatives)`     # secciones del template
- `^Status:\s*(Proposed|Accepted|Deprecated|Superseded)`     # estado declarado
- `Superseded\s*by\s*\[?ADR`     # links de supersession
- `\d{4}-[a-z0-9-]+\.md$`     # nombres numerados (regex en file path)
**Señal de N/A:** repo sin decisiones de arquitectura propias (fork de upstream, scaffolding de framework, app trivial CRUD).

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

**Dónde buscar:** `docs/adr/**`, `**/adr/**`, `**/decisions/**`
**Patrones:**
- `^Status:\s*Proposed`     # ADRs estancados en proposed (cruzar con fecha)
- `Superseded\s*by`     # cadena de supersession presente
- `Date:\s*20\d{2}-\d{2}-\d{2}`     # fecha del ADR (detectar antigüedad)
- *(además: revisión humana — comparar ADR vs estado actual del código)*
**Señal de N/A:** no existen ADRs en el repo (aplicar `DOC-ADR-001` primero).

**Verificar:**
- [ ] Si una decisión cambia, se abre un nuevo ADR que supersede al anterior.
- [ ] No se editan ADRs aceptados (son históricos).
- [ ] Revisión anual de ADRs vs realidad.

---

## B. Diagramas

#### `DOC-DIAG-001` — Diagramas C4 (al menos Context y Container)
**Severidad:** medium · **Aplica a:** documentation

Existen diagramas estilo C4 que muestran el sistema a distintos niveles.

**Dónde buscar:** `docs/**/*.{md,puml,mermaid,d2,dsl}`, `docs/architecture/**`, `docs/diagrams/**`, `**/*.drawio`
**Patrones:**
- `C4Context|C4Container|C4Component|C4Dynamic`     # macros PlantUML C4
- `workspace\s*\{[\s\S]*?model`     # Structurizr DSL
- `\`\`\`mermaid[\s\S]*?(C4Context|flowchart|graph)`     # bloques mermaid
- `Person\s*\(|System\s*\(|Container\s*\(`     # elementos C4
**Señal de N/A:** sistema trivial de un solo componente sin integraciones externas (un único microservicio standalone con BD local).

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

**Dónde buscar:** `docs/**`, `**/*.{png,jpg,jpeg,svg,puml,mermaid,d2,drawio,dsl}`
**Patrones:**
- `\.png\)|\.jpg\)|\.jpeg\)`     # imágenes raster embebidas (sospechoso)
- `\`\`\`(mermaid|plantuml|d2)`     # diagramas como código
- `\.puml$|\.mermaid$|\.d2$|\.dsl$`     # archivos fuente versionables
- `!\[.*?\]\(.*?\.(png|jpg)\)`     # imágenes sin fuente editable acompañante
**Señal de N/A:** no hay diagramas en el repo (aplicar `DOC-DIAG-001` primero).

**Verificar:**
- [ ] Formato text-based versionable.
- [ ] Render automático en la wiki/docs.
- [ ] Fuentes commiteadas junto al código que describen.

---

#### `DOC-DIAG-003` — Diagramas de flujo críticos documentados
**Severidad:** medium · **Aplica a:** documentation

Flujos complejos (onboarding, checkout, ingestión de datos) tienen diagrama
de secuencia o flujo.

**Dónde buscar:** `docs/flows/**`, `docs/sequences/**`, `docs/**/*.{md,puml,mermaid}`
**Patrones:**
- `sequenceDiagram|@startuml[\s\S]*?->`     # diagramas de secuencia
- `flowchart\s+(TD|LR|TB)|graph\s+(TD|LR)`     # mermaid flowcharts
- `participant\s+\w+|actor\s+\w+`     # participantes en sequence
- `^##?\s*(Flujo|Flow|Sequence|Pipeline)`     # secciones de flujo
**Señal de N/A:** app sin flujos multi-componente complejos (CRUD trivial sin async / sin integraciones).

**Verificar:**
- [ ] Diagrama por flujo crítico.
- [ ] Muestra componentes involucrados, datos y puntos de fallo.
- [ ] Actualizado cuando cambia el flujo.

---

## C. Documentación operacional

#### `DOC-OPS-001` — Runbooks por alerta crítica
**Severidad:** medium · **Aplica a:** documentation · observability

(Ver `OBS-RUN-001`.)

**Dónde buscar:** `RUNBOOK*`, `runbooks/**`, `docs/runbooks/**`, `docs/ops/**`
**Patrones:**
- `^#\s*(Runbook|RUNBOOK)`     # archivos runbook
- `^##?\s*(Symptom|Síntoma|Diagnosis|Diagnóstico|Mitigation|Mitigación|Resolution)`     # secciones runbook
- `alert(name|_name):\s*["']?\w+`     # nombres de alerta (cruzar con runbook)
- `runbook_url|runbookUrl`     # link en alerta hacia runbook
**Señal de N/A:** app sin alertas configuradas / sin observabilidad productiva (entorno dev/sandbox sin oncall).

---

#### `DOC-OPS-002` — Playbook de incidentes
**Severidad:** medium · **Aplica a:** process

Procedimiento claro ante incidentes: detección → contención → mitigación →
comunicación → post-mortem.

**Dónde buscar:** `INCIDENT*`, `docs/incidents/**`, `docs/playbook*`, `docs/post-mortem*`
**Patrones:**
- `incident\s*commander|IC\b|war\s*room`     # roles definidos
- `post[-\s]?mortem|postmortem|RCA`     # plantilla / referencia
- `status\s*page|statuspage`     # canal de comunicación
- `game\s*day|chaos|fire\s*drill`     # ensayos
**Señal de N/A:** equipo / proyecto sin operación productiva 24/7 (proyecto interno sin SLA).

**Verificar:**
- [ ] Roles definidos (incident commander, comms, ops).
- [ ] Canales (war room, status page).
- [ ] Plantilla de post-mortem.
- [ ] Se ensaya (game days).

---

#### `DOC-OPS-003` — Procedimientos de soporte
**Severidad:** low · **Aplica a:** process

Para casos comunes del equipo de soporte, hay procedimientos escritos.

**Dónde buscar:** `docs/support/**`, `docs/sop/**`, `docs/procedures/**`
**Patrones:**
- *(sin patrones mecánicos — revisión humana / contenido)*
**Señal de N/A:** producto sin equipo de soporte / sin usuarios externos (lib, CLI dev-only, infra interna).

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

**Dónde buscar:** `docs/glossary*`, `docs/glosario*`, `docs/domain*`, `GLOSSARY*`
**Patrones:**
- `^#\s*(Glossary|Glosario|Domain|Dominio|Ubiquitous Language)`     # archivos glosario
- `^##?\s+\w+\s*$`     # entradas tipo término
- `^\*\*\w+\*\*\s*[:—-]`     # término en negrita seguido de definición
**Señal de N/A:** dominio técnico/genérico sin terminología específica (proxy, CLI utility, biblioteca de algoritmos).

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

**Dónde buscar:** `docs/privacy*`, `docs/legal/**`, `**/privacy-policy*`, `**/*.{tsx,jsx,vue,html}`
**Patrones:**
- `privacy[-_]?policy|política[-_]?de[-_]?privacidad`     # links / archivos
- `<a[^>]*href=["'][^"']*privacy`     # link en frontend
- `gdpr|ccpa|lopd`     # menciones de regulación aplicable
**Señal de N/A:** app sin datos personales (no procesa PII, herramienta interna sin tracking) o B2B-only sin frontend público.

---

#### `DOC-COMP-002` — Documentación de cumplimiento
**Severidad:** medium · **Aplica a:** legal · documentation

Los procedimientos que exige el régimen aplicable (GDPR, SOC2, ISO 27001,
HIPAA) están documentados.

**Dónde buscar:** `docs/compliance/**`, `docs/legal/**`, `docs/security/**`
**Patrones:**
- `gdpr|soc\s*2|iso\s*27001|hipaa|pci[-\s]?dss`     # menciones de framework
- `data[-\s]?processing[-\s]?agreement|DPA\b`     # DPA
- `sub[-\s]?processor`     # sub-procesadores
- `breach\s*notification|notificación\s*de\s*brecha`     # respuesta a brechas
- `record\s*of\s*processing|registro\s*de\s*tratamientos`     # registro GDPR
**Señal de N/A:** ningún régimen de cumplimiento aplica al proyecto (proyecto académico, herramienta interna sin datos regulados, OSS sin operación productiva).

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

**Dónde buscar:** `docs/security/**`, `docs/threat-model*`, `THREAT_MODEL*`, `**/*.md`
**Patrones:**
- `threat\s*model|modelo\s*de\s*amenazas`     # archivo dedicado
- `\bSTRIDE\b|\bLINDDUN\b|\bDREAD\b|\bPASTA\b`     # metodologías
- `attack\s*surface|superficie\s*de\s*ataque`     # análisis de superficie
- `mitigation|mitigación`     # contramedidas listadas
- `(reviewed|revisado)\s*(:|on|el)\s*20\d{2}`     # fecha de revisión
**Señal de N/A:** proyecto sin superficie de ataque significativa (CLI offline, lib pura sin I/O de red).

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

**Dónde buscar:** `docs/data/**`, `docs/schema*`, `docs/dictionary*`, `**/migrations/**`, `**/schema.{sql,prisma}`
**Patrones:**
- `^##?\s*(Tabla|Table|Schema|Data Dictionary)`     # secciones de catálogo
- `COMMENT\s+ON\s+(TABLE|COLUMN)`     # comentarios SQL en schema
- `///\s*@|\/\/\/\s+`     # comentarios doc en Prisma schema
- `description:|comment:`     # campo descripción en YAML/dbt
- `models:\s*$`     # dbt models con docs
**Señal de N/A:** app sin BD propia / sin tablas propias relevantes (lib pura, frontend sin storage, proxy stateless).

**Verificar:**
- [ ] Descripción por tabla y columna importante.
- [ ] Clasificación de sensibilidad (ver `DATA-INV-002`).
- [ ] Relación con otras tablas.
- [ ] Ejemplos / rangos esperados.

---

#### `DOC-DATA-002` — Pipelines y transformaciones documentadas
**Severidad:** medium · **Aplica a:** data

Si hay ETL/ELT, está documentado: fuentes, transformaciones, destinos.

**Dónde buscar:** `docs/pipelines/**`, `docs/data/**`, `**/dags/**`, `**/dbt_project.yml`, `**/airflow/**`
**Patrones:**
- `DAG\(|@dag\b|@task\b`     # Airflow DAGs
- `models:\s*$|sources:\s*$`     # dbt sources/models
- `owner:\s*\w+|owners:\s*$`     # owner declarado
- `schedule(_interval)?:\s*["']?\w+`     # schedule visible
- `sla:\s*|freshness:\s*$`     # SLAs / freshness
**Señal de N/A:** app sin pipelines de datos (no hay ETL/ELT, no hay batch processing, app puramente transaccional).

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
