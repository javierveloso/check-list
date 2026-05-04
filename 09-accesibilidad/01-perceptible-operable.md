# 09 · Accesibilidad · Perceptible y operable (WCAG 2.2 AA)

> Controles de WCAG 2.2 principios **Perceptible** y **Operable**. Conformidad
> AA por defecto.
>
> **Marcos de referencia:** WCAG 2.2 AA (W3C) · ARIA Authoring Practices.

---

## A. Perceptible

#### `A11Y-PER-001` — Alternativas textuales para contenido no textual
**Severidad:** high · **Tags:** `wcag-1-1-1` · **Aplica a:** frontend

Imágenes, íconos, gráficos, audio y video tienen alternativa textual.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte,html}`, `**/components/**`, `**/pages/**`, `**/public/**`
**Patrones:**
- `<img(?![^>]*\salt=)`     # img sin alt
- `<svg(?![^>]*(?:aria-label|aria-labelledby|<title))`     # SVG sin nombre accesible
- `<(button|a)[^>]*>\s*<(svg|i\s|Icon)[^>]*>(?!.*aria-label)`     # botón/link icon-only sin aria-label
- `<(video|audio)(?![\s\S]*?<track)`     # media sin tracks/captions
- `aria-label=["']\s*["']`     # aria-label vacío
- `alt=["']image["']|alt=["']picture["']`     # alts inútiles
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] `<img alt="">` presente: descriptivo si aporta, vacío si decorativo.
- [ ] Íconos-sólo con `aria-label` o texto visually-hidden.
- [ ] SVG con `<title>` o `aria-labelledby`.
- [ ] Gráficos de datos con tabla/descripción alternativa.
- [ ] Audio/video con transcripción; video con captions y audiodescripción cuando aplique.

**Banderas rojas:**
- `<img>` sin `alt`.
- Botones que son solo un ícono sin `aria-label`.
- Imagen decorativa con `alt` duplicando texto contiguo.

---

#### `A11Y-PER-002` — Estructura semántica en el HTML
**Severidad:** high · **Tags:** `wcag-1-3-1` · **Aplica a:** frontend

El marcado usa elementos semánticos nativos (`<nav>`, `<main>`, `<header>`,
`<footer>`, `<h1>`-`<h6>`, `<article>`, `<section>`) correctamente.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte,html}`, `**/components/**`, `**/layouts/**`, `**/pages/**`
**Patrones:**
- `<div\s+role=["'](navigation|main|banner|contentinfo|complementary)`     # divs con role en vez de elemento nativo
- `<div[^>]*onClick`     # div clickable (debería ser button)
- `<(h[1-6])`     # presencia de headings (verificar jerarquía manual)
- `<ul[^>]*>\s*<div|<ol[^>]*>\s*<div`     # listas con div como item
- `<table[^>]*>(?![\s\S]*?<th)`     # tabla sin <th>
- `scope=["'](row|col|rowgroup|colgroup)["']`     # scope correcto en th
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Exactamente un `<h1>` por página principal.
- [ ] Jerarquía de headings no salta niveles (`<h1>` → `<h3>` sin `<h2>` = mal).
- [ ] Landmarks (`<nav>`, `<main>`, `<aside>`) correctamente usados.
- [ ] Listas con `<ul>`/`<ol>`/`<dl>`, no `<div>` con bullets CSS.
- [ ] Tablas con `<th>` y `scope` cuando son de datos.

---

#### `A11Y-PER-003` — Contraste de color suficiente
**Severidad:** high · **Tags:** `wcag-1-4-3` · **Aplica a:** frontend · design

Texto y elementos UI tienen contraste adecuado con su fondo.

**Dónde buscar:** `**/*.{css,scss,sass,less}`, `tailwind.config.*`, `**/*.{tsx,jsx,vue,svelte}`, `**/styles/**`, `**/theme/**`
**Patrones:**
- *(detección rigurosa requiere axe-core/lighthouse/pa11y; lo siguiente son heurísticas)*
- `color:\s*#([cdef]\w{2}|[cdef]{3})`     # texto muy claro (sospechoso sobre blanco)
- `color:\s*(gray|grey|silver|lightgray)`     # nombres genéricos claros
- `text-(gray|slate|zinc|neutral)-(100|200|300|400)`     # Tailwind grises bajos
- `placeholder.*(color|opacity).*0\.[0-4]`     # placeholders muy translúcidos
- `opacity:\s*0\.[1-4]`     # contenido translúcido
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Texto normal: 4.5:1 mínimo.
- [ ] Texto grande (18.66 px+ bold, 24 px+ regular): 3:1 mínimo.
- [ ] Componentes UI (bordes de botón, íconos informativos): 3:1.
- [ ] Focus indicators: 3:1 (WCAG 2.2 SC 2.4.11).
- [ ] Se verifica en dark mode también.

**Banderas rojas:**
- Gris sobre gris claro.
- Texto de marca sobre fondo de marca sin probar contraste.
- Placeholders demasiado claros confundidos con campo vacío deshabilitado.

---

#### `A11Y-PER-004` — Texto redimensionable hasta 200% sin pérdida
**Severidad:** medium · **Tags:** `wcag-1-4-4`, `wcag-1-4-10` · **Aplica a:** frontend

Al escalar texto a 200% o reflow a 320px, no se pierde contenido ni
funcionalidad.

**Dónde buscar:** `**/*.{css,scss,sass,less}`, `tailwind.config.*`, `**/*.{tsx,jsx,vue,svelte}`, `**/styles/**`
**Patrones:**
- `font-size:\s*\d+px`     # font-size absoluto
- `(width|height):\s*\d+px[^;]*;\s*overflow:\s*hidden`     # caja fija + overflow
- `line-height:\s*\d+px`     # line-height fijo
- `letter-spacing|word-spacing|line-height`     # presencia (cruzar con WCAG 1.4.12)
- `\b(rem|em)\b`     # uso de unidades relativas (esperado)
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Unidades relativas (rem/em) para texto.
- [ ] No hay dimensiones fijas que corten contenido al zoom.
- [ ] Reflow: sin scroll en dos direcciones a 320px.
- [ ] Espaciado adicional (WCAG 1.4.12) no rompe layout.

---

#### `A11Y-PER-005` — Color no es el único indicador
**Severidad:** high · **Tags:** `wcag-1-4-1` · **Aplica a:** frontend

Estados (error, éxito, requerido, seleccionado) se comunican con algo más que
solo color: ícono, texto, patrón.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte,css,scss}`, `**/components/**`, `**/forms/**`
**Patrones:**
- `(error|isError|hasError|isInvalid)`     # estado de error (debería traer texto/ícono)
- `(border-red|text-red|bg-red|color:\s*red)`     # uso de rojo (cruzar con texto/ícono)
- `(IconError|AlertCircle|XCircle|CheckCircle|IconSuccess)`     # íconos de estado
- `text-decoration:\s*none.*color:\s*(blue|#0)`     # links sin subrayado
- `aria-invalid|aria-required`     # estados expuestos a AT
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Campos con error: borde rojo + ícono + mensaje.
- [ ] Gráficos de categorías: color + patrón/forma diferentes.
- [ ] Links en el cuerpo del texto tienen subrayado (o muy alto contraste consistente).
- [ ] Estado "activo" de tabs con algo más que color.

**Banderas rojas:**
- Gráfico de líneas donde solo el color diferencia series.
- "Si está en rojo, es urgente" sin etiqueta.

---

#### `A11Y-PER-006` — Contenido no depende de orientación
**Severidad:** low · **Tags:** `wcag-1-3-4` · **Aplica a:** frontend

El contenido es utilizable tanto en portrait como landscape.

**Dónde buscar:** `**/*.{css,scss,sass,less}`, `**/styles/**`, `**/*.{html,tsx,jsx,vue,svelte}`, `**/manifest.{json,webmanifest}`
**Patrones:**
- `@media\s*\([^)]*orientation:\s*(portrait|landscape)`     # media queries por orientación
- `["']orientation["']\s*:\s*["'](portrait|landscape)["']`     # bloqueo en manifest PWA
- `screen\.orientation\.lock\(`     # bloqueo programático
- `transform:\s*rotate\((90|-90|180)deg\)`     # rotación forzada
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] El producto no bloquea la orientación (salvo caso justificado).
- [ ] Layout adapta a ambas orientaciones en mobile/tablet.

