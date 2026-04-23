# 08 · Usabilidad · Feedback y estados de UI

> Feedback visible, loading/empty/error states, consistencia, prevención de
> errores y recuperación.
>
> **Marcos de referencia:** 10 heurísticas de Nielsen · Shneiderman's Golden Rules · Material Design / Apple HIG.

---

## A. Visibilidad del estado del sistema

#### `UX-FEED-001` — El usuario siempre sabe qué está pasando
**Severidad:** high · **Tags:** `nielsen-1` · **Aplica a:** frontend

Toda acción tiene feedback inmediato (≤ 100 ms) y si toma tiempo, muestra
progreso.

**Verificar:**
- [ ] Click en botón → indicación visual inmediata (ripple, pressed state, loading).
- [ ] Operaciones > 1 s muestran spinner/progress bar.
- [ ] Operaciones > 10 s muestran progreso incremental o estimación.
- [ ] Estado actual visible (página actual, filtros aplicados, tab seleccionado).

**Banderas rojas:**
- Click que no se siente si tarda.
- Pantalla en blanco mientras carga sin skeleton ni spinner.

---

#### `UX-FEED-002` — Estados distintos visualmente
**Severidad:** medium · **Aplica a:** frontend

Empty, loading, error, success, partial — cada estado tiene su propia UI.

**Verificar:**
- [ ] **Loading**: skeleton o spinner consistente.
- [ ] **Empty**: mensaje explicativo + CTA ("No hay resultados. Ajusta filtros o crea uno nuevo").
- [ ] **Error**: mensaje claro + acción de recuperación ("Reintentar").
- [ ] **Partial**: indica que falta cargar más.
- [ ] **Success**: confirmación visual (toast, mensaje, animación).

**Banderas rojas:**
- Lista vacía sin mensaje — parece roto.
- Error con stack trace.

---

#### `UX-FEED-003` — Transiciones suaves entre estados
**Severidad:** low · **Aplica a:** frontend

Los cambios de estado no son bruscos; evitan layout shift y desconcierto.

**Verificar:**
- [ ] Skeleton → contenido con la misma estructura, sin saltos (ver `PERF-FE-003`).
- [ ] Animaciones cortas (< 300 ms) y con `prefers-reduced-motion` respetado.
- [ ] Fade in/out en modales y popups.

---

## B. Feedback específico

#### `UX-FEED-010` — Confirmaciones claras para acciones destructivas
**Severidad:** high · **Aplica a:** frontend

Borrar, archivar masivamente, enviar a producción — se confirma antes.

**Verificar:**
- [ ] Modal o diálogo de confirmación.
- [ ] El texto refiere el recurso exacto a afectar ("Eliminar `Proyecto X`").
- [ ] El botón destructivo tiene color distinto (rojo) y está a la derecha.
- [ ] Para acciones muy críticas, se pide escribir el nombre del recurso (GitHub delete repo pattern).

---

#### `UX-FEED-011` — Undo cuando sea posible
**Severidad:** medium · **Tags:** `nielsen-3` · **Aplica a:** frontend

En acciones reversibles, se ofrece deshacer por X segundos (Gmail pattern).

**Verificar:**
- [ ] Toast con "Deshacer" para acciones como archivar, mover, eliminar-to-trash.
- [ ] Ventana de 5-30 segundos.
- [ ] El backend soporta el undo (o pospone la acción real).

---

#### `UX-FEED-012` — Auto-save + indicador
**Severidad:** medium · **Aplica a:** frontend

Cuando los cambios se guardan automáticamente, el usuario lo ve.

**Verificar:**
- [ ] Indicador "Guardando…" / "Guardado" con timestamp.
- [ ] Conflict resolution explícita si dos cambios concurren.
- [ ] Offline: cola de cambios locales y reintento al reconectar.

---

## C. Manejo de errores

#### `UX-FEED-020` — Mensajes de error útiles y humanos
**Severidad:** high · **Tags:** `nielsen-9` · **Aplica a:** frontend · backend

Los errores explican qué pasó, por qué, y cómo resolverlo; sin jerga técnica.

**Verificar:**
- [ ] Sin códigos crípticos solos ("Error E23X").
- [ ] Ejemplo bueno: "No se pudo enviar el mensaje. Revisa tu conexión e intenta otra vez".
- [ ] Si hay un código, va acompañado de texto legible y, si aplica, link a ayuda.
- [ ] Los errores de validación indican qué corregir y dónde.
- [ ] Stack traces solo en dev, nunca en producción al usuario.

---

#### `UX-FEED-021` — Recuperación asistida
**Severidad:** medium · **Aplica a:** frontend

El usuario puede reintentar, corregir o cancelar sin empezar de cero.

**Verificar:**
- [ ] Botón "Reintentar" en errores de red.
- [ ] Formularios preservan los datos cuando hay error.
- [ ] Links/botones para acciones alternativas ("Volver a la lista", "Contactar soporte").

---

## D. Consistencia y convención

