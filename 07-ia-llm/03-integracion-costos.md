# 07 · IA / LLM · Integración técnica, costos y observabilidad

> Cliente al proveedor, reintentos, timeouts, streaming, cacheo, control de
> costos y observabilidad específica.

---

## A. Cliente y llamadas

#### `LLM-API-001` — Cliente reutilizable con configuración central
**Severidad:** medium · **Aplica a:** backend · ai

Hay un cliente/servicio central que envuelve las llamadas al proveedor, no
llamadas dispersas en muchos módulos.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/clients/**`, `**/*.{ts,js,py}`
**Patrones:**
- `class\s+(LLMClient|AIClient|LLMService)|export.*(llmClient|aiClient)`     # cliente central
- `new\s+(OpenAI|Anthropic)\(|openai\.OpenAI\(|anthropic\.Anthropic\(`     # instanciación dispersa (contar ocurrencias)
- `interface\s+LLM|abstract\s+class.*LLM`     # interfaz/abstracción
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Clase/módulo central `LLMClient` con métodos tipados.
- [ ] Configuración (modelo, temperatura, max_tokens, timeouts) en un solo lugar.
- [ ] Los modelos usados se listan en un enum o configuración.
- [ ] Un cambio de proveedor debería ser cuestión de implementar la interfaz.

**Banderas rojas:**
- `anthropic.Anthropic()` instanciado en 10 módulos distintos con parámetros ligeramente distintos.

---

#### `LLM-API-002` — Timeout y backoff en cada llamada
**Severidad:** critical · **Tags:** `reliability` · **Aplica a:** backend · ai

Toda llamada al proveedor tiene timeout explícito, reintentos con backoff
exponencial y límite de intentos.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `timeout\s*[:=]|request_timeout|httpx\.Timeout`     # timeout configurado
- `retry|backoff|exponential|tenacity|p-retry|@retry`     # reintentos
- `Retry-After|retry_after`     # respeto del header del proveedor
- `openai\.(create|chat).*(?!.*timeout)`     # llamada sin timeout aparente
- `max_retries|maxRetries|stop_after_attempt`     # límite de reintentos
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] `timeout` configurado (connect + read) — por defecto razonable (ej: 30-60 s según modelo).
- [ ] Reintentos ante errores transitorios (429, 5xx): exponential backoff con jitter.
- [ ] Límite de reintentos (ej: 3-5).
- [ ] No se reintentan 4xx no-recuperables (400, 401, 403).
- [ ] Respeto de `Retry-After` si el proveedor lo envía.

---

#### `LLM-API-003` — Manejo específico de errores del proveedor
**Severidad:** high · **Aplica a:** backend · ai

Cada tipo de error del proveedor se maneja distinto: rate limit vs timeout vs
content policy vs server error.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `RateLimitError|APITimeoutError|AuthenticationError|BadRequestError`     # errores tipados
- `\b(429|401|403|500|503)\b.*response\.status`     # ramas por status code
- `content_policy|content_filter|moderation.*reject`     # rechazo por política
- `catch\s*\(\s*err\s*\)\s*\{[^}]*\}`     # catch genérico (mal)
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Rate limit (429): backoff + métrica.
- [ ] Timeout: retry + alerta si persiste.
- [ ] Auth (401): alerta urgente (rotación de key).
- [ ] Content policy: no reintentar, mensaje claro al usuario.
- [ ] 5xx: reintentar, métrica, fallback.

---

#### `LLM-API-004` — Concurrencia limitada con semáforo
**Severidad:** high · **Tags:** `rate-limit`, `backpressure` · **Aplica a:** backend · ai

Cuando se procesan múltiples requests al LLM en paralelo (análisis de N
secciones), hay semáforo que respeta el rate limit del proveedor.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `Semaphore|p-limit|pLimit|asyncio\.Semaphore|bottleneck`     # semáforos / limitadores
- `Promise\.all\(.*map.*llm|asyncio\.gather.*llm`     # fan-out sin control (revisar)
- `concurrency\s*[:=]|max_concurrent|maxConcurrent`     # configuración
**Señal de N/A:** las llamadas LLM no se ejecutan en paralelo (procesamiento secuencial).

**Verificar:**
- [ ] `Semaphore` / p-limit dimensionado al rate limit del proveedor.
- [ ] Tamaño configurable por entorno.
- [ ] Cola / espera en vez de error ante saturación corta.
- [ ] Métrica de tiempo esperando vs ejecutando.

---

#### `LLM-API-005` — Streaming cuando el tamaño del output es grande
**Severidad:** medium · **Aplica a:** backend · ai

Para outputs largos (ensayos, resúmenes extensos, resultados en vivo), se usa
streaming: se reduce la latencia percibida y el uso de memoria.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `stream\s*[:=]\s*true|with_streaming_response|stream_options`     # streaming activado
- `EventSource|sse|text/event-stream|ReadableStream`     # SSE al cliente
- `for\s+chunk\s+in.*stream|for\s+await.*chunk`     # consumo del stream
- `usage.*total_tokens.*log.*after.*close`     # log de tokens al cerrar
**Señal de N/A:** los outputs son cortos y de baja latencia (streaming no aporta).

**Verificar:**
- [ ] Soporte de streaming en las rutas apropiadas (SSE al cliente, backpressure al servidor).
- [ ] Timeout total aún se respeta.
- [ ] Errores a medio stream se manejan (evento de error + cierre).
- [ ] El agregado final (tokens totales, costo) se loggea al cerrar.

---

## B. Control de costos

#### `LLM-COST-001` — Tracking de tokens y costo por request
**Severidad:** high · **Tags:** `cost-control` · **Aplica a:** backend · ai

Cada llamada al LLM registra tokens de entrada, tokens de salida, modelo y
costo estimado.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/observability/**`, `**/*.{ts,js,py}`
**Patrones:**
- `usage\.(prompt_tokens|completion_tokens|total_tokens|input_tokens|output_tokens)`     # captura de tokens
- `cost_usd|estimated_cost|price_per_token`     # costeo
- `metric.*token|prometheus.*token|datadog.*llm`     # métricas
- `openai.*chat.*completions.*create(?!.*usage)`     # llamada sin tracking
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Logs/métricas incluyen: `input_tokens`, `output_tokens`, `model`, `cost_usd`.
- [ ] Agregación por endpoint, usuario, organización, periodo.
- [ ] Dashboard de costo diario/mensual.
- [ ] Alertas ante picos.

---

#### `LLM-COST-002` — Presupuestos por usuario/org
**Severidad:** high · **Aplica a:** backend

Existen límites diarios/mensuales por entidad; al superarse, se bloquea o se
pide upgrade.

**Dónde buscar:** `**/llm/**`, `**/billing/**`, `**/quota*`, `**/*.{ts,js,py}`
**Patrones:**
- `quota|budget|monthly_limit|daily_limit|credits_remaining`     # cuotas
- `if.*tokens.*>.*limit|exceeded.*quota|over.*budget`     # bloqueo
- `tenant.*plan|subscription.*tier`     # diferenciación por plan
- `notify.*before.*exhaust|alert.*80.*percent`     # notificación previa
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Cuotas configurables por plan/tenant.
- [ ] Bloqueo / degradación al alcanzar cuota.
- [ ] Notificación al usuario antes de agotar.
- [ ] Exención para cuentas enterprise con acuerdo distinto.

---

#### `LLM-COST-003` — Selección del modelo adecuado al caso
**Severidad:** medium · **Aplica a:** ai

Se usa el modelo más barato que resuelve bien la tarea; se reservan modelos
grandes para tareas que lo justifican.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py,yaml,yml}`
**Patrones:**
- `model\s*[:=]\s*["']?(gpt-4|claude-3-opus|claude-opus-4|claude-sonnet-4)`     # modelos caros (verificar justificación)
- `model\s*[:=]\s*["']?(gpt-4o-mini|claude-haiku|gpt-3\.5|gemini.*flash)`     # modelos económicos para tareas simples
- `\b(classify|categorize|moderate|tag)\b.*model.*opus|gpt-4`     # tareas triviales con modelo grande
- `MODELS\s*=|model_config|models\.ya?ml`     # config centralizada de modelos
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Tareas triviales (clasificación, moderación) usan modelos pequeños.
- [ ] Tareas complejas (análisis profundo, razonamiento) usan modelos mayores.
- [ ] Se documenta qué modelo resuelve qué tipo de tarea y por qué.
- [ ] Experimentos documentados sobre cost/quality tradeoff.

---

#### `LLM-COST-004` — Caché de resultados idénticos
**Severidad:** medium · **Aplica a:** backend · ai

Cuando la misma entrada produce la misma salida (temperature 0, determinista),
se cachea.

**Dónde buscar:** `**/llm/**`, `**/cache/**`, `**/*.{ts,js,py}`
**Patrones:**
- `redis.*get.*prompt|cache.*hit.*llm|memoize.*llm`     # caché de respuestas
- `hash\(prompt|sha.*prompt|cache_key.*model.*temperature`     # cache key derivada
- `ttl|expires_in|cacheControl`     # TTL declarado
- `cache.*hit.*rate|metric.*cache.*llm`     # métrica de hit rate
**Señal de N/A:** las llamadas LLM nunca son idempotentes (todas con temperature > 0 o input siempre distinto).

**Verificar:**
- [ ] Cache key derivada del prompt + modelo + parámetros.
- [ ] TTL apropiado a la volatilidad del contenido.
- [ ] Invalidación cuando el prompt cambia de versión.
- [ ] Métrica de hit rate del cache.

---

#### `LLM-COST-005` — Optimización del prompt (context reuse)
**Severidad:** medium · **Aplica a:** ai · backend

Se usan features del proveedor para reducir costo de inputs repetidos: prompt
caching, context windows reutilizados, few-shot compartido.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `cache_control|prompt_caching|cached_tokens`     # prompt caching del proveedor
- `system\s*[:=]\s*\[\s*\{[^}]*type.*text.*cache_control`     # bloques cacheables
- `usage.*cache_read_input_tokens`     # métrica de hit
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Uso de "prompt caching" cuando el proveedor lo ofrece (Anthropic, OpenAI).
- [ ] System prompt largo y estable colocado primero (se cachea mejor).
- [ ] Few-shot / ejemplos no se reenvían innecesariamente.

---

## C. Observabilidad IA

#### `LLM-OBS-001` — Latencia y throughput medidos
**Severidad:** high · **Aplica a:** backend · ai · observability

Métricas de tiempo por llamada, distribución, percentiles, y contador de
éxitos/errores.

**Dónde buscar:** `**/observability/**`, `**/metrics/**`, `**/llm/**`, `**/*.{ts,js,py}`
**Patrones:**
- `histogram|summary|prometheus|datadog|opentelemetry`     # métricas
- `p50|p95|p99|percentile`     # percentiles
- `latency.*llm|duration.*llm|llm.*request.*duration`     # nombre de métricas LLM
- `success_total|error_total|requests_total.*model`     # counters
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Histogramas por endpoint y modelo.
- [ ] p50/p95/p99 visibles.
- [ ] Segmentado por tipo de operación (corto vs largo).

---

#### `LLM-OBS-002` — Log de prompts y respuestas con muestreo
**Severidad:** medium · **Tags:** `debugging`, `cost-control` · **Aplica a:** backend · ai

Se loguean prompts y respuestas con muestreo (no el 100%, costoso y sensible).
Con cuidado de no loggear PII (ver `LLM-SEC-013`).

**Dónde buscar:** `**/llm/**`, `**/observability/**`, `**/*.{ts,js,py}`
**Patrones:**
- `sample.?rate|sampling.*rate|Math\.random\(\)\s*<`     # muestreo
- `redact|scrub.*before.*log|mask.*pii`     # redacción previa
- `langsmith|helicone|langfuse|braintrust`     # plataformas de tracing
- `if.*error.*log.*100|always.*log.*errors`     # errores al 100%
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Muestreo configurable (1%, 10%).
- [ ] Redacción previa de PII.
- [ ] Retención alineada con política de privacidad.
- [ ] Los errores se loggean al 100% (sin muestreo).

---

#### `LLM-OBS-003` — Dashboards y alertas específicas
**Severidad:** medium · **Aplica a:** observability · ai

Hay dashboards dedicados a IA: costo, latencia, errores por modelo/endpoint,
tokens.

**Dónde buscar:** `**/dashboards/**`, `**/grafana/**`, `**/monitoring/**`, `**/*.{json,yaml,yml}`
**Patrones:**
- *(sin patrones mecánicos — revisión humana de dashboards configurados)*
- `grafana.*dashboard|datadog.*dashboard|cloudwatch.*dashboard`     # provisión de dashboards
- `alert.*cost|alert.*budget|alert.*error_rate`     # alertas
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Dashboard público al equipo.
- [ ] Alertas: error rate > X%, cost > budget, latencia > SLO.
- [ ] Tablero de costo por feature/producto.

---

## D. Degradación y fallback

#### `LLM-API-010` — Fallback ante falla del proveedor principal
**Severidad:** high · **Tags:** `resilience` · **Aplica a:** backend · ai

Cuando el proveedor principal falla o supera SLA, el sistema degrada
correctamente.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `circuit.?breaker|opossum|pybreaker|hystrix`     # circuit breaker
- `fallback.*model|secondary.*model|backup.*provider`     # fallback
- `degraded|service.*temporarily.*unavailable`     # mensaje al usuario
- `feature.?flag.*ai|disable.*ai.*feature`     # modo degradado
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Circuit breaker que abre al detectar fallos sostenidos.
- [ ] Mensaje claro al usuario ("servicio temporalmente indisponible") — NO 500 genérico.
- [ ] Fallback a modelo secundario si la calidad lo permite.
- [ ] Modo degradado documentado (features que siguen funcionando sin IA).

---

## Checklist resumen

| ID             | Control                                              | Severidad |
| -------------- | ---------------------------------------------------- | --------- |
| LLM-API-001    | Cliente reutilizable central                         | medium    |
| LLM-API-002    | Timeout y backoff                                    | critical  |
| LLM-API-003    | Manejo específico de errores                         | high      |
| LLM-API-004    | Concurrencia limitada                                | high      |
| LLM-API-005    | Streaming para outputs grandes                       | medium    |
| LLM-COST-001   | Tracking de tokens y costo                           | high      |
| LLM-COST-002   | Presupuestos por usuario/org                         | high      |
| LLM-COST-003   | Modelo adecuado a la tarea                           | medium    |
| LLM-COST-004   | Caché de respuestas                                  | medium    |
| LLM-COST-005   | Optimización de contexto/prompt caching              | medium    |
| LLM-OBS-001    | Latencia y throughput medidos                        | high      |
| LLM-OBS-002    | Log muestreado de prompts                            | medium    |
| LLM-OBS-003    | Dashboards y alertas IA                              | medium    |
| LLM-API-010    | Fallback ante falla                                  | high      |
