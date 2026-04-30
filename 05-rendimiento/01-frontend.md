# 05 · Rendimiento · Frontend

> Core Web Vitals, bundle, hidratación, rendering, caché de assets.
>
> **Marcos de referencia:** Core Web Vitals (Google) · web.dev Performance · RAIL model.

---

## A. Core Web Vitals

#### `PERF-FE-001` — LCP (Largest Contentful Paint) < 2.5 s
**Severidad:** high · **Aplica a:** frontend

El elemento principal (hero image, texto destacado, CTA) aparece en los
primeros 2.5 s en mobile p75.

**Verificar:**
- [ ] Imagen/recurso LCP identificado y optimizado (tamaño, formato moderno: WebP/AVIF).
- [ ] Fuentes con `font-display: swap` para no bloquear el render.
- [ ] `preload` para recursos críticos del LCP.
- [ ] Medición en producción (RUM: Real User Monitoring) y en CI (Lighthouse, WebPageTest).

**Banderas rojas:**
- Imagen LCP en JPEG sin optimizar, cargada con `<img>` sin dimensiones ni lazy.
- Fuentes que bloquean render sin fallback.

---

#### `PERF-FE-002` — INP (Interaction to Next Paint) < 200 ms
**Severidad:** high · **Aplica a:** frontend

La respuesta a interacciones (click, tap, input) ocurre en < 200 ms p75.

**Verificar:**
- [ ] Tareas largas en main thread < 50 ms.
- [ ] Handlers de input no hacen trabajo pesado sincrónico (deferir con `requestIdleCallback` o web worker).
- [ ] Frameworks con concurrent rendering cuando aplica (React 18, Vue 3).
- [ ] Long Tasks y Total Blocking Time medidos.

---

#### `PERF-FE-003` — CLS (Cumulative Layout Shift) < 0.1
**Severidad:** high · **Aplica a:** frontend

La página no salta durante la carga.

**Verificar:**
- [ ] Imágenes con `width` y `height` declarados.
- [ ] Reserva de espacio para anuncios, banners, embeds, videos.
- [ ] Fuentes sin FOUT/FOIT brusco.
- [ ] No hay contenido que se inserta arriba de la vista (notificaciones, banners tardíos).

**Banderas rojas:**
- Imágenes sin dimensiones.
- Banner de cookies que empuja contenido al aparecer.

---

## B. Bundle y carga

#### `PERF-FE-010` — Code splitting por ruta y por feature
**Severidad:** high · **Aplica a:** frontend

La aplicación se divide en chunks; solo se descarga lo necesario para la pantalla
actual.

**Verificar:**
- [ ] Routing con lazy loading (React.lazy + Suspense, dynamic imports).
- [ ] Features pesadas (editor, viewer PDF, gráfico) detrás de import dinámico.
- [ ] Bundle inicial < 150–200 KB gzip (depende del contexto).
- [ ] Bundle analyzer corre en CI y muestra cambios en el PR.

---

#### `PERF-FE-011` — Tree-shaking y dead code elimination
**Severidad:** medium · **Aplica a:** frontend

Las dependencias se importan granularmente y el bundler elimina lo no usado.

**Verificar:**
- [ ] Imports específicos (`import { Button } from "lib"`) cuando la lib lo soporta.
- [ ] No hay side effects en módulos que impidan tree-shaking.
- [ ] CSS unused purgado (Tailwind purge, PurgeCSS, CSS modules).
- [ ] Sin polyfills innecesarios para navegadores modernos.

**Banderas rojas:**
- `import * as _ from "lodash"` (usa toda la librería).
- Librerías de íconos importadas enteras.

---

#### `PERF-FE-012` — Imágenes optimizadas y responsivas
**Severidad:** high · **Aplica a:** frontend

Las imágenes se sirven en formato moderno, comprimidas y en el tamaño adecuado.

**Verificar:**
- [ ] Formatos modernos (WebP/AVIF) con fallback.
- [ ] `srcset` + `sizes` para múltiples resoluciones.
- [ ] `loading="lazy"` para imágenes fuera de vista.
- [ ] CDN/image service con transformaciones on-the-fly si es posible.
- [ ] `<picture>` con `media` para art direction cuando cambia el crop.

---

#### `PERF-FE-013` — Fuentes optimizadas
**Severidad:** medium · **Aplica a:** frontend

