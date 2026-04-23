# 09 · Accesibilidad · Comprensible y robusto (WCAG 2.2 AA + ARIA)

> Principios **Comprensible** y **Robusto** de WCAG, más patrones ARIA
> apropiados.

---

## A. Comprensible

#### `A11Y-UND-001` — Idioma de la página y de fragmentos declarado
**Severidad:** high · **Tags:** `wcag-3-1-1`, `wcag-3-1-2` · **Aplica a:** frontend

El `<html lang="...">` refleja el idioma; fragmentos en otro idioma se marcan.

**Verificar:**
- [ ] `<html lang="es">` (o el correspondiente) en cada página.
- [ ] Fragmentos de otro idioma con `lang="en"` en el elemento.
- [ ] Las imágenes con texto en otro idioma tienen `alt` en el idioma correcto.

---

#### `A11Y-UND-002` — Navegación consistente
**Severidad:** medium · **Tags:** `wcag-3-2-3` · **Aplica a:** frontend

La navegación está en el mismo lugar y orden en todas las páginas.

**Verificar:**
- [ ] Menú principal en la misma ubicación en todas las páginas.
- [ ] Componentes identificados consistentemente (mismo label, mismo ícono).

(Cross con `UX-CONSIST-002`.)

---

#### `A11Y-UND-003` — Sin cambios de contexto automáticos
**Severidad:** high · **Tags:** `wcag-3-2-1`, `wcag-3-2-2` · **Aplica a:** frontend

Al enfocar o cambiar un campo, no se navega a otra página ni se envían
formularios automáticamente.

**Verificar:**
- [ ] Focus en un elemento NO dispara cambio de contexto (envío, redirect).
- [ ] Cambio de valor (onChange) en select/checkbox NO auto-envía salvo que el usuario lo sepa y haya alternativa.
- [ ] Pop-ups inesperados son gatillados por acción explícita.

---

#### `A11Y-UND-004` — Errores y formularios con ayuda
**Severidad:** high · **Tags:** `wcag-3-3-1`, `wcag-3-3-3` · **Aplica a:** frontend

Los errores se identifican explícitamente y el sistema ayuda a corregir.

**Verificar:**
- [ ] Cada error tiene texto visible + `aria-describedby` desde el input.
- [ ] Campos inválidos con `aria-invalid="true"`.
- [ ] Sugerencias concretas ("El email debe incluir @").
- [ ] Focus se lleva al primer error al intentar enviar.
- [ ] Campos obligatorios indicados con `aria-required="true"` y visualmente.

---

#### `A11Y-UND-005` — Confirmación en acciones legales/financieras
**Severidad:** high · **Tags:** `wcag-3-3-4`, `wcag-3-3-6` · **Aplica a:** frontend

Transacciones, envíos legales, borrados: revisables, confirmables o
reversibles.

**Verificar:**
- [ ] Pantalla de revisión antes del envío.
- [ ] Confirmación explícita antes de cobro o borrado.
- [ ] Posibilidad de editar/cancelar tras enviar (cuando sea posible).

(Cross con `UX-FEED-010`.)

---

#### `A11Y-UND-006` — Autocompletado y ayuda consistente
**Severidad:** medium · **Tags:** `wcag-1-3-5`, `wcag-3-3-7` · **Aplica a:** frontend

Los campos con significado estándar usan el atributo `autocomplete` apropiado.

**Verificar:**
- [ ] Inputs de nombre, email, teléfono, dirección con `autocomplete="given-name"`, `email`, etc.
- [ ] WCAG 2.2 SC 3.3.7: "Redundant Entry" — no se pide al usuario reingresar datos que ya dio en el flujo.

---

## B. Robusto y ARIA

#### `A11Y-ROB-001` — HTML válido y sin IDs duplicados
**Severidad:** medium · **Tags:** `wcag-4-1-1` · **Aplica a:** frontend

El HTML valida; IDs son únicos; atributos se usan correctamente.

**Verificar:**
- [ ] Sin IDs duplicados en el DOM.
- [ ] Linter / validator HTML en el pipeline.
- [ ] Atributos `aria-*` con valores permitidos.

**Nota:** WCAG 2.2 removió el SC 4.1.1 "Parsing" (asumido cubierto por navegadores modernos), pero los IDs únicos siguen siendo críticos para referencias ARIA.

---

#### `A11Y-ROB-002` — Name, role, value correctos
**Severidad:** critical · **Tags:** `wcag-4-1-2` · **Aplica a:** frontend

Cada control UI expone programáticamente:

- **name** (accessible name: label, aria-label, aria-labelledby),
- **role** (botón, link, tab, etc.),
- **value/state** (expanded, selected, checked).

**Verificar:**
- [ ] Todos los interactivos tienen accessible name ("Enviar", "Cerrar modal", no "×" solo).
- [ ] Se usan elementos nativos cuando es posible (`<button>`, `<a>`, `<select>`).
- [ ] Componentes custom declaran `role` y actualizan estados ARIA.
- [ ] Accessibility tree se inspecciona en DevTools y tiene sentido.

**Banderas rojas:**
- `<div onClick>` sin `role="button"` ni `tabindex="0"`.
- Iconos-solo sin etiqueta.

---

#### `A11Y-ROB-003` — Anuncios de cambios dinámicos
**Severidad:** high · **Tags:** `wcag-4-1-3` · **Aplica a:** frontend

Notificaciones, cambios, validaciones asincrónicas se anuncian a tecnologías
asistivas.

