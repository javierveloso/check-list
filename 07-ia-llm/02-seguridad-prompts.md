# 07 · IA / LLM · Seguridad: injection, fuga de datos y abuso

> Prompt injection, data leakage, PII en prompts, safety guards, y contenido
> peligroso.
>
> **Marcos de referencia:** OWASP Top 10 for LLM Applications · NIST AI RMF.

---

## A. Prompt injection

#### `LLM-SEC-001` — Input del usuario tratado como dato, no como instrucción
**Severidad:** critical · **Tags:** `owasp-llm01`, `prompt-injection` · **Aplica a:** ai · backend

La arquitectura del prompt distingue explícitamente entre instrucciones del
sistema y datos del usuario, para que inyecciones dentro del user input no
sobrescriban el comportamiento.

**Verificar:**
- [ ] User input dentro de etiquetas/delimitadores claros: `<user_input>...</user_input>`.
- [ ] System prompt instruye al modelo a ignorar instrucciones embebidas en datos.
- [ ] No se concatenan instrucciones del sistema después del input del usuario.
- [ ] Para tareas críticas, hay capa de validación posterior.

**Banderas rojas:**
- `"Ignore previous instructions"` no detectado.
- Documentos que "engañan" al modelo sin que el flujo tenga defensa.

---

#### `LLM-SEC-002` — Validación de output de IA antes de actuar
**Severidad:** critical · **Tags:** `owasp-llm02` · **Aplica a:** ai · backend

El output del modelo nunca se usa directamente para ejecutar código, hacer
llamadas privilegiadas, o mostrar HTML crudo sin sanitización.

**Verificar:**
- [ ] El output se valida contra schema/tipo esperado.
- [ ] Si el output puede contener HTML, se sanitiza (DOMPurify, bleach).
- [ ] Si el output contiene URLs, se validan antes de mostrarse como links.
- [ ] No se pasa el output directo a `eval`, `exec`, shell, o ejecutores de SQL.

**Banderas rojas:**
- Mostrar respuesta del modelo con `dangerouslySetInnerHTML` sin sanitización.
- Ejecutar como SQL/código lo que el modelo "pidió".

---

#### `LLM-SEC-003` — Tool / function calling con autorización por llamada
**Severidad:** critical · **Tags:** `owasp-llm07`, `agent-security` · **Aplica a:** ai · backend

Cuando el modelo puede invocar tools (function calls, agents), cada llamada
pasa por autorización, no se confía en que el modelo respete límites por sí
mismo.

**Verificar:**
- [ ] Cada tool tiene ACL que el servidor aplica antes de ejecutar.
- [ ] Tools peligrosas (delete, transfer, send email masivo) requieren confirmación humana.
- [ ] Tools que escriben datos tienen audit log.
- [ ] El modelo recibe solo las tools que el usuario actual puede invocar.

**Banderas rojas:**
- "El modelo no debería llamar a delete_all_users" como única defensa.
- Tool que ejecuta código arbitrario del usuario.

---

## B. Protección de datos en prompts

#### `LLM-SEC-010` — PII minimizada en el prompt
**Severidad:** high · **Tags:** `data-minimization` · **Aplica a:** ai · data

Solo los datos estrictamente necesarios para la tarea se incluyen en el prompt.
PII innecesaria se remueve o anonimiza antes.

**Verificar:**
- [ ] Se sanean logs y prompts para no pasar PII no necesaria.
- [ ] Para tareas de análisis, se puede considerar anonimizar antes y re-identificar después.
- [ ] No se envían claves, secretos, tokens, paths internos al proveedor.

---

#### `LLM-SEC-011` — Política clara con el proveedor sobre uso de datos
**Severidad:** high · **Tags:** `gdpr`, `vendor-dpa` · **Aplica a:** legal · ai

El contrato con el proveedor (OpenAI, Anthropic, Google, etc.) define qué hace
con los datos: no entrenamiento, retención, logging, ubicación.

**Verificar:**
- [ ] DPA firmado con el proveedor.
- [ ] Opt-out de entrenamiento si aplica (Enterprise / API con retention 0 / zero data retention).
- [ ] Política clara sobre retención en la plataforma del proveedor.
- [ ] La política de privacidad al usuario menciona el proveedor.

---

#### `LLM-SEC-012` — No enviar datos sensibles a modelos públicos sin autorización
**Severidad:** critical · **Tags:** `data-leakage` · **Aplica a:** backend · legal

Datos con secreto profesional, datos médicos, financieros críticos: no se
envían a modelos consumidores (ChatGPT free) sino a tenants empresariales
con controles.

**Verificar:**
- [ ] Endpoints internos no llaman a APIs públicas con datos sensibles sin autorización.
- [ ] Uso de modelos on-prem / bring-your-own-key / Azure OpenAI / Bedrock cuando es exigido.
- [ ] Empleados no usan ChatGPT personal con data del trabajo (política).

---

