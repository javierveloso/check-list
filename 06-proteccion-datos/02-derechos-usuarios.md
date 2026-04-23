# 06 · Protección de datos · Derechos de los titulares

> Acceso, rectificación, cancelación, oposición, portabilidad, y decisiones
> automatizadas.
>
> **Marcos de referencia:** GDPR Arts. 15-22 · CCPA §1798.100-130 · LGPD Art. 18 · Ley 21.719.

---

## A. Derecho de acceso

#### `DATA-RIGHTS-001` — Acceso a los datos propios
**Severidad:** high · **Tags:** `gdpr-art-15` · **Aplica a:** backend · frontend

El usuario puede solicitar copia de los datos que se tienen sobre él. El
servicio responde en el plazo legal (1 mes en GDPR, típicamente).

**Verificar:**
- [ ] Endpoint / flujo de "descargar mis datos" disponible.
- [ ] La copia incluye datos de todas las áreas (perfil, actividad, preferencias, contenidos).
- [ ] La identidad del solicitante se verifica (no con PII solamente).
- [ ] Se cumple el SLA legal.

---

#### `DATA-RIGHTS-002` — Formato legible y portable
**Severidad:** medium · **Tags:** `gdpr-art-20` · **Aplica a:** backend

Los datos se entregan en formato estructurado y legible (JSON, CSV) que
permita portabilidad a otro servicio.

**Verificar:**
- [ ] Formato estándar (JSON, CSV con headers).
- [ ] Archivos con encoding claro (UTF-8).
- [ ] Metadata descriptiva de los campos.

---

## B. Rectificación

#### `DATA-RIGHTS-010` — Usuario puede corregir sus datos
**Severidad:** high · **Tags:** `gdpr-art-16` · **Aplica a:** backend · frontend

Hay UI/endpoint para que el usuario actualice los campos de su perfil.

**Verificar:**
- [ ] Campos modificables accesibles desde la UI.
- [ ] Si algún campo no es modificable, hay un mecanismo para solicitar corrección.
- [ ] Las correcciones se propagan a cachés, índices y downstream systems.
- [ ] Histórico de cambios si se requiere por auditoría, con acceso restringido.

---

## C. Cancelación / borrado

#### `DATA-RIGHTS-020` — Derecho al borrado implementable
**Severidad:** critical · **Tags:** `gdpr-art-17`, `right-to-be-forgotten` · **Aplica a:** backend · data

El usuario puede solicitar el borrado de sus datos, salvo cuando una base legal
obliga conservar (contabilidad, prevención de fraude, etc.).

**Verificar:**
- [ ] Endpoint/flujo para solicitar borrado.
- [ ] El borrado elimina datos en BD principal, réplicas, caches, índices de búsqueda, sistemas analíticos.
- [ ] Los datos no estrictamente necesarios se borran; los retenidos por obligación legal se documentan y justifican.
- [ ] Si hay retención mínima, se anonimiza o se restringe acceso.
- [ ] El backup que contenga los datos borrados se reemplaza cuando caduque o se re-procesa.

**Banderas rojas:**
- "Soft delete" sin plan de borrado duro definitivo.
- Datos que persisten en S3, search index o data warehouse tras borrado.

---

#### `DATA-RIGHTS-021` — Cascada de borrado documentada
**Severidad:** high · **Aplica a:** backend · data

Hay claridad sobre qué se borra y qué no cuando el usuario solicita borrado.

**Verificar:**
- [ ] Mapa de "qué tablas/sistemas se tocan al borrar".
- [ ] Datos compartidos (ej: contenido público que el usuario creó) tratados según la política (anonimizar vs borrar).
- [ ] Datos de terceros mencionados (ej: en comentarios) no se borran por el borrado de un usuario.

---

#### `DATA-RIGHTS-022` — Anonimización como alternativa cuando aplica
**Severidad:** medium · **Aplica a:** backend · data

Cuando hay razón legítima para conservar (estadísticas, fraude), se anonimiza
(no solo pseudonimiza) cuando sea posible.

**Verificar:**
- [ ] Técnicas: agregación, k-anonymity, differential privacy, hashing con salt global irreversible.
- [ ] Se valida que la anonimización sea efectiva (no re-identificable).
- [ ] Pseudonimización cuando la anonimización total no es posible, con controles extras.

---

## D. Oposición y limitación

#### `DATA-RIGHTS-030` — Oposición a tratamientos opcionales
**Severidad:** high · **Tags:** `gdpr-art-21` · **Aplica a:** frontend · backend

El usuario puede oponerse a tratamientos basados en interés legítimo o para
marketing directo.