**Verificar:**
- [ ] `aria-live="polite"` en regiones de feedback menor (toasts, cambio de conteo).
- [ ] `aria-live="assertive"` / `role="alert"` en errores críticos.
- [ ] `role="status"` para loading / saved.
- [ ] Los mensajes se inyectan al DOM después de estar listos (no en vacío).

---

## C. Patrones ARIA comunes

#### `A11Y-ARIA-001` — Modales y diálogos
**Severidad:** high · **Aplica a:** frontend

**Verificar:**
- [ ] `role="dialog"` o `role="alertdialog"`.
- [ ] `aria-modal="true"`.
- [ ] `aria-labelledby` apunta al título.
- [ ] Focus trap dentro del modal.
- [ ] Al cerrar, foco vuelve al disparador.
- [ ] Fondo inerte (`inert` / `aria-hidden="true"` en el resto).

---

#### `A11Y-ARIA-002` — Dropdowns y menús
**Severidad:** high · **Aplica a:** frontend

**Verificar:**
- [ ] Trigger con `aria-haspopup="menu"`, `aria-expanded`.
- [ ] `role="menu"` / `role="menubar"` con `role="menuitem"`.
- [ ] Navegación con flechas dentro; Tab sale del menú.
- [ ] Al abrir, foco se mueve al primer item (o se usa `aria-activedescendant`).

---

#### `A11Y-ARIA-003` — Tabs
**Severidad:** high · **Aplica a:** frontend

**Verificar:**
- [ ] `role="tablist"`, `role="tab"` (con `aria-selected`), `role="tabpanel"`.
- [ ] `aria-controls` desde tab a panel, `aria-labelledby` en panel.
- [ ] Flechas ← → para cambiar tab; Home/End.
- [ ] Una sola tab en el tab order (otras `tabindex="-1"`).

---

#### `A11Y-ARIA-004` — Accordion / Disclosure
**Severidad:** medium · **Aplica a:** frontend

**Verificar:**
- [ ] Trigger es `<button>` con `aria-expanded`.
- [ ] `aria-controls` apunta al panel.
- [ ] Panel con `id` que lo haga referenciable.

---

#### `A11Y-ARIA-005` — Tooltips
**Severidad:** medium · **Aplica a:** frontend

**Verificar:**
- [ ] Contenido no crítico (no esencial para completar la tarea).
- [ ] Aparece por hover Y focus; se mantiene al mover hacia el tooltip.
- [ ] Se cierra con Escape.
- [ ] `aria-describedby` desde el elemento activador.

---

#### `A11Y-ARIA-006` — Combobox y autocomplete
**Severidad:** medium · **Aplica a:** frontend

**Verificar:**
- [ ] `role="combobox"` con `aria-expanded`, `aria-controls`, `aria-autocomplete`.
- [ ] Lista con `role="listbox"`, items con `role="option"`.
- [ ] Flechas navegan la lista sin mover foco (aria-activedescendant).
- [ ] Enter selecciona; Escape cierra.

---

#### `A11Y-ARIA-007` — Tree / Treegrid / Data grid
**Severidad:** medium · **Aplica a:** frontend

Componentes complejos siguen el patrón del Authoring Practices Guide.

**Verificar:**
- [ ] Estructura ARIA correcta del patrón.
- [ ] Keyboard: flechas, Home, End, typeahead si aplica.
- [ ] Estados comunicados (expanded, selected, busy).

---

## D. Testing de accesibilidad

#### `A11Y-TEST-001` — Herramientas automáticas en el pipeline
**Severidad:** high · **Aplica a:** testing

Axe-core u otro escáner corre en tests E2E; Lighthouse CI con presupuesto
de a11y.

(Ver `TEST-A11Y-001`.)

---

#### `A11Y-TEST-002` — Testing manual con teclado y screen reader
**Severidad:** high · **Aplica a:** testing

Revisión humana regular con NVDA/JAWS/VoiceOver y navegación solo por teclado.

**Verificar:**
- [ ] Checklist de audit manual aplicado en releases relevantes.
- [ ] Testeado al menos con NVDA (Windows/Firefox) y VoiceOver (macOS/Safari o iOS).
- [ ] Usuarios con discapacidad incluidos en pruebas cuando sea posible.

---

## Checklist resumen

| ID               | Control                                           | Severidad |
| ---------------- | ------------------------------------------------- | --------- |
| A11Y-UND-001     | Idioma declarado                                  | high      |
| A11Y-UND-002     | Navegación consistente                            | medium    |
| A11Y-UND-003     | Sin cambios de contexto automáticos               | high      |
| A11Y-UND-004     | Errores y formularios con ayuda                   | high      |
| A11Y-UND-005     | Confirmación legal/financiera                     | high      |
| A11Y-UND-006     | Autocompletado estándar                           | medium    |
| A11Y-ROB-001     | HTML válido, IDs únicos                           | medium    |
| A11Y-ROB-002     | Name/role/value correctos                         | critical  |
| A11Y-ROB-003     | Anuncios de cambios dinámicos                     | high      |
| A11Y-ARIA-001    | Modales                                           | high      |
| A11Y-ARIA-002    | Dropdowns / menús                                 | high      |
| A11Y-ARIA-003    | Tabs                                              | high      |
| A11Y-ARIA-004    | Accordion / disclosure                            | medium    |
| A11Y-ARIA-005    | Tooltips                                          | medium    |
| A11Y-ARIA-006    | Combobox / autocomplete                           | medium    |
| A11Y-ARIA-007    | Tree / grid                                       | medium    |
| A11Y-TEST-001    | Tests automáticos (→ testing)                     | high      |
| A11Y-TEST-002    | Testing manual con teclado y AT                   | high      |
