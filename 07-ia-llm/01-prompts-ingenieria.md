# 07 · IA / LLM · Ingeniería de prompts

> Estructura, gestión y calidad de los prompts. Separación de system/user,
> variables, versionado y evaluación.
>
> **Marcos de referencia:** OWASP Top 10 for LLM Applications · NIST AI RMF · Anthropic/OpenAI prompting guides.

---

## A. Arquitectura de prompts

#### `LLM-PROMPT-001` — Prompts en archivos versionados, fuera del código
**Severidad:** high · **Aplica a:** ai · backend

Los prompts largos viven en archivos de texto o YAML versionados, no
hardcodeados como strings en medio de la lógica.

**Verificar:**
- [ ] Directorio `/prompts/` (o similar) con archivos por prompt, en el repo.
- [ ] Cada prompt tiene metadata: versión, autor, fecha, propósito.
- [ ] El código carga prompts por nombre/ID, no los escribe inline.
- [ ] Cambiar un prompt es un commit rastreable (diff claro).

**Banderas rojas:**
- Prompts de 100+ líneas embebidos en una función.
- Múltiples variantes del mismo prompt repartidas en el código.

---

#### `LLM-PROMPT-002` — Separación clara entre system, user y data
**Severidad:** critical · **Tags:** `owasp-llm01`, `prompt-injection` · **Aplica a:** ai · backend

El mensaje del sistema (instrucciones, reglas) se separa estrictamente del
input del usuario y de los datos embebidos, usando los roles que la API ofrece.

**Verificar:**
- [ ] `system` / `developer` role contiene las instrucciones.
- [ ] `user` role contiene la intención del usuario.
- [ ] Datos / documentos se embeben con delimitadores claros (`<document>...</document>`, XML/JSON estructurado).
- [ ] Las instrucciones no se concatenan con el input del usuario en un solo string.

**Banderas rojas:**
- `prompt = f"You are an assistant. The user asks: {user_input}. Answer nicely."`
- Todo el contenido en un solo `user` role.

**Referencias:** OWASP LLM01:2025 — Prompt Injection.

---

#### `LLM-PROMPT-003` — Variables y plantillas con sanitización
**Severidad:** high · **Tags:** `prompt-injection` · **Aplica a:** ai · backend

Las variables en plantillas de prompt se sanitizan antes de insertarse,
especialmente cuando provienen de usuarios.

**Verificar:**
- [ ] Las plantillas usan motor seguro (no string concat).
- [ ] El input del usuario se escapa o delimita para evitar que "rompa" la estructura del prompt.
- [ ] Se ponen límites de longitud al input del usuario antes de insertar.
- [ ] Caracteres especiales del formato usado (XML, markdown) se escapan.

---

#### `LLM-PROMPT-004` — Versionado y comparación entre versiones
**Severidad:** medium · **Aplica a:** ai

Cada cambio de prompt se evalúa contra un set de casos antes de reemplazar la
versión viva.

**Verificar:**
- [ ] Hay test set (dataset) con ejemplos representativos y outputs esperados.
- [ ] Framework de evaluación (LangSmith, promptfoo, evals propios) compara versiones.
- [ ] La regresión en métricas importantes bloquea el cambio.

---

## B. Calidad del prompt

#### `LLM-PROMPT-010` — Instrucciones claras y sin ambigüedad
**Severidad:** medium · **Aplica a:** ai

El prompt explicita rol, tarea, formato de salida, restricciones y ejemplos
cuando ayudan.

**Verificar:**
- [ ] Rol definido: "Eres un asistente de X con conocimiento en Y".
- [ ] Tarea específica: "Extraer las fechas de vencimiento del siguiente contrato".
- [ ] Formato esperado explícito (JSON con schema, markdown con secciones).
- [ ] Casos borde cubiertos ("si no hay datos, responde con `{ "items": [] }`").
- [ ] Ejemplos few-shot cuando aportan (no cuando lo hacen peor).

---

#### `LLM-PROMPT-011` — Salida estructurada cuando el consumidor la procesa
**Severidad:** high · **Tags:** `reliability` · **Aplica a:** ai · backend