**Verificar:**
- [ ] Opt-out claro para marketing/comunicaciones promocionales.
- [ ] Unsubscribe link en cada email promocional, que funcione en un clic.
- [ ] Preferencias granulares si aplica (emails semanales vs producto nuevo).
- [ ] La oposición se refleja en los sistemas (cola de envío, CRM).

---

#### `DATA-RIGHTS-031` — Limitación al tratamiento
**Severidad:** medium · **Tags:** `gdpr-art-18` · **Aplica a:** backend

El usuario puede pedir que sus datos se "pausen" mientras se resuelve una
disputa (se conservan pero no se procesan activamente).

**Verificar:**
- [ ] Mecanismo para flagear cuentas como "en limitación".
- [ ] El procesamiento en esas cuentas se detiene (ej: exclusión de analytics, envíos).

---

## E. Portabilidad

#### `DATA-RIGHTS-040` — Exportación en formato estándar
**Severidad:** medium · **Tags:** `gdpr-art-20` · **Aplica a:** backend

El usuario puede exportar sus datos para llevarlos a otro proveedor.

**Verificar:**
- [ ] Formato estructurado, legible por máquina (JSON, CSV, formato del dominio si hay estándar).
- [ ] Se exporta lo que el usuario proporcionó o generó (no datos derivados internos sin justificación).

---

## F. Decisiones automatizadas

#### `DATA-RIGHTS-050` — Derecho a no ser objeto de decisiones automatizadas significativas
**Severidad:** high · **Tags:** `gdpr-art-22` · **Aplica a:** backend · ai · frontend

Cuando una decisión automatizada (scoring, aprobación crediticia,
rechazo automático, decisión de IA) tiene efecto legal o significativo, el
usuario debe poder:

- Ser informado de que ocurre y la lógica general.
- Expresar su punto de vista.
- Solicitar intervención humana.
- Impugnar la decisión.

**Verificar:**
- [ ] Se identifican todas las decisiones automatizadas significativas.
- [ ] La política de privacidad las menciona.
- [ ] Existe flujo para apelar / pedir revisión humana.
- [ ] Para IA: se documenta la lógica básica (no el modelo entero, pero sí los factores principales).

---

#### `DATA-RIGHTS-051` — Transparencia en uso de IA
**Severidad:** medium · **Aplica a:** frontend

Cuando un output es generado por IA, se informa al usuario (etiqueta, disclaimer).

(Ver también `07-ia-llm/04-confiabilidad-costos.md`.)

---

## G. Notificaciones y gestión

#### `DATA-RIGHTS-060` — Canal claro para ejercer derechos
**Severidad:** high · **Aplica a:** frontend · backend

Hay un canal oficial (email, formulario, settings) donde el usuario ejerce sus
derechos. Se responde en el plazo legal.

**Verificar:**
- [ ] Canal documentado y visible en la política de privacidad.
- [ ] SLA interno para responder (dentro del plazo legal, con margen).
- [ ] Log de solicitudes y tiempos de respuesta para auditoría.

---

#### `DATA-RIGHTS-061` — Verificación de identidad sin fricción excesiva
**Severidad:** medium · **Aplica a:** backend

Verificar la identidad del solicitante es necesario, pero no debe exigir PII
adicional desproporcionada.

**Verificar:**
- [ ] Se usa la autenticación existente cuando el usuario tiene cuenta.
- [ ] Solo se pide PII adicional cuando es imprescindible y proporcional.
- [ ] No se pide una copia de documento de identidad si la verificación puede hacerse de otra forma.

---

## Checklist resumen

| ID                   | Control                                             | Severidad |
| -------------------- | --------------------------------------------------- | --------- |
| DATA-RIGHTS-001      | Acceso a datos propios                              | high      |
| DATA-RIGHTS-002      | Formato portable                                    | medium    |
| DATA-RIGHTS-010      | Rectificación                                       | high      |
| DATA-RIGHTS-020      | Derecho al borrado                                  | critical  |
| DATA-RIGHTS-021      | Cascada de borrado documentada                      | high      |
| DATA-RIGHTS-022      | Anonimización cuando aplica                         | medium    |
| DATA-RIGHTS-030      | Oposición a marketing                               | high      |
| DATA-RIGHTS-031      | Limitación al tratamiento                           | medium    |
| DATA-RIGHTS-040      | Exportación estándar                                | medium    |
| DATA-RIGHTS-050      | Decisiones automatizadas: revisión humana           | high      |
| DATA-RIGHTS-051      | Transparencia en uso de IA                          | medium    |
| DATA-RIGHTS-060      | Canal claro para ejercer derechos                   | high      |
| DATA-RIGHTS-061      | Verificación proporcional                           | medium    |
