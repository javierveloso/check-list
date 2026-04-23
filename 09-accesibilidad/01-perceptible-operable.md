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

**Verificar:**
- [ ] El producto no bloquea la orientación (salvo caso justificado).
- [ ] Layout adapta a ambas orientaciones en mobile/tablet.

---

## B. Operable

#### `A11Y-OP-001` — Todo es operable con teclado
**Severidad:** critical · **Tags:** `wcag-2-1-1` · **Aplica a:** frontend

Cualquier acción que se puede hacer con mouse se puede hacer con teclado.

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

**Verificar:**
- [ ] Modales: Tab cicla dentro, Escape cierra.
- [ ] Embeds (iframes, widgets) no atrapan el foco.
- [ ] Menús y dropdowns se cierran con Escape y devuelven foco al disparador.

---

#### `A11Y-OP-004` — Skip links para navegación repetitiva
**Severidad:** medium · **Tags:** `wcag-2-4-1` · **Aplica a:** frontend

El usuario puede saltar directamente al contenido principal.

**Verificar:**
- [ ] "Skip to main content" como primer elemento focuseable.
- [ ] Visible al recibir foco.
- [ ] Funciona (el foco realmente va al `<main>`).

---

#### `A11Y-OP-005` — Orden de tab lógico y predecible
**Severidad:** high · **Tags:** `wcag-2-4-3` · **Aplica a:** frontend

El orden de foco sigue el orden visual.

**Verificar:**
- [ ] Orden de tab coincide con lectura (izq→der, arr→aba).
- [ ] No se usa `tabindex > 0` (desordena).
- [ ] Contenido oculto no recibe foco (ej: menú colapsado).

---

#### `A11Y-OP-006` — Tiempo suficiente / desactivable
**Severidad:** medium · **Tags:** `wcag-2-2-1` · **Aplica a:** frontend

Si hay timeouts/sesiones/carouseles, el usuario puede pausar, extender o
desactivar.

**Verificar:**
- [ ] Sesiones que expiran tienen aviso y opción de extender.
- [ ] Carousels/sliders pausables; no se auto-avanzan en contenido con texto.
- [ ] Redirects con countdown pausables.

---

#### `A11Y-OP-007` — Sin parpadeos peligrosos
**Severidad:** critical · **Tags:** `wcag-2-3-1` · **Aplica a:** frontend

Nada parpadea más de 3 veces por segundo (riesgo de fotosensibilidad).

**Verificar:**
- [ ] Animaciones no parpadeantes > 3 Hz.
- [ ] `prefers-reduced-motion` reduce o elimina animaciones.

---

#### `A11Y-OP-008` — Gestos complejos tienen alternativa simple
**Severidad:** medium · **Tags:** `wcag-2-5-1` · **Aplica a:** frontend

Toda acción que usa gesto multitouch o path complejo tiene alternativa con
un solo punto.

**Verificar:**
- [ ] Swipe → también botón/tap.
- [ ] Pinch zoom → también controles + / -.

---

#### `A11Y-OP-009` — Touch targets adecuados
**Severidad:** medium · **Tags:** `wcag-2-5-5`, `wcag-2-5-8` · **Aplica a:** frontend

Objetivos táctiles tienen tamaño suficiente (≥ 24×24 CSS px es el mínimo WCAG
2.2; 44×44 recomendado).

(Ver también `UX-RESP-002`.)

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
