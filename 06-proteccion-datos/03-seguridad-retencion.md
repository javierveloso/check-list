# 06 · Protección de datos · Seguridad, retención y transferencias

> Medidas de seguridad del tratamiento, retención y borrado programado,
> transferencias internacionales, incidentes.
>
> **Marcos de referencia:** GDPR Arts. 32-34 · Ley 21.719 Chile (Arts. 14, 15, 16, 22) · ISO 27001 · NIST SP 800-53.

---

## A. Medidas técnicas

#### `DATA-SEC-001` — Cifrado en tránsito y en reposo
**Severidad:** critical · **Tags:** `gdpr-art-32` · **Aplica a:** infra · backend

TLS 1.2+ en tránsito, cifrado en reposo para datos personales.

(Ver `SEC-CRYPTO-030`, `SEC-CRYPTO-031` en seguridad para detalle.)

**Verificar:**
- [ ] TLS 1.2+ en toda comunicación externa.
- [ ] Volúmenes/DB con cifrado de disco o tabular.
- [ ] Backups cifrados con claves gestionadas separadamente.
- [ ] Campos muy sensibles cifrados a nivel aplicación con KMS.

---

#### `DATA-SEC-002` — Control de acceso por rol y auditoría
**Severidad:** high · **Tags:** `least-privilege` · **Aplica a:** backend · infra

Solo el personal que lo necesita accede a datos personales, y su acceso queda
registrado.

**Verificar:**
- [ ] Acceso a BD productiva restringido (tiempo limitado, MFA).
- [ ] Sin copias locales de datos productivos en laptops.
- [ ] Accesos loguados (quién, cuándo, qué query).
- [ ] Revisión periódica de accesos (al menos trimestral).

---

#### `DATA-SEC-003` — Datos de producción no se usan en dev/staging
**Severidad:** critical · **Aplica a:** data · infra

Entornos no productivos trabajan con datos sintéticos o anonimizados, no con
copia literal de producción.

**Verificar:**
- [ ] Dev/staging usa datos generados o anonimizados.
- [ ] Si se reusa data de prod, se enmascara antes de copiar.
- [ ] No hay dumps productivos en S3 de dev / slack / laptops.

**Banderas rojas:**
- Restaurar un backup de producción en staging como atajo.

---

#### `DATA-SEC-004` — Registros de acceso a datos sensibles
**Severidad:** high · **Aplica a:** backend

El acceso a registros con datos sensibles (salud, financieros, PII crítica) se
audita.

**Verificar:**
- [ ] Log de quién ve qué registro, cuándo y por qué (si aplica).
- [ ] Alerta en accesos masivos o anómalos.
- [ ] Los logs son inmutables o append-only.

---

## B. Retención y borrado programado

#### `DATA-RET-001` — Políticas de retención definidas por tipo de dato
**Severidad:** high · **Tags:** `gdpr-art-5` · **Aplica a:** data · legal

Cada tipo de dato personal tiene un plazo máximo de retención, alineado con
la finalidad y la ley aplicable.

**Verificar:**
- [ ] Tabla "tipo de dato → retención → justificación".
- [ ] Retenciones documentadas en la política de privacidad.
- [ ] Ejemplos: logs de auditoría (2-7 años según jurisdicción), facturación (5-10 años), datos de usuario inactivo (definir).

---

#### `DATA-RET-002` — Borrado automático al vencer retención
**Severidad:** high · **Aplica a:** backend · data

Existen jobs automáticos que aplican las políticas de retención.

**Verificar:**
- [ ] Job programado que detecta datos vencidos y los borra/anonimiza.
- [ ] Hay período de grace documentado (soft delete + borrado final).
- [ ] El job es idempotente y auditable.
- [ ] Las excepciones (legal hold) se gestionan explícitamente.

---

#### `DATA-RET-003` — Propagación del borrado a todos los sistemas
**Severidad:** high · **Aplica a:** backend · data

Cuando un dato se borra, también se borra en:

- [ ] Réplicas y secondaries.
- [ ] Cachés (Redis, CDN).
- [ ] Motores de búsqueda (Elasticsearch).
- [ ] Data warehouse / analytics.
- [ ] Backups (cuando rotan).
- [ ] Logs (si contenían PII — mejor no loggear PII).

