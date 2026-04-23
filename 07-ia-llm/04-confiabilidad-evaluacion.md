# 07 · IA / LLM · Confiabilidad, hallucinations y evaluación

> Verificación de salidas, grounding, reducción de alucinaciones, evaluación
> continua y manejo de incertidumbre.

---

## A. Reducción de alucinaciones

#### `LLM-REL-001` — Grounding contra fuentes cuando aplica
**Severidad:** high · **Tags:** `rag`, `hallucinations` · **Aplica a:** ai

Respuestas con hechos se basan en fuentes (documento provisto, BD, retrieval),
no en la memoria paramétrica del modelo.

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

**Verificar:**
- [ ] "Verifier": segunda llamada con criterios de validación.
- [ ] O regla determinista que chequea el formato, tipos, consistencia.
- [ ] Si falla la verificación, se reintenta con feedback o se devuelve error.

---

#### `LLM-REL-003` — "No sé" como opción válida
**Severidad:** medium · **Aplica a:** ai

El prompt admite explícitamente que el modelo diga "no tengo suficiente
información" en vez de inventar.

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

**Verificar:**
- [ ] La elección está documentada por caso de uso.
- [ ] Tests que verifican reproducibilidad cuando se espera.
- [ ] Para chains, se documenta si la no-determinación es aceptable.

---

#### `LLM-REL-011` — Consenso por múltiples ejecuciones (self-consistency)
**Severidad:** low · **Aplica a:** ai

Para decisiones críticas, se puede ejecutar N veces y tomar consenso / mayoría.

**Verificar:**
- [ ] Se evalúa si aporta frente al costo.
- [ ] Umbral de confianza documentado (ej: "coinciden ≥ 3/5 → aceptar").

---

## C. Evaluación continua

#### `LLM-EVAL-001` — Dataset de evaluación mantenido
**Severidad:** high · **Aplica a:** ai

Existe un dataset curado de ejemplos representativos con respuestas esperadas
(o criterios de calidad) que se usa para evaluar cambios.

**Verificar:**
- [ ] Dataset versionado en el repo o en un sistema de eval.
- [ ] Incluye casos: felices, borde, adversarios (jailbreak attempts).
- [ ] Se expande cuando aparecen regresiones o bugs.

---

#### `LLM-EVAL-002` — Métricas automatizadas de calidad
**Severidad:** medium · **Aplica a:** ai

Hay métricas automáticas (match exacto, semantic similarity, LLM-as-judge con
rúbrica, classifier-based) que comparan outputs con referencia.

**Verificar:**
- [ ] Al menos una métrica cuantitativa definida y medida.
- [ ] Regresión en métrica falla CI o alerta.
- [ ] Se combinan métricas automáticas con revisión humana periódica.

---

#### `LLM-EVAL-003` — Evaluación humana periódica
**Severidad:** medium · **Aplica a:** ai

Se revisan muestras reales con humanos para detectar problemas que las
métricas automáticas no ven.

**Verificar:**
- [ ] Proceso periódico (semanal/mensual).
- [ ] Criterios de calidad documentados.
- [ ] Resultados alimentan el dataset y los prompts.

---

#### `LLM-EVAL-004` — Evaluación adversarial (red-teaming)
**Severidad:** medium · **Tags:** `safety` · **Aplica a:** ai · security

Se busca activamente cómo romper el sistema: prompt injection, jailbreaks,
data leakage, sesgos.

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

**Verificar:**
- [ ] El schema de output incluye `confidence` cuando tiene sentido.
- [ ] La UI muestra la confianza (barra, etiqueta).
- [ ] Decisiones con baja confianza se marcan para revisión.

---

#### `LLM-REL-021` — Disclaimer visible ante output de IA
**Severidad:** medium · **Aplica a:** frontend

El usuario sabe que un contenido proviene de IA y tiene limitaciones.

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
