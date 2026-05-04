# 07 · IA / LLM · Confiabilidad, hallucinations y evaluación

> Verificación de salidas, grounding, reducción de alucinaciones, evaluación
> continua y manejo de incertidumbre.

---

## A. Reducción de alucinaciones

#### `LLM-REL-001` — Grounding contra fuentes cuando aplica
**Severidad:** high · **Tags:** `rag`, `hallucinations` · **Aplica a:** ai

Respuestas con hechos se basan en fuentes (documento provisto, BD, retrieval),
no en la memoria paramétrica del modelo.

**Dónde buscar:** `**/rag/**`, `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `embedding|vector_?store|pinecone|weaviate|qdrant|chroma|pgvector`     # stack de retrieval
- `cite|citation|source_id|<source.*id`     # citación exigida
- `Use only the provided|solo usar el contexto|do not invent`     # restricción al contexto
- `validate.*citation|verify.*source.*exists`     # validación de citas
**Señal de N/A:** el LLM no produce afirmaciones de hechos verificables (solo creatividad/generación abierta).

**Verificar:**
- [ ] Se inserta el contexto relevante en el prompt (RAG, tool call a BD).
- [ ] Se instruye al modelo que use solo lo provisto.
- [ ] Se exige citación (ID de párrafo/documento) por afirmación.
- [ ] Las citaciones se validan (existen, coinciden con contenido).

---

#### `LLM-REL-002` — Auto-crítica o verificación post-hoc
**Severidad:** medium · **Aplica a:** ai

Para tareas críticas, hay un segundo paso que verifica si el output cumple
con la tarea antes de devolverlo.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `verify|verifier|critic|self_check|reflect`     # paso de verificación
- `validate.*(schema|output)|zod.*parse|pydantic.*validate`     # validación determinista
- `retry.*on.*invalid|feedback.*loop`     # retry con feedback
**Señal de N/A:** el LLM se usa solo para tareas no críticas donde la auto-crítica no aporta.

**Verificar:**
- [ ] "Verifier": segunda llamada con criterios de validación.
- [ ] O regla determinista que chequea el formato, tipos, consistencia.
- [ ] Si falla la verificación, se reintenta con feedback o se devuelve error.

---

#### `LLM-REL-003` — "No sé" como opción válida
**Severidad:** medium · **Aplica a:** ai

El prompt admite explícitamente que el modelo diga "no tengo suficiente
información" en vez de inventar.

**Dónde buscar:** `**/prompts/**`, `**/llm/**`, `**/*.{ts,js,py,yaml,yml,md,txt}`
**Patrones:**
- `if.*you.*don.?t.*know|si no.*tienes.*suficiente|inconclusive|insufficient`     # instrucción explícita
- `result.*null|status.*unknown|confidence.*low`     # schema lo soporta
- `metric.*unknown|count.*no.?answer`     # métrica de "no sé"
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Instrucción explícita: "si no hay datos suficientes, responde con `{"result": null}` o `Inconclusivo`".
- [ ] El schema de salida soporta esa respuesta.
- [ ] Se contabiliza cuántas respuestas son "no sé" (métrica).

---

## B. Consistencia

#### `LLM-REL-010` — Temperature/seed apropiados para la tarea
**Severidad:** medium · **Aplica a:** ai

Tareas que requieren reproducibilidad usan `temperature=0` y, si el proveedor
lo ofrece, `seed`. Tareas creativas, temperature mayor.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py,yaml,yml}`
**Patrones:**
- `temperature\s*[:=]\s*(0|0\.0|1|1\.0|0\.7)`     # valores explícitos
- `temperature\s*[:=]\s*1(?!\d)`     # temperature 1 (revisar si es deterministic)
- `seed\s*[:=]|seed:\s*\d+`     # seed configurado
- `\.create\([^)]*(?!temperature)[^)]*\)`     # llamada sin temperature explícita
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] La elección está documentada por caso de uso.
- [ ] Tests que verifican reproducibilidad cuando se espera.
- [ ] Para chains, se documenta si la no-determinación es aceptable.

---

#### `LLM-REL-011` — Consenso por múltiples ejecuciones (self-consistency)
**Severidad:** low · **Aplica a:** ai