Si el output se parsea por código, se exige JSON con schema (vía function
calling / structured output o instrucción explícita + validación).

**Verificar:**
- [ ] Se usa la API de structured output / function calling cuando está disponible.
- [ ] El schema de salida está definido (JSON Schema, Pydantic, Zod).
- [ ] El output se valida contra el schema antes de usarse.
- [ ] Hay fallback o retry cuando el output no parsea.

**Banderas rojas:**
- Parsear output con regex frágil sobre texto libre.
- `json.loads(response)` sin try/except ni validación.

---

#### `LLM-PROMPT-012` — Chain-of-thought / razonamiento cuando mejora el resultado
**Severidad:** low · **Aplica a:** ai

Para tareas complejas, se pide al modelo que piense paso a paso (visible u
oculto según la API).

**Verificar:**
- [ ] En tareas de análisis complejo, el prompt guía razonamiento estructurado.
- [ ] Se evalúa si el chain-of-thought mejora vs. simplemente pedir la respuesta.

---

## C. Contexto y retrieval

#### `LLM-PROMPT-020` — Contexto relevante, acotado y con fuente
**Severidad:** high · **Tags:** `rag`, `hallucinations` · **Aplica a:** ai

Cuando se usa RAG (retrieval-augmented generation), se inserta solo el contexto
relevante y se pide al modelo citar la fuente.

**Verificar:**
- [ ] El retrieval devuelve top-K chunks relevantes, con identificador.
- [ ] Los chunks se insertan con metadata (id, fuente) visible al modelo.
- [ ] Se instruye explícitamente al modelo que use SOLO la información de los chunks.
- [ ] El output cita `source_id` por afirmación.

---

#### `LLM-PROMPT-021` — Longitud de contexto dentro del límite con margen
**Severidad:** medium · **Tags:** `cost`, `reliability` · **Aplica a:** ai

El prompt total (system + user + context + few-shot) queda dentro del contexto
máximo del modelo, con margen para la respuesta.

**Verificar:**
- [ ] Tokenizer mide la longitud antes de enviar.
- [ ] Si se excede, se trunca o resume con estrategia clara (no "drop middle" silencioso).
- [ ] Logs alertan cuando se alcanza > 80% de capacidad.

---

## D. Idioma y dominio

#### `LLM-PROMPT-030` — Idioma del prompt alineado con el output esperado
**Severidad:** medium · **Aplica a:** ai

Las instrucciones se dan en el idioma del output esperado, o se especifica
explícitamente el idioma.

**Verificar:**
- [ ] El prompt define el idioma de la respuesta.
- [ ] Los ejemplos few-shot son en el idioma correcto.
- [ ] Los tests cubren los idiomas soportados.

---

#### `LLM-PROMPT-031` — Terminología del dominio explícita cuando es necesaria
**Severidad:** medium · **Aplica a:** ai

Para dominios específicos (legal, médico, financiero), se entrega glosario o
definiciones cuando los términos pueden ambigüarse.

**Verificar:**
- [ ] Glosario / definiciones clave dentro del prompt cuando aporta.
- [ ] Términos específicos del cliente / país aclarados.
- [ ] Ejemplos de uso correcto cuando la terminología es crítica.

---

## Checklist resumen

| ID                | Control                                           | Severidad |
| ----------------- | ------------------------------------------------- | --------- |
| LLM-PROMPT-001    | Prompts en archivos versionados                   | high      |
| LLM-PROMPT-002    | Separación system/user/data                       | critical  |
| LLM-PROMPT-003    | Variables con sanitización                        | high      |
| LLM-PROMPT-004    | Versionado y eval entre versiones                 | medium    |
| LLM-PROMPT-010    | Instrucciones claras                              | medium    |
| LLM-PROMPT-011    | Salida estructurada cuando se parsea              | high      |
| LLM-PROMPT-012    | Chain-of-thought cuando mejora                    | low       |
| LLM-PROMPT-020    | Contexto con fuente para RAG                      | high      |
| LLM-PROMPT-021    | Longitud dentro del límite                        | medium    |
| LLM-PROMPT-030    | Idioma explícito                                  | medium    |
| LLM-PROMPT-031    | Glosario de dominio                               | medium    |
