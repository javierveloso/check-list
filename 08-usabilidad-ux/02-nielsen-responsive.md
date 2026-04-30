# 08 · Usabilidad · Heurísticas de Nielsen y responsive

> Las 10 heurísticas de Nielsen aplicadas al producto, responsive design y
> mobile.
>
> **Marcos de referencia:** Nielsen Norman Group · Responsive web design (E. Marcotte) · Mobile First (L. Wroblewski).

---

## A. Aplicación de las 10 heurísticas

> Algunas se cruzan con `01-feedback-estados.md`. Aquí se cubren las restantes.

#### `UX-HEUR-002` — Match con el mundo real y el usuario
**Severidad:** medium · **Tags:** `nielsen-2` · **Aplica a:** frontend · content

El lenguaje, conceptos e íconos son los que usa el usuario target — no jerga
interna del equipo.

**Verificar:**
- [ ] Terminología del dominio del usuario (no nombres técnicos internos).
- [ ] Íconos reconocibles (cesta, lupa, engranaje).
- [ ] Fechas en formato local (DD/MM/YYYY en LatAm/Europa, MM/DD/YYYY en EE. UU., etc.).
- [ ] Números y monedas con separadores locales.
- [ ] Orden de lectura respeta la cultura (LTR / RTL si aplica).

**Banderas rojas:**
- "Kafka topic", "WAL replay" en UI de producto.
- Fechas `yyyy-mm-ddTHH:MM:SSZ` mostradas al usuario.

---

#### `UX-HEUR-006` — Reconocer, no recordar
**Severidad:** medium · **Tags:** `nielsen-6` · **Aplica a:** frontend

El usuario no tiene que memorizar cosas entre pantallas; las opciones están
visibles o son recuperables.

**Verificar:**
- [ ] Opciones relevantes visibles (vs escondidas en menús hamburguesa cuando no es móvil).
- [ ] Historial reciente / sugerencias autocompletan.
- [ ] Filtros activos visibles con opción de removerlos individualmente.
- [ ] Breadcrumbs donde ayuden.
- [ ] Tooltips en íconos ambiguos.

---

#### `UX-HEUR-007` — Flexibilidad y eficiencia
**Severidad:** medium · **Tags:** `nielsen-7` · **Aplica a:** frontend

Usuarios nuevos pueden usar el sistema; usuarios expertos tienen atajos.

**Verificar:**
- [ ] Atajos de teclado documentados (modal `?`, menús con atajos visibles).
- [ ] Acciones masivas para power users (select all, bulk edit).
- [ ] Búsqueda/comando global cuando aporta (⌘K pattern).
- [ ] Modo "pro" opcional si el producto lo justifica.

---

#### `UX-HEUR-008` — Estética y diseño minimalista
**Severidad:** medium · **Tags:** `nielsen-8` · **Aplica a:** frontend

Cada elemento compite por atención; lo raramente necesario no vive en pantalla
principal.

**Verificar:**
- [ ] Interfaz sin elementos decorativos que no aporten.
- [ ] Jerarquía visual clara (titulos, subtítulos, espacios).
- [ ] Paleta y tipografía con propósito.
- [ ] No hay "wall of text" sin estructura.

---

#### `UX-HEUR-010` — Ayuda y documentación accesibles
**Severidad:** medium · **Tags:** `nielsen-10` · **Aplica a:** frontend · content

Ayuda contextual donde ocurre la acción, y docs completas accesibles.

**Verificar:**
- [ ] Tooltips/hints donde hay concepto ambiguo.
- [ ] Help center / docs linkable desde el producto.
- [ ] Onboarding para nuevas features clave.
- [ ] FAQ para errores comunes.

---

## B. Responsive design

#### `UX-RESP-001` — Breakpoints estándar y testeados
**Severidad:** high · **Aplica a:** frontend

El layout funciona en móvil, tablet y desktop.

**Verificar:**
- [ ] Funciona bien en ~320px (móvil chico), ~768px (tablet), ~1024px, ~1280px+.
- [ ] Los breakpoints están definidos y son consistentes con el design system.
- [ ] Se prueba en dispositivos reales o emulación realista.
- [ ] No hay scroll horizontal inesperado (salvo tablas muy anchas con scroll interno).

**Banderas rojas:**
- Site que se rompe a menos de 1024 px.
- Botones encima del teclado virtual en móvil.

---

#### `UX-RESP-002` — Touch targets cómodos en móvil
**Severidad:** high · **Tags:** `a11y`, `wcag-2-5-5` · **Aplica a:** frontend

Elementos táctiles de al menos 44×44 px (Apple HIG) o 48×48 (Material) y
separados entre sí.

**Verificar:**
- [ ] Botones/links/inputs ≥ 44×44 px en móvil.
- [ ] Espaciado mínimo entre targets táctiles.
- [ ] No hay áreas donde el usuario acierte al vecino por error.

(Ver `A11Y-KBD-002`.)

---

#### `UX-RESP-003` — Imágenes y media responsivos
**Severidad:** medium · **Aplica a:** frontend