---

## B. Operable

#### `A11Y-OP-001` — Todo es operable con teclado
**Severidad:** critical · **Tags:** `wcag-2-1-1` · **Aplica a:** frontend

Cualquier acción que se puede hacer con mouse se puede hacer con teclado.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/pages/**`
**Patrones:**
- `<div[^>]*onClick(?![^>]*(?:role=|tabIndex|onKeyDown))`     # div clickable sin teclado
- `<span[^>]*onClick`     # span clickable
- `(onMouseDown|onMouseUp|onMouseEnter|onMouseLeave)(?![\s\S]{0,200}on(Key|Focus|Blur))`     # solo mouse
- `(onDragStart|onDrop)(?![\s\S]{0,500}(button|alternative))`     # drag sin alternativa
- `tabIndex=\{?["']?-1["']?\}?`     # exclusión del tab order (a veces correcto)
- `onKeyDown|onKeyUp|onKeyPress`     # presencia de teclado (esperado)
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Tab recorre elementos interactivos en orden lógico.
- [ ] Enter/Space activan botones y links.
- [ ] Arrows navegan dentro de componentes (tabs, menús, listbox).
- [ ] Escape cierra modales, menús, dropdowns.
- [ ] No hay interacciones solo drag-and-drop sin alternativa.

**Banderas rojas:**
- `<div onClick>` sin `role`/`tabindex` correctos.
- Widgets custom sin keyboard handling.

---

#### `A11Y-OP-002` — Focus visible y suficientemente claro
**Severidad:** critical · **Tags:** `wcag-2-4-7`, `wcag-2-4-11` · **Aplica a:** frontend

El elemento con foco se ve claramente en todo momento.

**Dónde buscar:** `**/*.{css,scss,sass,less}`, `**/styles/**`, `tailwind.config.*`, `**/*.{tsx,jsx,vue,svelte}`
**Patrones:**
- `outline:\s*(0|none)(?![\s\S]{0,200}:focus(?:-visible)?)`     # outline removido sin reemplazo
- `:focus-visible`     # presencia (recomendado)
- `:focus\s*\{[^}]*outline:\s*(0|none)`     # focus sin outline ni alternativa
- `(focus-ring|focus:ring|focus:outline)`     # utilidades Tailwind
- `\*\s*\{[^}]*outline:\s*(0|none)`     # reset global del outline
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Focus style ≠ outline removido sin reemplazo.
- [ ] Contraste ≥ 3:1 con fondo adyacente (WCAG 2.2 SC 2.4.11 Focus Appearance).
- [ ] Focus consistente en toda la app.
- [ ] `:focus-visible` usado para distinguir focus por teclado vs. click.

**Banderas rojas:**
- `outline: none` sin `:focus-visible` alternativo.
- Focus ring invisible en fondos oscuros.

---

#### `A11Y-OP-003` — Sin trampas de teclado
**Severidad:** critical · **Tags:** `wcag-2-1-2` · **Aplica a:** frontend

El usuario puede salir de cualquier componente con teclado solo.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/modals/**`, `**/dialogs/**`
**Patrones:**
- `(focus-trap|focusTrap|FocusLock|focus-trap-react)`     # libs de trap (debe haber salida)
- `(onClose|onDismiss|onEscape|onEsc)`     # handlers de salida
- `key\s*===?\s*['"]Escape['"]|event\.key\s*===?\s*['"]Escape['"]`     # tecla Esc
- `<iframe[^>]*(?!sandbox)`     # iframes pueden atrapar foco
- `(Modal|Dialog|Drawer|Sheet)\b`     # componentes que requieren trap correcto
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Modales: Tab cicla dentro, Escape cierra.
- [ ] Embeds (iframes, widgets) no atrapan el foco.
- [ ] Menús y dropdowns se cierran con Escape y devuelven foco al disparador.

