# 06 · Protección de datos · Inventario, clasificación y base legal

> Inventario de datos personales, clasificación por sensibilidad, base legal
> del tratamiento y consentimiento.
>
> **Marcos de referencia:** GDPR (UE) · CCPA/CPRA (California) · LGPD (Brasil) · Ley 21.719 (Chile) · PIPEDA (Canadá). Los controles son agnósticos del marco legal específico; adaptar al aplicable.

---

## A. Inventario y clasificación

#### `DATA-INV-001` — Inventario de datos personales documentado
**Severidad:** high · **Tags:** `gdpr-art-30` · **Aplica a:** data · backend

Existe un documento (registro de actividades de tratamiento) que enumera qué
datos personales se recogen, con qué finalidad, dónde se almacenan y por
cuánto tiempo.

**Verificar:**
- [ ] Inventario vivo (versionado) con todos los datos personales procesados.
- [ ] Por cada dato: propósito, base legal, retención, destinatarios, transferencias.
- [ ] El inventario se revisa al menos anualmente.
- [ ] Cada nuevo campo o tabla con PII dispara una actualización.

**Banderas rojas:**
- Tablas nuevas con PII creadas sin actualizar el inventario.
- "Nadie sabe qué guardamos exactamente" en entrevistas.

---

#### `DATA-INV-002` — Clasificación por sensibilidad
**Severidad:** high · **Aplica a:** data

Los datos personales se clasifican en niveles (p. ej.: pública, interna,
confidencial, sensible) con reglas operacionales por nivel.

**Verificar:**
- [ ] Niveles definidos y documentados.
- [ ] Cada campo/tabla está etiquetado en el inventario.
- [ ] Las reglas de acceso, cifrado y retención se aplican según el nivel.
- [ ] Datos sensibles (salud, religión, sexualidad, biometría, ideología) se tratan aparte y con más restricciones.

---

#### `DATA-INV-003` — Flujos de datos mapeados
**Severidad:** medium · **Aplica a:** data

Existe un diagrama/documento que muestra por dónde pasan los datos personales:
entrada, almacenamiento, procesamiento, exportación.

**Verificar:**
- [ ] Diagramas actualizados por flujo crítico (ej: signup, checkout, análisis).
- [ ] Cada "salida a tercero" (analytics, LLM, payment processor) está registrada.
- [ ] Los flujos internacionales se identifican explícitamente.

---

#### `DATA-INV-004` — Minimización en recolección
**Severidad:** high · **Tags:** `gdpr-art-5` · **Aplica a:** backend · frontend

Solo se recoge el dato necesario para la finalidad declarada. No se recolecta
"por si acaso".

**Verificar:**
- [ ] Cada campo en formularios tiene justificación documentada.
- [ ] Datos innecesarios no se almacenan (filtrado en el servidor, no solo en la UI).
- [ ] Revisión periódica de campos obsoletos.

**Banderas rojas:**
- Formulario de registro pide fecha de nacimiento sin usarla.
- Logs que capturan body completo "por si acaso".

---

## B. Base legal del tratamiento

#### `DATA-LEGAL-001` — Base legal documentada por cada tratamiento
**Severidad:** critical · **Tags:** `gdpr-art-6`, `ley-21719-art-13` · **Aplica a:** legal · data

Cada uso de datos personales tiene una base legal explícita (consentimiento,
contrato, obligación legal, interés vital, interés público, interés legítimo).

**Verificar:**
- [ ] El inventario indica la base legal por tratamiento.
- [ ] La base no se cambia sin re-evaluar ni notificar.
- [ ] Si es "interés legítimo", hay balancing test documentado.
- [ ] Tratamientos con datos sensibles tienen base reforzada (consentimiento explícito en la mayoría de regímenes).
- [ ] **[Chile — Ley 21.719]** Para datos de empleados, la base legal está documentada (típicamente Art. 13 letra b: "ejecución de un contrato del que el titular es parte"). Los tratamientos que van más allá del contrato laboral requieren base adicional.

**Banderas rojas:**
- Tablas nuevas con PII en el ORM sin actualización del inventario de tratamientos.
- Tratamiento de datos de salud, biometría o ideología sin consentimiento explícito documentado.
- Sistema que procesa datos de empleados chilenos sin referencia al Art. 13 Ley 21.719 en el ROPA.

**Referencias:** GDPR Art. 6 · Ley 21.719 Art. 13 (Chile, vigente desde 2024) · LGPD Art. 7 (Brasil).

---

#### `DATA-LEGAL-002` — Consentimiento granular, informado y revocable
**Severidad:** critical · **Tags:** `gdpr-art-7` · **Aplica a:** frontend · backend

Cuando la base es consentimiento, es:

