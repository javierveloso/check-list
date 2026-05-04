# 09 · Accesibilidad · Comprensible y robusto (WCAG 2.2 AA + ARIA)

> Principios **Comprensible** y **Robusto** de WCAG, más patrones ARIA
> apropiados.

---

## A. Comprensible

#### `A11Y-UND-001` — Idioma de la página y de fragmentos declarado
**Severidad:** high · **Tags:** `wcag-3-1-1`, `wcag-3-1-2` · **Aplica a:** frontend

El `<html lang="...">` refleja el idioma; fragmentos en otro idioma se marcan.

**Dónde buscar:** `**/*.html`, `**/public/**/*.html`, `**/app/layout.{tsx,jsx}`, `**/pages/_document.{tsx,jsx}`, `**/index.html`, `**/app.html`
**Patrones:**
- `<html(?![^>]*\slang=)`     # html sin lang
- `<html\s+lang=["']{2}["']`     # lang vacío
- `<html\s+lang=["'](?!(?:[a-z]{2}|[a-z]{2}-[A-Z]{2}))`     # lang con valor no estándar
- `lang=["'][a-z]{2}(-[A-Z]{2})?["']`     # uso correcto en fragmentos (esperado)
- `<title>\s*<\/title>|<title\s*\/>`     # title vacío
**Señal de N/A:** stack_signal.has_frontend == false (no hay HTML root ni layout raíz; solo backend/CLI/SDK).

**Verificar:**
- [ ] `<html lang="es">` (o el correspondiente) en cada página.
- [ ] Fragmentos de otro idioma con `lang="en"` en el elemento.
- [ ] Las imágenes con texto en otro idioma tienen `alt` en el idioma correcto.

---

#### `A11Y-UND-002` — Navegación consistente
**Severidad:** medium · **Tags:** `wcag-3-2-3` · **Aplica a:** frontend