Las fuentes cargan rápido y sin bloquear render.

**Verificar:**
- [ ] `font-display: swap` (o `optional`) para no bloquear.
- [ ] Subset de caracteres cuando aplica (no cargar el set completo).
- [ ] Preload de la familia primaria.
- [ ] Máximo 2-3 familias, número acotado de pesos.

---

#### `PERF-FE-014` — Cache HTTP de assets inmutables
**Severidad:** high · **Aplica a:** infra · frontend

Los assets tienen fingerprint y `Cache-Control: max-age=31536000, immutable`;
HTML tiene cache corto.

**Verificar:**
- [ ] JS/CSS/fuentes/imágenes con hash en el nombre.
- [ ] Cache inmutable en CDN para esos recursos.
- [ ] HTML con `no-cache` o `max-age` muy corto.
- [ ] Service worker (si aplica) actualiza correctamente.

---

## C. Rendering y estado

#### `PERF-FE-020` — Evitar re-renders costosos
**Severidad:** medium · **Aplica a:** frontend

Los componentes no se re-renderean innecesariamente en árboles grandes.

**Verificar:**
- [ ] Memoización (`React.memo`, `useMemo`, `useCallback`) aplicada donde aporta (no en todos lados).
- [ ] Listas grandes virtualizadas (react-window, tanstack-virtual) sobre ~50-100 items.
- [ ] Formularios largos: re-renders localizados (uncontrolled inputs, `useRef`, react-hook-form).

**Banderas rojas:**
- Re-render de 1000 filas cada keystroke en un input.
- `useMemo` por reflejo sobre valores primitivos baratos.

---

#### `PERF-FE-021` — Estado del servidor con caché apropiado
**Severidad:** high · **Aplica a:** frontend

El estado proveniente del server (queries) se cachea y se invalida con intención.

**Verificar:**
- [ ] Herramienta de caché de servidor (TanStack Query, SWR, Apollo Cache) en uso.
- [ ] `staleTime` configurado acorde a la frecuencia real de cambio del recurso.
- [ ] Invalidación por mutación con optimistic updates y rollback en caso de error.
- [ ] `gcTime`/`cacheTime` controla la memoria en sesiones largas.
- [ ] No hay refetch innecesario al recuperar el foco (`refetchOnWindowFocus: false` cuando no aplica).
- [ ] Las llamadas a la misma URL desde distintos componentes comparten la misma entrada de caché.

**Banderas rojas:**
- Patrón `useEffect(() => { fetchX().then(setData) }, [id])` repetido en más de 3 componentes sin librería de caché.
- Llamadas a `axiosInstance.get(url)` directamente dentro de componentes sin capa de caché intermedia.
- Modal o drawer que dispara una nueva llamada de red cada vez que se abre.
- Polling agresivo (intervalo ≤ 2 s) sin necesidad de tiempo real documentada.
- Refetch disparado en cada remount de un componente de lista (ej: cambiar de pestaña → recarga completa).

---

#### `PERF-FE-022` — Animaciones suaves (60 fps / GPU)
**Severidad:** low · **Aplica a:** frontend

Las animaciones usan `transform`/`opacity`, no `top/left/width/height`, para
no disparar layout/paint.

**Verificar:**
- [ ] Animaciones en CSS con `transform` / `opacity`.
- [ ] `will-change` solo cuando aporta.
- [ ] `prefers-reduced-motion` respetado.
- [ ] No hay JS animando por frame cosas que CSS podría.

---

#### `PERF-FE-023` — useEffect con I/O async: cleanup y AbortController
**Severidad:** high · **Tags:** `memory-leak`, `react` · **Aplica a:** frontend

Los `useEffect` que disparan fetch o suscripciones asíncronas retornan una función
de cleanup que aborta la petición o cancela la suscripción al desmontar el
componente. Previene memory leaks y condiciones de carrera cuando un ID cambia
antes de completarse la petición anterior.

**Verificar:**
- [ ] Todo `useEffect` con `fetch` / Axios usa `AbortController` y retorna `() => controller.abort()`.
- [ ] Axios recibe `{ signal: controller.signal }` como opción.
- [ ] Suscripciones a WebSocket / EventSource se cierran en el cleanup.
- [ ] El error de abort se captura y descarta silenciosamente (`axios.isCancel`, `err.name === 'AbortError'`).
- [ ] No aparece el warning "Can't perform a React state update on an unmounted component" en consola.