- **Específico**: separado por propósito.
- **Informado**: el usuario sabe qué acepta.
- **Libre**: sin coerción (no condicionar el servicio a consentimientos no esenciales).
- **Inequívoco**: acción afirmativa clara.
- **Revocable**: tan fácil de revocar como de dar.

**Verificar:**
- [ ] Consentimientos separados por propósito (ej: comunicaciones promocionales vs operativas).
- [ ] Texto claro, sin oscuridad legalesa.
- [ ] Checkboxes no pre-marcados.
- [ ] Revocación disponible en la UI (no "mándanos un email").
- [ ] Se almacena timestamp + versión del texto consentido + IP/device.

**Banderas rojas:**
- "Al usar el sitio, aceptas todo".
- Checkbox pre-marcado.
- Consentimiento único "para todo" incluyendo marketing.

---

#### `DATA-LEGAL-003` — Consentimiento específico para tratamientos con IA/LLM
**Severidad:** high · **Aplica a:** backend · frontend

Si los datos del usuario se procesan con modelos de IA (posiblemente con
proveedores externos), se explica y se recoge consentimiento cuando la base
legal lo exige.

**Verificar:**
- [ ] Política de privacidad menciona los procesadores de IA utilizados.
- [ ] Si los datos cruzan fronteras vía IA, se documenta.
- [ ] El usuario sabe si sus datos se usan para entrenar modelos (y puede oponerse cuando aplica).

(Ver también `07-ia-llm/02-seguridad-prompts.md`.)

---

#### `DATA-LEGAL-004` — Menores: consentimiento parental cuando aplique
**Severidad:** critical · **Tags:** `coppa`, `gdpr-art-8` · **Aplica a:** backend · frontend

Si el servicio está disponible a menores, se cumple la ley aplicable (13-16
años varía por jurisdicción) y se requiere consentimiento parental.

**Verificar:**
- [ ] Mecanismo para identificar menores.
- [ ] Consentimiento parental verificable cuando se recolectan datos de menores.
- [ ] Datos de menores se tratan con cuidado especial.

---

## C. Transparencia e información

#### `DATA-TRANS-001` — Política de privacidad completa y accesible
**Severidad:** high · **Tags:** `gdpr-art-13`, `gdpr-art-14` · **Aplica a:** frontend · legal

Existe política de privacidad con toda la información requerida, en lenguaje
comprensible y en el idioma del usuario.

**Verificar:**
- [ ] Identidad del responsable y forma de contacto (DPO si aplica).
- [ ] Datos tratados, finalidades, base legal.
- [ ] Destinatarios y transferencias internacionales.
- [ ] Plazos de retención.
- [ ] Derechos del titular y cómo ejercerlos.
- [ ] Existe fecha de última actualización.
- [ ] Cambios materiales se notifican activamente.

---

#### `DATA-TRANS-002` — Aviso en el momento de la recolección
**Severidad:** medium · **Aplica a:** frontend

Al recolectar datos, el usuario ve un aviso just-in-time con resumen y link a
la política.

**Verificar:**
- [ ] Formularios con aviso corto + link a política.
- [ ] Tooltips explican por qué se pide un dato sensible.
- [ ] Banners de cookies cumplen con la regulación local (consent/reject igual de fácil).

---

## D. Responsable y encargado

#### `DATA-ROLE-001` — Roles identificados: controller vs processor
**Severidad:** high · **Aplica a:** legal · infra

La organización tiene claro qué datos procesa como responsable (controller)
y qué como encargado (processor) de otro.

**Verificar:**
- [ ] Roles documentados por flujo de datos.
- [ ] Contratos (DPA) firmados con todos los encargados.
- [ ] Sub-encargados autorizados listados y notificados a los clientes.

---

## Checklist resumen

| ID                | Control                                              | Severidad |
| ----------------- | ---------------------------------------------------- | --------- |
| DATA-INV-001      | Inventario de datos personales                       | high      |
| DATA-INV-002      | Clasificación por sensibilidad                       | high      |
| DATA-INV-003      | Flujos de datos mapeados                             | medium    |
| DATA-INV-004      | Minimización en recolección                          | high      |
| DATA-LEGAL-001    | Base legal documentada                               | critical  |
| DATA-LEGAL-002    | Consentimiento granular                              | critical  |
| DATA-LEGAL-003    | Consentimiento específico para IA                    | high      |
| DATA-LEGAL-004    | Consentimiento parental (menores)                    | critical  |
| DATA-TRANS-001    | Política de privacidad completa                      | high      |
| DATA-TRANS-002    | Aviso just-in-time                                   | medium    |
| DATA-ROLE-001     | Roles controller/processor identificados             | high      |