La navegación está en el mismo lugar y orden en todas las páginas.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/layouts/**`, `**/components/**`, `**/app/**`, `**/pages/**`
**Patrones:**
- `(Layout|MainLayout|RootLayout|AppShell|DefaultLayout)`     # layout compartido
- `(<Sidebar|<Navbar|<Header|<Footer|<Nav\b)`     # componentes nav reusados
- `<nav\b`     # nav semántico (esperado en cada página/layout)
- `aria-label=["'](?:Main|Primary|Principal|Main navigation)`     # labels consistentes
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Menú principal en la misma ubicación en todas las páginas.
- [ ] Componentes identificados consistentemente (mismo label, mismo ícono).

(Cross con `UX-CONSIST-002`.)

---

#### `A11Y-UND-003` — Sin cambios de contexto automáticos
**Severidad:** high · **Tags:** `wcag-3-2-1`, `wcag-3-2-2` · **Aplica a:** frontend

Al enfocar o cambiar un campo, no se navega a otra página ni se envían
formularios automáticamente.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/forms/**`, `**/pages/**`
**Patrones:**
- `onFocus=\{[^}]*(?:submit|navigate|router|push|location)`     # focus que cambia contexto
- `onChange=\{[^}]*(?:submit|form\.submit|handleSubmit)`     # onChange auto-submit
- `onBlur=\{[^}]*(?:navigate|push|router\.|location)`     # blur que navega
- `window\.location\s*=|location\.href\s*=`     # redirects programáticos (auditar disparador)
- `<form[^>]*onChange`     # form con auto-submit en change
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Focus en un elemento NO dispara cambio de contexto (envío, redirect).
- [ ] Cambio de valor (onChange) en select/checkbox NO auto-envía salvo que el usuario lo sepa y haya alternativa.
- [ ] Pop-ups inesperados son gatillados por acción explícita.

---

#### `A11Y-UND-004` — Errores y formularios con ayuda
**Severidad:** high · **Tags:** `wcag-3-3-1`, `wcag-3-3-3` · **Aplica a:** frontend

Los errores se identifican explícitamente y el sistema ayuda a corregir.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/forms/**`
**Patrones:**
- `aria-describedby=`     # error asociado (esperado en inputs con error)
- `aria-invalid=`     # estado inválido expuesto
- `aria-required=|required\b`     # marcado de obligatorio
- `<input(?![^>]*(?:aria-label|id=|<label))`     # input sin label
- `(setFocus|focus\(\)|firstError\.focus)`     # focus al primer error
- `(errorMessage|errors\.\w+|FormMessage)`     # patrón de mensaje de error
**Señal de N/A:** stack_signal.has_frontend == false || el producto no expone formularios al usuario.

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

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/pages/**`, `**/checkout/**`, `**/payment/**`
**Patrones:**
- `(ReviewStep|Confirmation|ConfirmStep|ReviewOrder|Summary)`     # pantalla de revisión
- `(stripe|checkout|payment|charge|invoice)`     # flujos financieros
- `(softDelete|deletedAt|trash|cancelable|cancelWithin)`     # reversibilidad
- `(ConfirmDialog|requireConfirmation|typeToConfirm)`     # confirmación fuerte
- `(legal|terms|consent|agreement|signature)`     # acciones legales
**Señal de N/A:** el producto no procesa pagos, contratos legales ni acciones de alto impacto.

**Verificar:**
- [ ] Pantalla de revisión antes del envío.
- [ ] Confirmación explícita antes de cobro o borrado.
- [ ] Posibilidad de editar/cancelar tras enviar (cuando sea posible).

(Cross con `UX-FEED-010`.)

---

#### `A11Y-UND-006` — Autocompletado y ayuda consistente
**Severidad:** medium · **Tags:** `wcag-1-3-5`, `wcag-3-3-7` · **Aplica a:** frontend

Los campos con significado estándar usan el atributo `autocomplete` apropiado.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte,html}`, `**/forms/**`, `**/components/**`
**Patrones:**
- `<input(?![^>]*autocomplete=)[^>]*(?:type=["'](?:email|tel|password|text)["'])`     # input típico sin autocomplete
- `autocomplete=["'](?:given-name|family-name|email|tel|street-address|postal-code|cc-number|new-password|current-password|one-time-code)["']`     # uso correcto (esperado)
- `autocomplete=["']off["']`     # desactivación (auditar justificación)
- `name=["'](?:firstname|lastname|email|phone|address|zip)["']`     # campos comunes (cruzar con autocomplete)
**Señal de N/A:** stack_signal.has_frontend == false || el producto no tiene formularios con datos personales/de contacto.

**Verificar:**
- [ ] Inputs de nombre, email, teléfono, dirección con `autocomplete="given-name"`, `email`, etc.
- [ ] WCAG 2.2 SC 3.3.7: "Redundant Entry" — no se pide al usuario reingresar datos que ya dio en el flujo.

---

## B. Robusto y ARIA

#### `A11Y-ROB-001` — HTML válido y sin IDs duplicados
**Severidad:** medium · **Tags:** `wcag-4-1-1` · **Aplica a:** frontend

El HTML valida; IDs son únicos; atributos se usan correctamente.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte,html}`, `**/components/**`, `.eslintrc*`, `package.json`
**Patrones:**
- `id=["'][a-zA-Z][\w-]*["']`     # IDs hardcodeados (riesgo de duplicado si componente se renderiza varias veces)
- `(useId\(\)|nanoid\(\)|uniqueId\()`     # generación de IDs únicos (esperado)
- `aria-(labelledby|describedby|controls|owns)=["']([\w\s-]+)["']`     # referencias ARIA (verificar que existan)
- `(html-validate|html-validator|w3c|jsx-a11y)`     # validadores en pipeline
- `eslint-plugin-jsx-a11y`     # linter a11y
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

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

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte,html}`, `**/components/**`, `**/ui/**`
**Patrones:**
- `<div\s+role=["']button["'](?![^>]*(?:tabIndex|tabindex))`     # role=button sin tabindex
- `role=["'](?:button|link|checkbox|radio|switch|tab)["']`     # roles redundantes en elementos nativos
- `<(button|a|input)[^>]*role=`     # role en elemento que ya tiene rol implícito
- `<button[^>]*>\s*[×✕✖✗]\s*<\/button>`     # botón con solo símbolo (sin aria-label)
- `aria-(expanded|selected|checked|pressed|current)=`     # estados ARIA (esperados en custom)
- `<div[^>]*onClick(?![^>]*role=)`     # div clickable sin role
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

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

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/hooks/**`, `**/toast/**`, `**/notification/**`
**Patrones:**
- `aria-live=["'](polite|assertive)["']`     # regiones live (esperado)
- `role=["'](alert|status|log)["']`     # roles que implican aria-live
- `(toast|notify|notification|snackbar)`     # primitivas a auditar
- `(useAnnouncer|LiveRegion|live-region|sr-announcer)`     # patrones explícitos
- `aria-busy=`     # indicador de carga para AT
**Señal de N/A:** stack_signal.has_frontend == false || la UI no muestra cambios dinámicos al usuario (sin toasts, sin async).

**Verificar:**
- [ ] `aria-live="polite"` en regiones de feedback menor (toasts, cambio de conteo).
- [ ] `aria-live="assertive"` / `role="alert"` en errores críticos.
- [ ] `role="status"` para loading / saved.
- [ ] Los mensajes se inyectan al DOM después de estar listos (no en vacío).

---

## C. Patrones ARIA comunes

#### `A11Y-ARIA-001` — Modales y diálogos
**Severidad:** high · **Aplica a:** frontend

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/modals/**`, `**/dialogs/**`, `**/ui/**`
**Patrones:**
- `(<Modal|<Dialog|<AlertDialog|<Sheet|<Drawer)`     # componentes a auditar
- `role=["'](dialog|alertdialog)["']`     # role correcto
- `aria-modal=["']true["']`     # modal expuesto a AT
- `aria-labelledby=|aria-label=`     # nombre accesible (esperado)
- `(focusTrap|FocusLock|focus-trap)`     # focus trap
- `(inert|aria-hidden=["']true["'])`     # fondo inerte
**Señal de N/A:** stack_signal.has_frontend == false || la app no usa modales/dialogs.

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

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/ui/**`, `**/menus/**`
**Patrones:**
- `(DropdownMenu|Menu\b|<Menubar|<Popover|<Select)`     # componentes a auditar
- `aria-haspopup=["'](menu|true)["']`     # trigger correcto
- `aria-expanded=`     # estado del trigger
- `role=["'](menu|menubar|menuitem|menuitemcheckbox|menuitemradio)["']`     # roles
- `(ArrowUp|ArrowDown|ArrowLeft|ArrowRight)`     # navegación con flechas
- `aria-activedescendant=`     # alternativa a mover foco
**Señal de N/A:** stack_signal.has_frontend == false || la app no usa menús desplegables.

**Verificar:**
- [ ] Trigger con `aria-haspopup="menu"`, `aria-expanded`.
- [ ] `role="menu"` / `role="menubar"` con `role="menuitem"`.
- [ ] Navegación con flechas dentro; Tab sale del menú.
- [ ] Al abrir, foco se mueve al primer item (o se usa `aria-activedescendant`).

---

#### `A11Y-ARIA-003` — Tabs
**Severidad:** high · **Aplica a:** frontend

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/ui/**`, `**/tabs/**`
**Patrones:**
- `(Tabs|TabList|<Tab\b|TabPanel|<TabPanels)`     # componentes a auditar
- `role=["'](tablist|tab|tabpanel)["']`     # roles correctos
- `aria-selected=|aria-controls=|aria-labelledby=`     # asociación tab-panel
- `(ArrowLeft|ArrowRight|Home|End)`     # navegación de teclado esperada
- `tabIndex=\{?-1\}?|tabindex=["']-1["']`     # tabs no activos fuera del orden
**Señal de N/A:** stack_signal.has_frontend == false || la app no usa pestañas.

**Verificar:**
- [ ] `role="tablist"`, `role="tab"` (con `aria-selected`), `role="tabpanel"`.
- [ ] `aria-controls` desde tab a panel, `aria-labelledby` en panel.
- [ ] Flechas ← → para cambiar tab; Home/End.
- [ ] Una sola tab en el tab order (otras `tabindex="-1"`).

---

#### `A11Y-ARIA-004` — Accordion / Disclosure
**Severidad:** medium · **Aplica a:** frontend

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/ui/**`, `**/accordion/**`
**Patrones:**
- `(Accordion|Disclosure|Collapsible|<details>)`     # componentes a auditar
- `aria-expanded=`     # estado del trigger (esperado)
- `aria-controls=`     # asociación trigger-panel
- `<div[^>]*onClick[^>]*expand|<span[^>]*onClick[^>]*toggle`     # trigger no semántico
- `<button[^>]*aria-expanded`     # patrón correcto
**Señal de N/A:** stack_signal.has_frontend == false || la app no usa accordions/disclosures.

**Verificar:**
- [ ] Trigger es `<button>` con `aria-expanded`.
- [ ] `aria-controls` apunta al panel.
- [ ] Panel con `id` que lo haga referenciable.

---

#### `A11Y-ARIA-005` — Tooltips
**Severidad:** medium · **Aplica a:** frontend

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/ui/**`, `**/tooltips/**`
**Patrones:**
- `(<Tooltip|tooltip|@floating-ui|@radix-ui/react-tooltip|@reach/tooltip)`     # libs/componentes
- `role=["']tooltip["']`     # role correcto
- `aria-describedby=`     # asociación con el activador
- `(onMouseEnter|onHover)(?![\s\S]{0,200}onFocus)`     # tooltip solo por hover
- `key.*===?\s*['"]Escape['"]`     # cerrar con Esc
**Señal de N/A:** stack_signal.has_frontend == false || la UI no usa tooltips.

**Verificar:**
- [ ] Contenido no crítico (no esencial para completar la tarea).
- [ ] Aparece por hover Y focus; se mantiene al mover hacia el tooltip.
- [ ] Se cierra con Escape.
- [ ] `aria-describedby` desde el elemento activador.

---

#### `A11Y-ARIA-006` — Combobox y autocomplete
**Severidad:** medium · **Aplica a:** frontend

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/ui/**`, `**/forms/**`
**Patrones:**
- `(Combobox|Autocomplete|downshift|react-select|@headlessui/react.*Combobox|cmdk)`     # libs
- `role=["']combobox["']|role=["']listbox["']|role=["']option["']`     # roles ARIA
- `aria-autocomplete=["'](list|both|inline|none)["']`     # tipo
- `aria-expanded=|aria-controls=|aria-activedescendant=`     # estado y navegación
- `(ArrowUp|ArrowDown|Enter|Escape)`     # navegación de teclado
**Señal de N/A:** stack_signal.has_frontend == false || la UI no usa autocompletes/comboboxes.

**Verificar:**
- [ ] `role="combobox"` con `aria-expanded`, `aria-controls`, `aria-autocomplete`.
- [ ] Lista con `role="listbox"`, items con `role="option"`.
- [ ] Flechas navegan la lista sin mover foco (aria-activedescendant).
- [ ] Enter selecciona; Escape cierra.

---

#### `A11Y-ARIA-007` — Tree / Treegrid / Data grid
**Severidad:** medium · **Aplica a:** frontend

Componentes complejos siguen el patrón del Authoring Practices Guide.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/ui/**`, `**/grid/**`, `**/tree/**`
**Patrones:**
- `(TreeView|<Tree\b|TreeItem)`     # componentes tree
- `(DataGrid|<Grid\b|@?ag-grid|tan(stack)?-?table)`     # data grids
- `role=["'](tree|treeitem|grid|gridcell|treegrid|row|columnheader|rowheader)["']`     # roles
- `aria-(level|posinset|setsize|expanded|selected|busy)=`     # estados específicos
- `(ArrowUp|ArrowDown|Home|End|PageUp|PageDown)`     # navegación esperada
**Señal de N/A:** stack_signal.has_frontend == false || la UI no usa tree views ni data grids interactivas.

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

**Dónde buscar:** `package.json`, `pnpm-lock.yaml`, `**/.github/workflows/**`, `**/cypress/**`, `**/playwright/**`, `**/e2e/**`, `lighthouserc*`
**Patrones:**
- `(@axe-core|jest-axe|cypress-axe|@axe-core\/playwright|axe-playwright)`     # libs de a11y testing
- `(lighthouse|lighthouse-ci|@lhci\/cli)`     # Lighthouse CI
- `(pa11y|pa11y-ci)`     # alternativa
- `eslint-plugin-jsx-a11y`     # linter en pipeline
- `(a11y|accessibility)\.spec|\.test`     # tests dedicados
**Señal de N/A:** stack_signal.has_frontend == false (sin UI a auditar) o el proyecto declara explícitamente que la a11y se evalúa solo manualmente con justificación.

**Verificar:**
- [ ] Pipeline tiene tests automáticos de a11y.

---

#### `A11Y-TEST-002` — Testing manual con teclado y screen reader
**Severidad:** high · **Aplica a:** testing

Revisión humana regular con NVDA/JAWS/VoiceOver y navegación solo por teclado.

**Dónde buscar:** `**/docs/**`, `**/*.md`, `**/.github/**`, `**/CHANGELOG*`, `**/release-checklist*`
**Patrones:**
- *(sin patrones mecánicos — revisión manual del proceso/playbook con NVDA/VoiceOver y solo teclado)*
- `(NVDA|JAWS|VoiceOver|TalkBack|screen reader)`     # menciones del proceso en docs
- `(a11y.*audit|accessibility.*review|a11y.*checklist)`     # documentación del proceso
**Señal de N/A:** stack_signal.has_frontend == false (sin UI a auditar) o equipo dedicado de QA externo realiza la auditoría documentada.

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