Las imágenes se adaptan al ancho; videos tienen aspect ratio preservado.

**Verificar:**
- [ ] `max-width: 100%` + `height: auto` en imágenes.
- [ ] `<video>` con aspect ratio fijo para evitar layout shift.
- [ ] Diferentes resoluciones (`srcset`) según viewport.

---

#### `UX-RESP-004` — Tablas y layouts complejos en mobile
**Severidad:** medium · **Aplica a:** frontend

Las tablas anchas no rompen el layout: se colapsan en cards, o scroll
horizontal interno.

**Verificar:**
- [ ] Tablas con scroll horizontal interno bien visible.
- [ ] Alternativa mobile: card view.
- [ ] No se fuerza zoom out para leer contenido.

---

#### `UX-RESP-005` — Navegación en mobile accesible
**Severidad:** high · **Aplica a:** frontend

El menú hamburguesa funciona correctamente; se cierra al seleccionar; es
accesible por teclado y screen reader.

**Verificar:**
- [ ] Hamburger menu accesible (atributos `aria-expanded`, `aria-controls`).
- [ ] Tap fuera lo cierra.
- [ ] Contenido no queda bloqueado al usuario de screen reader.
- [ ] Navegación principal no requiere muchos taps.

(Cross con `A11Y-OP-001`.)

---

#### `UX-RESP-006` — Teclado virtual no oculta contenido
**Severidad:** high · **Aplica a:** frontend

Cuando el teclado aparece, el foco queda visible y el usuario puede enviar el
formulario.

**Verificar:**
- [ ] Scroll automático al campo activo.
- [ ] Botón de submit no queda detrás del teclado.
- [ ] `inputmode` / `type` apropiado para mostrar teclado correcto (email, numeric, tel).

---

#### `UX-RESP-007` — Viewport meta tag correcto
**Severidad:** high · **Tags:** `mobile`, `viewport` · **Aplica a:** frontend

El documento HTML declara el viewport correcto y no bloquea el zoom del usuario.

**Verificar:**
- [ ] `<meta name="viewport" content="width=device-width, initial-scale=1">` presente en el `<head>`.
- [ ] No se usa `user-scalable=no` ni `maximum-scale=1` (bloquea el zoom de accesibilidad — incumple WCAG 1.4.4).
- [ ] No hay `initial-scale` distinto de `1` sin justificación documentada.
- [ ] En frameworks (Next.js, Vite), el meta se genera en el layout raíz y no es sobreescrito por páginas hijas.

**Banderas rojas:**
- Ausencia del meta viewport → iOS y Android renderizan la versión desktop a escala reducida y la experiencia táctil se rompe.
- `user-scalable=no` → bloquea el zoom para usuarios con baja visión; además viola WCAG 1.4.4 (Success Criterion AA).

---

#### `UX-RESP-008` — Overflow horizontal controlado
**Severidad:** medium · **Tags:** `css`, `layout` · **Aplica a:** frontend

No hay scroll horizontal inesperado en ningún breakpoint. El `overflow: hidden`
global no se usa como parche para ocultar elementos que se escapan del viewport.

**Verificar:**
- [ ] No hay `overflow-x: hidden` en `body` o `html` como solución a un bug de layout.
- [ ] Se verifica en DevTools desactivando temporalmente `overflow: hidden` para encontrar los elementos que sobresalen.
- [ ] Scroll horizontal solo aparece en contenedores intencionados (tablas anchas, code blocks, carousels con overflow explícito).
- [ ] Elementos con anchos fijos en `px` se revisan en resoluciones < 375 px.

**Banderas rojas:**
- `body { overflow-x: hidden }` en el CSS global — enmascara bugs; en iOS puede generar un segundo scroll fantasma.
- Contenedores con `width` fijo en px que sobresalen del viewport en pantallas pequeñas.
- Margen o padding negativo que desplaza elementos fuera del viewport.

---

#### `UX-RESP-009` — Zoom y escalado de texto (WCAG 1.4.4)
**Severidad:** high · **Tags:** `wcag-1-4-4`, `a11y` · **Aplica a:** frontend

El contenido es funcional con el zoom del navegador al 200 % sin scroll horizontal
ni pérdida de funcionalidad (obligatorio WCAG 2.2 AA).

**Verificar:**
- [ ] La interfaz es usable con zoom al 200 % (salvo mapas, diagramas y contenido gráfico complejo, que tienen excepción WCAG).
- [ ] Los tamaños de fuente usan unidades relativas (`rem`, `em`) en lugar de `px` fijo.
- [ ] Los contenedores de texto no tienen `height` fijo que corte el contenido al aumentar el tamaño de fuente.
- [ ] Los breakpoints siguen activándose correctamente al hacer zoom (media queries responden al viewport lógico, no al físico).
- [ ] Se prueba con `Ctrl/⌘ +` en Chrome/Firefox hasta 200 %.

**Banderas rojas:**
- Font sizes definidos con `px` fijo que ignoran la preferencia de tamaño de fuente del sistema operativo.
- `height: 40px` en un botón o contenedor de texto que trunca el contenido al aumentar la fuente.
- Texto cortado con `overflow: hidden` sin `min-height` que se adapte.