---

#### `DATA-RET-004` — Borrado de cuenta vs. borrado de datos
**Severidad:** medium · **Aplica a:** backend

Se distingue "cerrar cuenta" (el usuario ya no usa el servicio, los datos
pueden conservarse si hay base legal) de "borrar datos" (derecho al olvido).

**Verificar:**
- [ ] UI y comunicación distinguen ambos casos.
- [ ] "Cerrar cuenta" mantiene lo necesario para cumplimiento legal.
- [ ] "Borrar datos" remueve lo que es permisible.

---

## C. Transferencias internacionales

#### `DATA-INTL-001` — Transferencias internacionales mapeadas y legitimadas
**Severidad:** high · **Tags:** `gdpr-ch-v` · **Aplica a:** legal · infra

Cada transferencia de datos fuera del área de residencia legal (ej: EEE para
GDPR) tiene una base jurídica (adecuación, SCC, BCRs, derogaciones).

**Verificar:**
- [ ] Lista de procesadores y países donde se alojan los datos.
- [ ] Para cada uno: base jurídica documentada (ej: SCC firmadas).
- [ ] Evaluación de riesgo de país de destino (TIA post Schrems II si aplica GDPR).
- [ ] Cloud providers con regiones específicas elegidas conscientemente.

---

#### `DATA-INTL-002` — DPA con cada encargado
**Severidad:** critical · **Tags:** `gdpr-art-28` · **Aplica a:** legal

Hay acuerdo de procesamiento de datos (DPA) firmado con todo proveedor que
procese datos personales en nombre de la organización.

**Verificar:**
- [ ] DPA vigente con cada procesador (cloud, LLM provider, email, analytics, etc.).
- [ ] Cláusulas obligatorias: finalidad, duración, naturaleza, obligaciones.
- [ ] Lista de sub-encargados aprobados.
- [ ] Revisión anual.

---

## D. Incidentes y brechas

#### `DATA-INC-001` — Plan de respuesta a incidentes de datos
**Severidad:** critical · **Tags:** `gdpr-art-33`, `gdpr-art-34` · **Aplica a:** legal · infra · backend

Existe plan documentado para detectar, contener, notificar y aprender de
brechas de datos.

**Verificar:**
- [ ] Playbook escrito (quién hace qué en las primeras 24 h).
- [ ] Plazos de notificación a autoridad (72 h en GDPR) incorporados.
- [ ] Criterios para notificar al usuario (alto riesgo).
- [ ] Simulacros periódicos.
- [ ] Contactos de autoridades y asesores legales accesibles.

---

#### `DATA-INC-002` — Registro de brechas incluso sin notificación
**Severidad:** high · **Aplica a:** legal

Toda brecha (aunque no sea notificable) se registra internamente para
aprendizaje y auditoría.

**Verificar:**
- [ ] Registro con fecha, naturaleza, datos afectados, medidas tomadas.
- [ ] Revisado en post-mortems.

---

## E. Evaluación de impacto

#### `DATA-DPIA-001` — DPIA/PIA para tratamientos de alto riesgo
**Severidad:** high · **Tags:** `gdpr-art-35` · **Aplica a:** legal · data

Cuando un tratamiento presenta alto riesgo (ej: profiling a gran escala, datos
sensibles, vigilancia), se hace evaluación de impacto.

**Verificar:**
- [ ] Criterio documentado sobre cuándo se exige DPIA.
- [ ] Plantilla de DPIA usada por los equipos.
- [ ] DPIAs aprobadas por DPO / legal antes del lanzamiento.
- [ ] Re-evaluación cuando cambia el tratamiento.

---

## F. Datos de terceros / procesador

#### `DATA-3P-001` — Datos de terceros mencionados en documentos del usuario
**Severidad:** high · **Aplica a:** backend

Cuando el usuario sube documentos que contienen datos de terceros (contratos,
actas, notas), la organización actúa como encargado y no los trata fuera de
los fines del usuario.