#### `LLM-SEC-013` — Inspección antes de loggear prompts
**Severidad:** high · **Tags:** `cwe-532` · **Aplica a:** backend

Los logs que capturan prompts/respuestas pasan por una capa de redacción.

**Verificar:**
- [ ] PII redactada antes de loggear (emails, teléfonos, nombres sensibles, IDs).
- [ ] Longitud de payload loggeado acotada.
- [ ] Retención de logs compatible con política de retención de datos.

---

## C. Contenido peligroso y abuse

#### `LLM-SEC-020` — Filtros de contenido en entrada y salida
**Severidad:** high · **Tags:** `safety`, `owasp-llm09` · **Aplica a:** ai

Se aplican clasificadores / moderation APIs para detectar contenido
inapropiado (ilegal, autolesiones, explícito) en entrada y salida cuando el
riesgo lo justifica.

**Verificar:**
- [ ] API de moderación (Anthropic, OpenAI Moderation, etc.) integrada en caminos de riesgo.
- [ ] Umbrales y acciones definidas (bloquear, advertir, notificar).
- [ ] Logs de eventos de moderación (sin guardar contenido completo si es sensible).

---

#### `LLM-SEC-021` — Protección anti-abuse (DoS, costos)
**Severidad:** high · **Tags:** `cost`, `dos` · **Aplica a:** backend · ai

Rate limiting específico a endpoints que invocan LLM; límites de tokens por
usuario por periodo; watchdog de gastos.

**Verificar:**
- [ ] Rate limit más estricto en rutas con LLM (no heredar el general).
- [ ] Límites diarios/mensuales de tokens por usuario/org.
- [ ] Alerta cuando un usuario o endpoint explota el budget.
- [ ] Capability flags permiten desactivar features de IA ante incidente.

**Banderas rojas:**
- Usuario sin cuotas consumiendo millones de tokens sin freno.

---

#### `LLM-SEC-022` — Detección de prompt injection activa
**Severidad:** medium · **Tags:** `defense-in-depth` · **Aplica a:** ai · backend

Hay heurísticas o clasificadores que detectan intentos de prompt injection
(aún imperfectos) y registran para análisis.

**Verificar:**
- [ ] Lista de patrones conocidos ("ignore previous", "disregard", etc.) como señal.
- [ ] Logging de intentos sospechosos para análisis y mejora.
- [ ] Revisión periódica de intentos para ajustar el sistema.

---

## D. Autenticidad y control

#### `LLM-SEC-030` — Identificación de contenido generado por IA
**Severidad:** medium · **Tags:** `transparency` · **Aplica a:** frontend

Cuando un output es generado por IA, se identifica claramente al usuario.

**Verificar:**
- [ ] Etiqueta visible cerca del contenido generado.
- [ ] Disclaimer en el producto sobre limitaciones.
- [ ] Si hay citas, se pueden verificar.

---

#### `LLM-SEC-031` — Human in the loop en decisiones sensibles
**Severidad:** high · **Aplica a:** backend · frontend

Las decisiones automatizadas con impacto legal, financiero o de seguridad
requieren confirmación/revisión humana.

(Ver `DATA-RIGHTS-050`.)

**Verificar:**
- [ ] Las decisiones críticas no se ejecutan solo con output del modelo.
- [ ] Hay UI para revisar/aprobar.
- [ ] Audit log de quién aprobó.

---

#### `LLM-SEC-032` — Protección contra leakage de system prompt
**Severidad:** medium · **Aplica a:** ai

Asumir que el system prompt **se filtrará**. No poner secretos, datos sensibles
ni lógica de seguridad que el usuario no pueda ver.

**Verificar:**
- [ ] No hay API keys, secretos, URLs internas en el system prompt.
- [ ] La lógica de control de acceso no depende del contenido del prompt.
- [ ] Si filtrar el prompt sería embarazoso, el prompt debe reescribirse.

---

## Checklist resumen

| ID               | Control                                            | Severidad |
| ---------------- | -------------------------------------------------- | --------- |
| LLM-SEC-001      | User input como dato, no instrucción               | critical  |
| LLM-SEC-002      | Validación de output antes de actuar               | critical  |
| LLM-SEC-003      | Tool calling con autorización                      | critical  |
| LLM-SEC-010      | PII minimizada en prompts                          | high      |
| LLM-SEC-011      | DPA con el proveedor                               | high      |
| LLM-SEC-012      | No enviar sensibles a modelos públicos             | critical  |
| LLM-SEC-013      | Redacción antes de loggear                         | high      |
| LLM-SEC-020      | Filtros de contenido                               | high      |
| LLM-SEC-021      | Anti-abuse / budgets                               | high      |
| LLM-SEC-022      | Detección de injection activa                      | medium    |
| LLM-SEC-030      | Contenido generado identificado                    | medium    |
| LLM-SEC-031      | Human in the loop                                  | high      |
| LLM-SEC-032      | System prompt asumido público                      | medium    |