**Banderas rojas:**
- `useEffect(() => { fetch(url).then(setData) }, [id])` sin AbortController ni cleanup.
- Axios sin `signal` en efectos cuyo `id` puede cambiar rápidamente (buscador, paginación).
- Componentes de lista / modal que disparan una petición nueva en cada montaje sin cancelar la anterior.

**Ejemplo de hallazgo:**
```yaml
control_id: PERF-FE-023
severity: high
file: src/components/ItemDetail.tsx
line: 14
evidence: |
  useEffect(() => {
    axios.get(`/api/items/${id}`).then(res => setData(res.data));
  }, [id]);
explanation: |
  Si el usuario navega antes de completar la petición, axios la continúa
  y setData() intenta actualizar estado en un componente desmontado.
  Cuando id cambia rápido (paginación), varias peticiones en vuelo pueden
  resolverse fuera de orden (race condition).
suggestion: |
  useEffect(() => {
    const controller = new AbortController();
    axios
      .get(`/api/items/${id}`, { signal: controller.signal })
      .then(res => setData(res.data))
      .catch(err => { if (!axios.isCancel(err)) setError(err); });
    return () => controller.abort();
  }, [id]);
```

---

## D. Red y requests

#### `PERF-FE-030` — Requests concurrentes y HTTP/2+
**Severidad:** medium · **Aplica a:** frontend · infra

El servidor soporta HTTP/2 o HTTP/3, permitiendo multiplexing.

**Verificar:**
- [ ] CDN / edge con HTTP/2/3.
- [ ] No hay "domain sharding" de la era HTTP/1.1.
- [ ] Requests en paralelo en cargas críticas (no cascadas innecesarias).

---

#### `PERF-FE-031` — Prefetch / preload / prerender prudente
**Severidad:** low · **Aplica a:** frontend

Los recursos se prefetch-ean cuando hay alta probabilidad de uso, pero sin
consumir ancho de banda móvil innecesariamente.

**Verificar:**
- [ ] Hay `prefetch` de rutas probables (ej: link a siguiente pantalla).
- [ ] `preload` solo para recursos que se usarán muy pronto.
- [ ] En móvil saver/data-saver, se degradan prefetches.

---

## E. Medición

#### `PERF-FE-040` — RUM en producción
**Severidad:** high · **Aplica a:** frontend · infra

Se mide Web Vitals en usuarios reales.

**Verificar:**
- [ ] Herramienta de RUM (Google Analytics 4, Vercel Analytics, SpeedCurve, custom) en prod.
- [ ] p75 de LCP, INP, CLS reportados y alertados.
- [ ] Segmentación por dispositivo, red, país.

---

#### `PERF-FE-041` — Budget de performance en CI
**Severidad:** medium · **Aplica a:** ci-cd

Hay presupuestos (bundle size, Lighthouse scores) que bloquean regresiones.

**Verificar:**
- [ ] Lighthouse CI / SpeedCurve con thresholds.
- [ ] PRs que superan presupuesto requieren aprobación explícita.
- [ ] Bundle size trackeado (size-limit, bundlewatch).

---

## Checklist resumen

| ID             | Control                                          | Severidad |
| -------------- | ------------------------------------------------ | --------- |
| PERF-FE-001    | LCP < 2.5 s                                      | high      |
| PERF-FE-002    | INP < 200 ms                                     | high      |
| PERF-FE-003    | CLS < 0.1                                        | high      |
| PERF-FE-010    | Code splitting                                   | high      |
| PERF-FE-011    | Tree-shaking                                     | medium    |
| PERF-FE-012    | Imágenes optimizadas                             | high      |
| PERF-FE-013    | Fuentes optimizadas                              | medium    |
| PERF-FE-014    | Cache HTTP de assets                             | high      |
| PERF-FE-020    | Evitar re-renders costosos                       | medium    |
| PERF-FE-021    | Cache del estado del servidor                    | high      |
| PERF-FE-022    | Animaciones suaves                               | low       |
| PERF-FE-023    | useEffect async con cleanup (AbortController)    | high      |
| PERF-FE-030    | HTTP/2+ y requests concurrentes                  | medium    |
| PERF-FE-031    | Prefetch prudente                                | low       |
| PERF-FE-040    | RUM en producción                                | high      |
| PERF-FE-041    | Budget de performance en CI                      | medium    |