**Verificar:**
- [ ] Los datos no se extraen a BD separadas para otros fines.
- [ ] No se usan para entrenar modelos sin autorización explícita.
- [ ] Se aplican las mismas medidas de seguridad.
- [ ] Política clara con el cliente.

---

#### `DATA-3P-002` — Secreto profesional / privilegios específicos
**Severidad:** critical · **Aplica a:** backend

Si los datos están bajo secreto profesional (abogado-cliente, médico-paciente,
periodístico), hay medidas extra: acceso aun más restringido, cifrado por
tenant/cliente, no extracción ni reprocesamiento.

**Verificar:**
- [ ] Documentación del régimen legal aplicable.
- [ ] Accesos limitados al mínimo operativo.
- [ ] No se procesan con finalidades secundarias.
- [ ] Cifrado a nivel tenant cuando es viable.

---

#### `DATA-3P-003` — API externa como encargado: DPA e integración documentada
**Severidad:** critical · **Tags:** `gdpr-art-28`, `ley-21719-art-16` · **Aplica a:** backend · legal

Cuando la aplicación envía datos personales a una API de tercero (software de RRHH,
nómina, gestión de talento, analítica, etc.) como parte de su proceso principal,
ese proveedor actúa como encargado (processor). Debe existir un DPA vigente y la
integración debe estar documentada en el ROPA.

**Verificar:**
- [ ] Cada integración que transmite PII tiene el proveedor identificado como encargado en el ROPA.
- [ ] Hay DPA (o cláusulas contractuales equivalentes) firmado con cada proveedor externo que recibe PII.
- [ ] La información transmitida se limita al mínimo necesario (minimización): solo los campos requeridos por la funcionalidad.
- [ ] Las credenciales de la API se gestionan como secretos (variables de entorno, Key Vault) y se rotan periódicamente.
- [ ] Si el proveedor está en otro país, la transferencia tiene base jurídica documentada (decisión de adecuación, SCC, etc.).
- [ ] **[Chile — Ley 21.719 Art. 16]** El contrato con el encargado establece explícitamente: instrucciones de tratamiento, confidencialidad, medidas de seguridad y destino de los datos al término del contrato.

**Banderas rojas:**
- Integración con sistema de RRHH/nómina que envía datos de empleados sin DPA documentado.
- Credenciales de API hardcodeadas en el código fuente o en `.env` sin gestión de secretos dedicada.
- Datos de empleados o usuarios enviados a un tercero que no aparece en la política de privacidad ni en el ROPA.
- Payload de sincronización que incluye campos no requeridos por el tercero (email, fecha de nacimiento, domicilio cuando solo se necesita el nombre).

**Referencias:** GDPR Art. 28 · Ley 21.719 Art. 16 (Chile, vigente desde 2024) · LGPD Arts. 37-39 (Brasil).

---

## Checklist resumen

| ID                | Control                                                | Severidad |
| ----------------- | ------------------------------------------------------ | --------- |
| DATA-SEC-001      | Cifrado en tránsito y reposo                           | critical  |
| DATA-SEC-002      | Control de acceso por rol y auditoría                  | high      |
| DATA-SEC-003      | Prod data no en dev/staging                            | critical  |
| DATA-SEC-004      | Registros de acceso a datos sensibles                  | high      |
| DATA-RET-001      | Políticas de retención                                 | high      |
| DATA-RET-002      | Borrado automático                                     | high      |
| DATA-RET-003      | Propagación de borrado                                 | high      |
| DATA-RET-004      | Cierre vs. borrado                                     | medium    |
| DATA-INTL-001     | Transferencias internacionales legitimadas             | high      |
| DATA-INTL-002     | DPA con cada encargado                                 | critical  |
| DATA-INC-001      | Plan de respuesta a brechas                            | critical  |
| DATA-INC-002      | Registro interno de brechas                            | high      |
| DATA-DPIA-001     | DPIA para alto riesgo                                  | high      |
| DATA-3P-001       | Datos de terceros en documentos                        | high      |
| DATA-3P-002       | Secreto profesional protegido                          | critical  |
| DATA-3P-003       | API externa como encargado: DPA documentado            | critical  |