---

#### `A11Y-OP-004` — Skip links para navegación repetitiva
**Severidad:** medium · **Tags:** `wcag-2-4-1` · **Aplica a:** frontend

El usuario puede saltar directamente al contenido principal.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte,html}`, `**/layouts/**`, `**/components/**`, `**/app/**`
**Patrones:**
- `(SkipLink|SkipNav|SkipToContent|skip-link|skip-to-main)`     # componentes/clases skip
- `href=["']#main|href=["']#content`     # link clásico al main
- `<main[^>]*\sid=`     # main con id (target del skip)
- `(sr-only|visually-hidden|focus:not-sr-only)`     # patrón visualmente oculto + visible al focus
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] "Skip to main content" como primer elemento focuseable.
- [ ] Visible al recibir foco.
- [ ] Funciona (el foco realmente va al `<main>`).

---

#### `A11Y-OP-005` — Orden de tab lógico y predecible
**Severidad:** high · **Tags:** `wcag-2-4-3` · **Aplica a:** frontend

El orden de foco sigue el orden visual.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte,html}`, `**/components/**`, `**/*.{css,scss,sass,less}`
**Patrones:**
- `tabindex=["']?[2-9]\d*["']?|tabIndex=\{?[2-9]`     # tabindex > 1 (anti-patrón)
- `tabindex=["']?1["']?|tabIndex=\{?1\b`     # tabindex=1 (también desordena)
- `(order:\s*-?\d|flex-order|order-[0-9])`     # CSS order rompe orden visual vs DOM
- `(grid-area|grid-column-start|grid-row-start)`     # grid puede reordenar visualmente
- `display:\s*(none|hidden)`     # contenido oculto (no debe recibir foco)
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Orden de tab coincide con lectura (izq→der, arr→aba).
- [ ] No se usa `tabindex > 0` (desordena).
- [ ] Contenido oculto no recibe foco (ej: menú colapsado).

---

#### `A11Y-OP-006` — Tiempo suficiente / desactivable
**Severidad:** medium · **Tags:** `wcag-2-2-1` · **Aplica a:** frontend

Si hay timeouts/sesiones/carouseles, el usuario puede pausar, extender o
desactivar.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/auth/**`, `**/hooks/**`
**Patrones:**
- `setTimeout\(.*,\s*\d{4,}\)|setInterval\(`     # timers (verificar si pausables)
- `(autoPlay|autoplay|auto-play|autoAdvance)`     # auto-avance en carousels
- `(SessionTimeout|sessionExpiry|idleTimer|useIdleTimeout)`     # timeouts de sesión
- `(Carousel|Swiper|Slider|EmblaCarousel)`     # componentes a auditar
- `(pause|onPause|isPaused|stopAutoplay)`     # controles de pausa
- `meta http-equiv=["']refresh["']`     # redirect automático
**Señal de N/A:** stack_signal.has_frontend == false || el producto no tiene timeouts, carousels ni redirects automáticos visibles al usuario.

**Verificar:**
- [ ] Sesiones que expiran tienen aviso y opción de extender.
- [ ] Carousels/sliders pausables; no se auto-avanzan en contenido con texto.
- [ ] Redirects con countdown pausables.

---

#### `A11Y-OP-007` — Sin parpadeos peligrosos
**Severidad:** critical · **Tags:** `wcag-2-3-1` · **Aplica a:** frontend

Nada parpadea más de 3 veces por segundo (riesgo de fotosensibilidad).

**Dónde buscar:** `**/*.{css,scss,sass,less}`, `**/styles/**`, `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`
**Patrones:**
- `animation-duration:\s*(0?\.[0-2]\d*|[1-2]\d{0,2})ms\b`     # < 333ms (riesgo > 3Hz)
- `@keyframes\s+\w*(blink|flash|strobe)`     # animaciones de parpadeo
- `prefers-reduced-motion`     # respeto a preferencia (esperado)
- `(motion-safe|motion-reduce)`     # utilidades Tailwind
- `infinite\b`     # animaciones infinitas (auditar frecuencia)
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] Animaciones no parpadeantes > 3 Hz.
- [ ] `prefers-reduced-motion` reduce o elimina animaciones.

---

#### `A11Y-OP-008` — Gestos complejos tienen alternativa simple
**Severidad:** medium · **Tags:** `wcag-2-5-1` · **Aplica a:** frontend

Toda acción que usa gesto multitouch o path complejo tiene alternativa con
un solo punto.

**Dónde buscar:** `**/*.{tsx,jsx,vue,svelte}`, `**/components/**`, `**/hooks/**`
**Patrones:**
- `(onSwipe|onPinch|onRotate|swipeable|useSwipeable)`     # gestos
- `(react-use-gesture|@use-gesture|hammer\.js)`     # libs de gestos
- `(touch-action|touchstart|touchmove|touchend)`     # eventos táctiles
- `(onPan|onDrag).*(?!button|alternative)`     # gestos sin alternativa explícita
- `Map\b|Leaflet|Mapbox|Google Maps`     # mapas (típicos casos a auditar)
**Señal de N/A:** stack_signal.has_frontend == false || el producto no usa gestos multitouch ni interacciones por path.

**Verificar:**
- [ ] Swipe → también botón/tap.
- [ ] Pinch zoom → también controles + / -.

---

#### `A11Y-OP-009` — Touch targets adecuados
**Severidad:** medium · **Tags:** `wcag-2-5-5`, `wcag-2-5-8` · **Aplica a:** frontend

Objetivos táctiles tienen tamaño suficiente (≥ 24×24 CSS px es el mínimo WCAG
2.2; 44×44 recomendado).

(Ver también `UX-RESP-002`.)

**Dónde buscar:** `**/*.{css,scss,sass,less}`, `**/*.{tsx,jsx,vue,svelte}`, `tailwind.config.*`, `**/components/**`
**Patrones:**
- `(width|height):\s*([1-9]|1\d|2[0-3])px\b`     # < 24px (debajo del mínimo WCAG 2.5.8)
- `(h-|w-)([1-5])\b`     # Tailwind h-1..h-5 (≤ 20px)
- `padding:\s*0(px)?\b`     # sin padding (suele dar targets muy pequeños)
- `gap-(0|0\.5|1)\b`     # gaps muy pequeños entre targets
- `<a[^>]*>\s*<svg|<button[^>]*>\s*<svg`     # icon-only (alto riesgo)
**Señal de N/A:** stack_signal.has_frontend == false (no hay archivos en `**/*.{tsx,jsx,vue,svelte}` ni `**/public/index.html`).

**Verificar:**
- [ ] WCAG 2.2 SC 2.5.8: target ≥ 24×24 o espaciado suficiente.
- [ ] Excepciones documentadas (texto en párrafo).

---

## Checklist resumen

| ID             | Control                                               | Severidad |
| -------------- | ----------------------------------------------------- | --------- |
| A11Y-PER-001   | Alt text para no-textual                              | high      |
| A11Y-PER-002   | Estructura semántica                                  | high      |
| A11Y-PER-003   | Contraste suficiente                                  | high      |
| A11Y-PER-004   | Texto redimensionable 200%                            | medium    |
| A11Y-PER-005   | Color no es el único indicador                        | high      |
| A11Y-PER-006   | Independencia de orientación                          | low       |
| A11Y-OP-001    | Operable con teclado                                  | critical  |
| A11Y-OP-002    | Focus visible                                         | critical  |
| A11Y-OP-003    | Sin trampas de teclado                                | critical  |
| A11Y-OP-004    | Skip links                                            | medium    |
| A11Y-OP-005    | Orden de tab lógico                                   | high      |
| A11Y-OP-006    | Tiempos desactivables                                 | medium    |
| A11Y-OP-007    | Sin parpadeos peligrosos                              | critical  |
| A11Y-OP-008    | Alternativa a gestos complejos                        | medium    |
| A11Y-OP-009    | Touch targets adecuados                               | medium    |