Para decisiones críticas, se puede ejecutar N veces y tomar consenso / mayoría.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py}`
**Patrones:**
- `self_consistency|majority.*vote|consensus.*N|run.*N.*times`     # patrón de consenso
- `for.*in.*range\(\s*[3-9]\s*\).*completion`     # ejecuciones múltiples
- `agreement.*threshold|votes\s*>=`     # umbral
**Señal de N/A:** la tarea no es crítica o el costo de N ejecuciones no se justifica.

**Verificar:**
- [ ] Se evalúa si aporta frente al costo.
- [ ] Umbral de confianza documentado (ej: "coinciden ≥ 3/5 → aceptar").

---

## C. Evaluación continua

#### `LLM-EVAL-001` — Dataset de evaluación mantenido
**Severidad:** high · **Aplica a:** ai

Existe un dataset curado de ejemplos representativos con respuestas esperadas
(o criterios de calidad) que se usa para evaluar cambios.

**Dónde buscar:** `**/evals/**`, `**/datasets/**`, `**/tests/llm/**`, `**/*.{json,jsonl,csv,yaml}`
**Patrones:**
- `evals?\/.*\.(json|jsonl|csv|yaml)|dataset.*\.jsonl`     # dataset versionado
- `expected.*output|reference.*answer|golden.*set`     # respuestas esperadas
- `adversarial|jailbreak|injection.*test`     # casos adversarios
- `prompts.*test|llm.*test.*case|eval.*case`     # tests para prompts
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Dataset versionado en el repo o en un sistema de eval.
- [ ] Incluye casos: felices, borde, adversarios (jailbreak attempts).
- [ ] Se expande cuando aparecen regresiones o bugs.

---

#### `LLM-EVAL-002` — Métricas automatizadas de calidad
**Severidad:** medium · **Aplica a:** ai

Hay métricas automáticas (match exacto, semantic similarity, LLM-as-judge con
rúbrica, classifier-based) que comparan outputs con referencia.

**Dónde buscar:** `**/evals/**`, `**/tests/llm/**`, `**/*.{ts,js,py}`
**Patrones:**
- `bleu|rouge|bert.?score|exact_match|semantic.*similarity`     # métricas clásicas
- `llm.?as.?judge|judge.*prompt|rubric`     # LLM-as-judge
- `assert.*similarity\s*>|score\s*>=\s*0\.`     # umbrales
- `ci.*eval|github.*workflow.*eval`     # bloqueo en CI
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Al menos una métrica cuantitativa definida y medida.
- [ ] Regresión en métrica falla CI o alerta.
- [ ] Se combinan métricas automáticas con revisión humana periódica.

---

#### `LLM-EVAL-003` — Evaluación humana periódica
**Severidad:** medium · **Aplica a:** ai

Se revisan muestras reales con humanos para detectar problemas que las
métricas automáticas no ven.

**Dónde buscar:** `**/evals/**`, `**/review/**`, `**/labeling/**`, `**/*.md`
**Patrones:**
- *(sin patrones mecánicos — revisión humana / proceso)*
- `human.*review|annotation|label.*queue|labelbox|argilla`     # plataforma/proceso
- `weekly.*review|monthly.*audit`     # cadencia
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Proceso periódico (semanal/mensual).
- [ ] Criterios de calidad documentados.
- [ ] Resultados alimentan el dataset y los prompts.

---

#### `LLM-EVAL-004` — Evaluación adversarial (red-teaming)
**Severidad:** medium · **Tags:** `safety` · **Aplica a:** ai · security

Se busca activamente cómo romper el sistema: prompt injection, jailbreaks,
data leakage, sesgos.

**Dónde buscar:** `**/evals/**`, `**/security/**`, `**/red.?team*`, `**/*.{md,jsonl}`
**Patrones:**
- `red.?team|jailbreak.*test|adversarial.*prompt`     # casos red-team
- `garak|pyrit|promptbench`     # frameworks
- `injection.*case|leak.*test|bias.*test`     # casos específicos
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Sesiones de red-teaming con cadencia definida.
- [ ] Casos descubiertos se incorporan al dataset.
- [ ] Mitigaciones se despliegan y documentan.

---

## D. Transparencia y manejo de incertidumbre

#### `LLM-REL-020` — Mostrar nivel de confianza cuando aplique
**Severidad:** low · **Aplica a:** ai · frontend

Cuando el modelo retorna una decisión probabilística, se comunica la
incertidumbre al usuario.

**Dónde buscar:** `**/llm/**`, `**/components/**`, `**/*.{ts,js,py,tsx,jsx}`
**Patrones:**
- `confidence|certainty|probability|score`     # campo de confianza
- `<ConfidenceBar|<Confidence|confidence.*indicator`     # UI de confianza
- `if.*confidence.*<.*review|low.*confidence.*flag`     # gating por confianza
**Señal de N/A:** los outputs no se prestan a un score de confianza significativo.

**Verificar:**
- [ ] El schema de output incluye `confidence` cuando tiene sentido.
- [ ] La UI muestra la confianza (barra, etiqueta).
- [ ] Decisiones con baja confianza se marcan para revisión.

---

#### `LLM-REL-021` — Disclaimer visible ante output de IA
**Severidad:** medium · **Aplica a:** frontend

El usuario sabe que un contenido proviene de IA y tiene limitaciones.

**Dónde buscar:** `**/components/**`, `**/*.{tsx,jsx,vue,svelte}`, `**/llm/**`
**Patrones:**
- `disclaimer|generated.?by.?ai|verify.*before.*using`     # disclaimer textual
- `not.*professional.*advice|consult.*professional`     # disclaimers de dominios regulados
- `<Disclaimer|<Alert.*ai`     # componentes de disclaimer
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Disclaimer junto al output: "Resumen generado por IA. Verifica lo importante".
- [ ] Links a fuentes cuando existen.
- [ ] Para dominios regulados (legal, médico), el disclaimer es explícito sobre no sustituir consulta profesional.

---

## E. Sesgos y equidad

#### `LLM-FAIR-001` — Auditoría de sesgos
**Severidad:** medium · **Tags:** `fairness`, `nist-ai-rmf` · **Aplica a:** ai

Se verifica periódicamente que el sistema no discrimina por género, etnia,
edad, etc., en outputs con impacto social.

**Dónde buscar:** `**/evals/**`, `**/fairness/**`, `**/*.{ts,js,py,jsonl}`
**Patrones:**
- `bias.*test|fairness.*audit|disparate.*impact`     # tests de sesgo
- `gender|ethnicity|age|race.*variant`     # variación de atributos
- `aif360|fairlearn|whatif`     # frameworks
**Señal de N/A:** los outputs LLM no tienen impacto social diferenciado (ningún uso decisional sobre personas).

**Verificar:**
- [ ] Tests con inputs variando atributos sensibles (mismo contenido, diferente género).
- [ ] Métricas de paridad documentadas.
- [ ] Mitigaciones cuando se detecta sesgo.

---

## F. Actualizaciones del modelo

#### `LLM-REL-030` — Pin del modelo y política de upgrade
**Severidad:** medium · **Aplica a:** ai

Se especifica la versión exacta del modelo para reproducibilidad; los upgrades
se evalúan antes de desplegar.

**Dónde buscar:** `**/llm/**`, `**/ai/**`, `**/*.{ts,js,py,yaml,yml,env}`, `package.json`, `requirements.txt`
**Patrones:**
- `model\s*[:=]\s*["']?(gpt|claude|gemini)-[\w.-]+-\d{4,}`     # versión pinneada (deseable)
- `model\s*[:=]\s*["']?(gpt-4|claude-3|gpt-3\.5)["']?\s*[,)]`     # alias suelto (revisar)
- `latest|preview|beta`     # alias inestables
- `MODEL_VERSION|MODEL_ID`     # variable centralizada
**Señal de N/A:** ningún import de `openai|anthropic|@langchain|@google/generative-ai|cohere|replicate|mistral|together-ai|huggingface`.

**Verificar:**
- [ ] Modelo versionado explícitamente (`claude-sonnet-4-6`, `gpt-4o-2024-XX-XX`).
- [ ] Antes de cambiar a una versión nueva, se corre la suite de eval.
- [ ] La migración a un modelo nuevo se planifica y documenta.

---

## Checklist resumen

| ID               | Control                                          | Severidad |
| ---------------- | ------------------------------------------------ | --------- |
| LLM-REL-001      | Grounding contra fuentes                         | high      |
| LLM-REL-002      | Verificación post-hoc                            | medium    |
| LLM-REL-003      | "No sé" como opción válida                       | medium    |
| LLM-REL-010      | Temperature/seed apropiados                      | medium    |
| LLM-REL-011      | Self-consistency si aporta                       | low       |
| LLM-EVAL-001     | Dataset de evaluación                            | high      |
| LLM-EVAL-002     | Métricas automatizadas                           | medium    |
| LLM-EVAL-003     | Evaluación humana periódica                      | medium    |
| LLM-EVAL-004     | Red-teaming                                      | medium    |
| LLM-REL-020      | Mostrar confianza                                | low       |
| LLM-REL-021      | Disclaimer de IA visible                         | medium    |
| LLM-FAIR-001     | Auditoría de sesgos                              | medium    |
| LLM-REL-030      | Pin de modelo + política de upgrade              | medium    |
