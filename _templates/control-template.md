# Plantilla de control

Copia esto cuando agregues un control nuevo a cualquier módulo.

---

#### `CAT-SUBCAT-NNN` — Título corto, afirmativo, en imperativo

**Severidad:** critical | high | medium | low | info
**Tags:** `etiqueta-1`, `etiqueta-2` (ej: `owasp-a01`, `cwe-89`, `gdpr-art-32`)
**Aplica a:** backend | frontend | api | infra | data | ai | all

Descripción breve (1-3 frases) explicando **por qué** el control importa y **qué**
comportamiento esperamos. Redactar sin referencias a librerías concretas cuando sea
posible; si se nombra una tecnología, hacerlo como ejemplo (`ej: bcrypt`), no como
requisito obligatorio.

**Dónde buscar:** `glob1`, `glob2`, `glob3`
*(Globs relativos a la raíz del repo bajo análisis. Pueden ser amplios (`**/*.ts`)
o específicos (`**/auth/**`, `Dockerfile`, `package.json`). El agente usa estos
globs con `Glob` antes de cualquier `Grep`.)*

**Patrones (señales positivas de FAIL):**
- `regex_o_string_literal_1`     # comentario corto explicando qué detecta
- `regex_o_string_literal_2`
- *(Cuando una red flag no sea expresable como patrón, omitirla — no forzar.)*

**Señal de N/A:** condición procesable que indica que el control no aplica
(ej: "ningún import de `jsonwebtoken|jose|@nestjs/jwt`", "no existe `Dockerfile`",
"`package.json.dependencies` no incluye `react|vue|svelte`"). Permite al agente
saltar el control sin leerlo entero.

**Verificar:**
- [ ] Afirmación verificable 1 (lo que debe cumplirse).
- [ ] Afirmación verificable 2.
- [ ] Afirmación verificable 3.

**Banderas rojas (red flags):**
- Patrón o llamada sospechosa que el agente debe buscar en el diff.
- Anti-patrón concreto con nombre identificable.
- Ausencia de algo que debería estar (ej: "falta timeout en llamada externa").

**Ejemplo de hallazgo (opcional):**
```yaml
control_id: CAT-SUBCAT-NNN
severity: high
file: ruta/archivo.ext
line: 12
evidence: |
  fragmento exacto del código
explanation: |
  por qué esto viola el control
suggestion: |
  cómo arreglarlo
```

**Referencias:** Estándar · CWE-XXX · RFC-XXXX · Link a documentación autorizada.

---

## Reglas de redacción

1. **IDs** son estables y únicos. Nunca reutilices un ID liberado.
2. **Severidad** refleja riesgo real en producción, no opinión estética.
3. **Los "verificar"** son afirmaciones **falsables** — el agente debe poder
   decir sí/no/no aplica. Evitar verbos vagos ("adecuado", "apropiado") sin
   criterio medible.
4. **Las "banderas rojas"** son patrones de código o ausencias concretas.
   Si un control no tiene red flags identificables en un diff, probablemente
   no debería estar en un checklist de code review automatizado.
5. **Agnóstico de lenguaje**: si el control depende de una tecnología específica,
   mencionar la tecnología como ejemplo y describir el comportamiento equivalente
   en otros ecosistemas.
6. **Una idea por control**: si tienes que usar "y/o" en el título, probablemente
   son dos controles.

---

## Reglas para los nuevos campos de ejecución

7. **`Dónde buscar`** — siempre incluir al menos un glob. Si el control aplica
   a "todo el repo", usar `**/*` y dejar que `Patrones` filtre. Preferir globs
   restrictivos cuando sea posible (reduce el costo de `Grep`).

8. **`Patrones`** — strings literales o regex POSIX/PCRE compatibles con
   `ripgrep`. Cada patrón debería corresponder con una red flag específica;
   acompañar con un comentario `#` explicando qué detecta. Para detectar
   **ausencias** (ej: "falta timeout"), usar la sección `Señal de N/A` o
   describirlo en `Verificar` — los patrones grep solo detectan presencia.

9. **`Señal de N/A`** — debe ser **mecánicamente comprobable** por el agente
   (un grep, un Glob negativo, una clave del `package.json`/`pyproject.toml`).
   Frases como "no aplica si el equipo no usa X" son inútiles si el agente
   no puede verificarlas leyendo archivos.

10. **Si el control es transversal** (aplica a *cualquier* código sin patrón
    concreto, ej: principios SOLID, calidad de naming), los nuevos campos
    pueden omitirse. En ese caso el control queda marcado para revisión
    humana o LLM-judge sin búsqueda mecánica.
