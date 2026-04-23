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
| UX-COPY-001       | Tono consistente                                     | low       |
| UX-COPY-002       | i18n técnica                                         | medium    |
| UX-STATE-001      | Onboarding mínimo                                    | medium    |
| UX-STATE-002      | Progresión visible                                   | low       |
