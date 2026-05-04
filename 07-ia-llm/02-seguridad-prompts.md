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

**Dónde buscar:** `**/prompts/**`, `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `f["']You are an assistant\..*\{user_input\}|system\s*=\s*f["'][^"']*\{`     # input usuario en system prompt
- `<user_input>[\s\S]*</user_input>|<data>[\s\S]*</data>`     # delimitadores defensivos
- `ignore.*previous.*instructions|disregard.*above`     # frases típicas de injection (filtros)
- `role:\s*["']user["']`     # uso del rol user (correcto)
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

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

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py,jsx,tsx}`
**Patrones:**
- `\beval\(.*response|exec\(.*response|new\s+Function\(.*completion`     # ejecución del output (peligroso)
- `dangerouslySetInnerHTML.*\{.*(response|completion|message)`     # HTML crudo del LLM
- `DOMPurify|bleach\.clean|sanitize-html`     # sanitización aplicada
- `zod|pydantic|jsonschema.*validate.*response`     # validación de schema
- `os\.system\(.*response|subprocess.*\(.*completion`     # shell con output del modelo
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

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

**Dónde buscar:** `**/agents/**`, `**/tools/**`, `**/llm/**`, `**/*.{ts,js,py}`
**Patrones:**
- `tools\s*=\s*\[|tool_choice|function_call|@tool|defineTool`     # registro de tools
- `tool.*allow.?list|tool.*allowed.*for.*user|authorize.*before.*tool`     # allowlist por usuario
- `human.?in.?the.?loop|require.*confirmation.*tool`     # confirmación humana
- `await.*executeTool|run_tool\(.*\)`     # ejecución a verificar
- `audit.*tool.*call|log.*tool.*invocation`     # audit log de tools
**Señal de N/A:** el LLM no usa tool/function calling (solo respuestas de texto).

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

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `prompt.*\$?\{user\}|prompt.*user\.email|prompt.*user\.address`     # PII directo en prompt
- `redact|scrub|mask.*pii|remove.*pii`     # sanitización pre-prompt
- `process\.env\..*KEY.*prompt|secret.*prompt`     # secretos en prompt (mal)
- `JSON\.stringify\(user\)|json\.dumps\(.*user`     # serialización completa de user
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Se sanean logs y prompts para no pasar PII no necesaria.
- [ ] Para tareas de análisis, se puede considerar anonimizar antes y re-identificar después.
- [ ] No se envían claves, secretos, tokens, paths internos al proveedor.

---

#### `LLM-SEC-011` — Política clara con el proveedor sobre uso de datos
**Severidad:** high · **Tags:** `gdpr`, `vendor-dpa` · **Aplica a:** legal · ai

El contrato con el proveedor (OpenAI, Anthropic, Google, etc.) define qué hace
con los datos: no entrenamiento, retención, logging, ubicación.

**Dónde buscar:** `DPA*`, `privacy.md`, `**/legal/**`, `package.json`, `requirements.txt`
**Patrones:**
- *(sin patrones mecánicos — revisión humana / legal)*
- `import.*(openai|anthropic|@google/generative-ai|cohere|mistral)`     # proveedores a contrastar con DPAs
- `zero.?retention|opt.?out.*training|data.*retention.*0`     # opt-out documentado
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

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

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`, `.env*`
**Patrones:**
- `api\.openai\.com|api\.anthropic\.com`     # endpoint público (revisar si manejan datos sensibles)
- `azure.*openai|bedrock|vertex.?ai|on.?prem`     # tenants empresariales/controlados
- `\b(health|medical|patient|attorney|privileged|tax|nomina)\b.*prompt`     # datos sensibles cerca de LLM
**Señal de N/A:** el repo no procesa datos sensibles (sin salud, sin financieros críticos, sin secreto profesional).

**Verificar:**
- [ ] Endpoints internos no llaman a APIs públicas con datos sensibles sin autorización.
- [ ] Uso de modelos on-prem / bring-your-own-key / Azure OpenAI / Bedrock cuando es exigido.
- [ ] Empleados no usan ChatGPT personal con data del trabajo (política).

---

#### `LLM-SEC-013` — Inspección antes de loggear prompts
**Severidad:** high · **Tags:** `cwe-532` · **Aplica a:** backend

Los logs que capturan prompts/respuestas pasan por una capa de redacción.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/logger*`, `**/middleware/**`, `**/*.{ts,js,py}`
**Patrones:**
- `console\.log\(.*prompt|logger\.(info|debug)\(.*prompt`     # logueo crudo de prompts
- `redact|sanitize|scrub.*before.*log|mask.*pii`     # capa de redacción
- `log.*\.email|log.*\.rut|log.*\.phone`     # PII en logs
- `truncate.*log|max.*log.*length`     # acotar payload
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

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

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/moderation/**`, `**/*.{ts,js,py}`
**Patrones:**
- `moderation|moderations\.create|safety.*classifier|perspective.*api`     # APIs de moderación
- `categories\s*:\s*\{|flagged|unsafe.*content`     # estructura de respuesta de moderación
- `block.*content|reject.*input|warn.*user`     # acciones definidas
**Señal de N/A:** el dominio del LLM es cerrado y no acepta input libre del usuario (no hay riesgo razonable de contenido inapropiado).

**Verificar:**
- [ ] API de moderación (Anthropic, OpenAI Moderation, etc.) integrada en caminos de riesgo.
- [ ] Umbrales y acciones definidas (bloquear, advertir, notificar).
- [ ] Logs de eventos de moderación (sin guardar contenido completo si es sensible).

---

#### `LLM-SEC-021` — Protección anti-abuse (DoS, costos)
**Severidad:** high · **Tags:** `cost`, `dos` · **Aplica a:** backend · ai

Rate limiting específico a endpoints que invocan LLM; límites de tokens por
usuario por periodo; watchdog de gastos.

**Dónde buscar:** `**/llm/**`, `**/middleware/**`, `**/rate*`, `**/*.{ts,js,py}`
**Patrones:**
- `rate.?limit|throttle|@Throttle|express-rate-limit|slowapi`     # rate limit
- `quota|budget|max_tokens_per_(day|month|user)`     # cuotas
- `usage\.total_tokens|track.*tokens.*per.*user`     # tracking por usuario
- `feature.?flag|kill.?switch.*ai`     # capability flag
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

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

**Dónde buscar:** `**/llm/**`, `**/security/**`, `**/middleware/**`, `**/*.{ts,js,py}`
**Patrones:**
- `ignore.*previous|disregard.*instructions|jailbreak.*pattern`     # patrones conocidos
- `prompt.?injection.*detect|injection.*classifier|guardrails`     # clasificador
- `lakera|rebuff|nvidia.*nemo.*guardrails`     # libs especializadas
- `log.*suspicious.*prompt`     # logging de intentos
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Lista de patrones conocidos ("ignore previous", "disregard", etc.) como señal.
- [ ] Logging de intentos sospechosos para análisis y mejora.
- [ ] Revisión periódica de intentos para ajustar el sistema.

---

## D. Autenticidad y control

#### `LLM-SEC-030` — Identificación de contenido generado por IA
**Severidad:** medium · **Tags:** `transparency` · **Aplica a:** frontend

Cuando un output es generado por IA, se identifica claramente al usuario.

**Dónde buscar:** `**/components/**`, `**/*.{tsx,jsx,vue,svelte}`, `**/llm/**`
**Patrones:**
- `generated.?by.?ai|ai.?generated|powered.?by.?(gpt|claude|llm)`     # disclaimer
- `<Badge.*ai|<Tag.*ai|aria-label.*ai.*generated`     # etiqueta visible
- `disclaimer|caveat|verify.*output`     # texto de limitaciones
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

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

**Dónde buscar:** `**/llm/**`, `**/agents/**`, `**/workflow/**`, `**/*.{ts,js,py,jsx,tsx}`
**Patrones:**
- `human.?in.?the.?loop|require.*review|pending.*approval`     # HITL
- `auto.*approve|auto.*execute|auto.*decision`     # decisiones sin revisión (revisar)
- `approve|reject|reviewer.*id`     # flujo de aprobación
- `audit.*log.*approval|signed.*by.*reviewer`     # audit log
**Señal de N/A:** el LLM solo produce contenido informativo (sin decisiones con efecto legal/financiero).

**Verificar:**
- [ ] Las decisiones críticas no se ejecutan solo con output del modelo.
- [ ] Hay UI para revisar/aprobar.
- [ ] Audit log de quién aprobó.

---

#### `LLM-SEC-032` — Protección contra leakage de system prompt
**Severidad:** medium · **Aplica a:** ai

Asumir que el system prompt **se filtrará**. No poner secretos, datos sensibles
ni lógica de seguridad que el usuario no pueda ver.

**Dónde buscar:** `**/prompts/**`, `**/llm/**`, `**/ai/**`
**Patrones:**
- `sk-[a-zA-Z0-9]{20,}|api_?key\s*[:=]\s*["'][^"']+["']`     # secretos en prompt
- `internal.*url|http://[a-z0-9.-]+\.internal|admin.*endpoint`     # URLs internas
- `if.*role.*admin.*then|access.*based.*on.*prompt`     # control de acceso desde prompt (mal)
- `system\s*[:=].*\b(password|token|secret)\b`     # credenciales en system prompt
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

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