#### `UX-CONSIST-001` — Mismo elemento → misma apariencia y comportamiento
**Severidad:** medium · **Tags:** `nielsen-4` · **Aplica a:** frontend

Botones, inputs, íconos, patrones se ven y se comportan igual en toda la app.

**Verificar:**
- [ ] Design system / component library en uso consistente.
- [ ] Colores tienen significado estable (rojo = destructivo, verde = éxito).
- [ ] Íconos reconocibles, no ambiguos.
- [ ] La misma acción vive en el mismo lugar (guardar en la esquina sup der, etc.).

---

#### `UX-CONSIST-002` — Navegación estable
**Severidad:** medium · **Aplica a:** frontend

La ubicación de la navegación principal es fija; los usuarios no se pierden.

**Verificar:**
- [ ] Nav principal visible o accesible en todo momento.
- [ ] Breadcrumbs en estructuras anidadas.
- [ ] URL refleja el estado; usuarios pueden copiar/pegar y guardar favoritos.
- [ ] Botón atrás del navegador funciona como se espera.

---

#### `UX-CONSIST-003` — Convenciones del SO y navegador respetadas
**Severidad:** low · **Aplica a:** frontend

Atajos, gestos y convenciones nativas funcionan cuando tiene sentido (⌘+S para
guardar, drag & drop donde se espera).

**Verificar:**
- [ ] Formularios respetan `Enter` para enviar, `Esc` para cerrar modales.
- [ ] Scroll, zoom, selección de texto no están rotos sin razón.
- [ ] Copiar/pegar funciona.

---

## E. Prevención de errores

#### `UX-PREV-001` — Validación temprana en formularios
**Severidad:** medium · **Tags:** `nielsen-5` · **Aplica a:** frontend

El error se detecta antes de enviar: on blur o on change, no solo on submit.

**Verificar:**
- [ ] Email/teléfono/RUT validan formato localmente.
- [ ] Campos obligatorios marcados visualmente.
- [ ] Errores aparecen junto al campo, no al final.
- [ ] Botón de envío deshabilitado o claro feedback si faltan campos.

---

#### `UX-PREV-002` — Valores razonables por defecto
**Severidad:** low · **Aplica a:** frontend

Los formularios tienen defaults que reducen el trabajo del usuario.

**Verificar:**
- [ ] Fechas prefilled cuando se puede inferir.
- [ ] Unidad monetaria local, idioma, país según el contexto.
- [ ] Selects con la opción más común preseleccionada (cuando aporta).

---

#### `UX-PREV-003` — Input masks para formatos complejos
**Severidad:** low · **Aplica a:** frontend

Campos con formato específico guían al usuario mientras escribe.

**Verificar:**
- [ ] Teléfonos, RUT/NIF/CPF, tarjetas de crédito usan máscara.
- [ ] La máscara no bloquea pegado (accepta variantes comunes).
- [ ] Hay hint ("Formato: 12.345.678-9").

---

## F. Percepción de rendimiento

#### `UX-PERF-001` — Skeleton screens en vez de spinners en cargas previsibles
**Severidad:** low · **Aplica a:** frontend

Cuando la estructura de la pantalla es conocida, un skeleton reduce la
percepción de espera.

**Verificar:**
- [ ] Listas y dashboards con skeleton placeholder.
- [ ] El skeleton se parece al layout final (no rectángulos genéricos).
- [ ] Loading en operación no-estructurada usa spinner.

---

#### `UX-PERF-002` — Optimistic UI cuando el riesgo es bajo
**Severidad:** low · **Aplica a:** frontend

Cambios pequeños (like, favorite, reorden) se reflejan inmediatamente con
rollback si el servidor rechaza.

**Verificar:**
- [ ] Mutation con optimistic update y rollback documentado.
- [ ] Rollback visible al usuario (toast explicando el fallo).

---

## Checklist resumen

| ID                | Control                                              | Severidad |
| ----------------- | ---------------------------------------------------- | --------- |
| UX-FEED-001       | Feedback visible del estado                          | high      |
| UX-FEED-002       | Estados distintos visualmente                        | medium    |
| UX-FEED-003       | Transiciones suaves                                  | low       |
| UX-FEED-010       | Confirmaciones para acciones destructivas            | high      |
| UX-FEED-011       | Undo cuando es posible                               | medium    |
| UX-FEED-012       | Auto-save + indicador                                | medium    |
| UX-FEED-020       | Errores útiles y humanos                             | high      |
| UX-FEED-021       | Recuperación asistida                                | medium    |
| UX-CONSIST-001    | Consistencia visual y de comportamiento              | medium    |
| UX-CONSIST-002    | Navegación estable                                   | medium    |
| UX-CONSIST-003    | Convenciones del SO/navegador                        | low       |
| UX-PREV-001       | Validación temprana                                  | medium    |
| UX-PREV-002       | Defaults razonables                                  | low       |
| UX-PREV-003       | Input masks                                          | low       |
| UX-PERF-001       | Skeleton screens                                     | low       |
| UX-PERF-002       | Optimistic UI                                        | low       |