**Referencias:** WCAG 2.2 SC 1.4.4 — Resize Text (AA).

---

#### `UX-RESP-010` — Dark mode y `prefers-color-scheme`
**Severidad:** medium · **Tags:** `css`, `prefers-color-scheme` · **Aplica a:** frontend

Si el sistema operativo del usuario está en dark mode, la aplicación responde
con colores adecuados, o declara explícitamente que solo soporta light mode.

**Verificar:**
- [ ] Se probó la app con `prefers-color-scheme: dark` activado (DevTools → Rendering → Emulate).
- [ ] Si no se implementa dark mode, se declara `<meta name="color-scheme" content="light">` para que el navegador no aplique estilos del sistema a inputs y scrollbars.
- [ ] Colores hardcodeados (`#fff`, `#000`, `rgb(255,255,255)`) se revisaron en ambos modos.
- [ ] Si se implementa dark mode: el contraste cumple WCAG AA (≥ 4.5:1 para texto normal) en ambos temas.
- [ ] Si hay toggle de tema en la UI: el estado se persiste en `localStorage` / cookie y sobrevive a recarga.

**Banderas rojas:**
- Texto oscuro sobre fondo claro hardcodeado que queda ilegible cuando el OS aplica dark mode al `<body>`.
- Imágenes PNG/JPG con fondo blanco que contrastan mal sobre fondos oscuros.
- Colores de borde o placeholder que desaparecen en dark mode por bajo contraste.

---

## C. Copy e internacionalización

#### `UX-COPY-001` — Tono y voz consistentes
**Severidad:** low · **Aplica a:** content · frontend

El tono del producto es consistente (formal vs. cercano, serio vs. juguetón)
y adecuado al dominio.

**Verificar:**
- [ ] Guía de voz y tono documentada.
- [ ] Traducciones mantienen el tono.
- [ ] Errores y mensajes no contradicen el tono general (ej: tono casual y de repente "El sistema rechazó su solicitud por violación de políticas").

---

#### `UX-COPY-002` — Internacionalización técnica
**Severidad:** medium · **Aplica a:** frontend · backend

Los textos se extraen a archivos de traducción; el código no concatena.

**Verificar:**
- [ ] Framework i18n en uso (i18next, FormatJS, Django i18n).
- [ ] Plurales, géneros, interpolación manejados con librería.
- [ ] Fechas y números con `Intl.*` o equivalente del backend.
- [ ] RTL soportado si aplica.

**Banderas rojas:**
- Textos hardcodeados en componentes.
- Concatenación tipo `"You have " + count + " messages"` sin pluralización.

---

## D. Estado vacío y onboarding

#### `UX-STATE-001` — Onboarding mínimo para usuarios nuevos
**Severidad:** medium · **Aplica a:** frontend

El usuario nuevo entiende qué hacer primero.

**Verificar:**
- [ ] Primera pantalla no asume contexto previo.
- [ ] Tour interactivo o tooltips explican lo esencial.
- [ ] El usuario puede saltarlo.
- [ ] Estados vacíos tienen ejemplos o CTAs ("crear tu primer proyecto").

---

#### `UX-STATE-002` — Progresión visible hacia completar tareas
**Severidad:** low · **Aplica a:** frontend

En flujos de varios pasos (onboarding, checkout), el usuario ve cuántos pasos
quedan.

**Verificar:**
- [ ] Stepper/progress bar visible.
- [ ] Paso actual destacado.
- [ ] Posibilidad de retroceder (salvo casos irreversibles).

---

## Checklist resumen

| ID                | Control                                              | Severidad |
| ----------------- | ---------------------------------------------------- | --------- |
| UX-HEUR-002       | Match con el mundo real                              | medium    |
| UX-HEUR-006       | Reconocer, no recordar                               | medium    |
| UX-HEUR-007       | Flexibilidad y eficiencia                            | medium    |
| UX-HEUR-008       | Estética minimalista                                 | medium    |
| UX-HEUR-010       | Ayuda accesible                                      | medium    |
| UX-RESP-001       | Breakpoints estándar                                 | high      |
| UX-RESP-002       | Touch targets cómodos                                | high      |
| UX-RESP-003       | Imágenes responsivas                                 | medium    |
| UX-RESP-004       | Tablas/layouts en mobile                             | medium    |
| UX-RESP-005       | Navegación mobile accesible                          | high      |
| UX-RESP-006       | Teclado virtual                                      | high      |
| UX-RESP-007       | Viewport meta tag correcto                           | high      |
| UX-RESP-008       | Overflow horizontal controlado                       | medium    |
| UX-RESP-009       | Zoom y escalado de texto (WCAG 1.4.4)                | high      |
| UX-RESP-010       | Dark mode / prefers-color-scheme                     | medium    |
| UX-COPY-001       | Tono consistente                                     | low       |
| UX-COPY-002       | i18n técnica                                         | medium    |
| UX-STATE-001      | Onboarding mínimo                                    | medium    |
| UX-STATE-002      | Progresión visible                                   | low       |
