# 01 · Seguridad · Headers HTTP y rate limiting

> Cabeceras de seguridad HTTP, CSP, rate limiting y protecciones anti-DoS.
>
> **Marcos de referencia:** OWASP Secure Headers Project · OWASP A05:2021 · OWASP API4:2023 · CWE-16, CWE-693, CWE-770, CWE-400.

---

## A. Cabeceras de seguridad obligatorias

#### `SEC-HEADERS-001` — HSTS forzando HTTPS
**Severidad:** high · **Tags:** `owasp-a02`, `hsts` · **Aplica a:** backend · infra

Todas las respuestas sobre HTTPS llevan `Strict-Transport-Security` con un
`max-age` largo y, cuando el dominio no sirve HTTP, `includeSubDomains` y
`preload`.

**Verificar:**
- [ ] Header presente en respuestas HTTPS.
- [ ] `max-age` ≥ 31 536 000 (1 año) en producción.
- [ ] `includeSubDomains` si ningún subdominio necesita HTTP.
- [ ] `preload` si el dominio está en la lista de preload.

**Ejemplo:** `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`

**Banderas rojas:**
- HSTS ausente.
- `max-age=0` en producción sin causa documentada.

---

#### `SEC-HEADERS-002` — X-Content-Type-Options nosniff
**Severidad:** high · **Aplica a:** backend

Previene que el navegador adivine el MIME y ejecute como script un archivo servido
con otro Content-Type.

**Verificar:**
- [ ] `X-Content-Type-Options: nosniff` en todas las respuestas.

---

#### `SEC-HEADERS-003` — Protección contra clickjacking
**Severidad:** high · **Tags:** `cwe-1021` · **Aplica a:** backend · frontend

El contenido no se puede embeber en iframes de otros orígenes salvo cuando es
intencional.

**Verificar:**
- [ ] `Content-Security-Policy: frame-ancestors 'none'` (o `'self'` si se embebe).
- [ ] Alternativamente `X-Frame-Options: DENY` / `SAMEORIGIN` como compatibilidad.
- [ ] Las páginas de login, pago y admin tienen `frame-ancestors 'none'`.

**Banderas rojas:**
- Ausencia de ambos headers.
- `X-Frame-Options: ALLOW-FROM *` (obsoleto y permisivo).

---

#### `SEC-HEADERS-004` — Referrer-Policy restrictivo
**Severidad:** medium · **Aplica a:** backend · frontend

Se limita la información enviada en el `Referer` al navegar a orígenes externos.

**Verificar:**
- [ ] `Referrer-Policy: strict-origin-when-cross-origin` o más restrictivo (`same-origin`, `no-referrer`).
- [ ] No se envía `Referer` completo a terceros cuando contenga IDs o tokens en path/query.

---

#### `SEC-HEADERS-005` — Permissions-Policy limitando APIs del navegador
**Severidad:** medium · **Aplica a:** frontend · backend

Se deshabilitan explícitamente las APIs del navegador que no se usan (cámara,
micrófono, geolocalización, etc.).

**Verificar:**
- [ ] `Permissions-Policy` declara las features habilitadas, las demás implícitamente negadas.
- [ ] Si se usa una feature, se limita por origen (`camera=(self)`, no `*`).

**Ejemplo:** `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(), usb=()`

---

#### `SEC-HEADERS-006` — Cross-Origin-*-Policy para aislamiento
**Severidad:** medium · **Aplica a:** backend

Los headers COEP/COOP/CORP endurecen el aislamiento entre orígenes.

**Verificar:**
- [ ] `Cross-Origin-Opener-Policy: same-origin` en páginas que manejan sesión.
- [ ] `Cross-Origin-Resource-Policy: same-origin` en recursos privados.
- [ ] `Cross-Origin-Embedder-Policy: require-corp` si se requiere aislamiento fuerte.

---

#### `SEC-HEADERS-007` — Eliminar/neutralizar headers informativos
**Severidad:** low · **Aplica a:** backend · infra

Headers que revelan el stack o versión se remueven en producción.

**Verificar:**
- [ ] `Server` y `X-Powered-By` omitidos o genéricos.
- [ ] `X-AspNet-Version`, `X-Runtime`, `Via` revisados.
- [ ] No se exponen versiones exactas que ayuden a mapear CVEs.

---

## B. Content Security Policy (CSP)

#### `SEC-HEADERS-010` — CSP restrictivo con nonces o hashes
**Severidad:** high · **Tags:** `csp`, `xss-mitigation` · **Aplica a:** frontend · backend

El CSP bloquea scripts inline y de orígenes no esperados. Cuando hay scripts
inline inevitables, se usan nonces dinámicos o hashes.

**Verificar:**
- [ ] `default-src 'self'`.
- [ ] `script-src` sin `'unsafe-inline'` ni `'unsafe-eval'`.
- [ ] `style-src` sin `'unsafe-inline'` (o con nonces).
- [ ] `img-src` y `connect-src` restringidos a orígenes conocidos.
- [ ] `object-src 'none'`, `base-uri 'self'`, `frame-ancestors 'none'`.
- [ ] `form-action 'self'` (o orígenes específicos).
- [ ] Existe reporting (`report-to` o `report-uri`) para detectar violaciones.
- [ ] Se despliega primero en modo `Content-Security-Policy-Report-Only`, luego se enforce.

**Banderas rojas:**
- CSP con `*` o `'unsafe-inline'` heredado del template.
- Nonces reutilizados entre requests.
- `default-src *` como base.

**Referencias:** MDN CSP · OWASP CSP Cheat Sheet.

---

#### `SEC-HEADERS-011` — CSP sin bypasses conocidos
**Severidad:** high · **Aplica a:** frontend · backend

Evitar allowlist de CDN con JSONP, dominios con redirects abiertos, o hosts que
sirvan scripts arbitrarios.

**Verificar:**
- [ ] Orígenes allowlisted no tienen endpoints JSONP abiertos.
- [ ] Se prefiere `'strict-dynamic'` con nonces frente a allowlists frágiles.
- [ ] Se actualiza el CSP cuando se añaden terceros (analytics, mapas, chat).

---

## C. Cookies (refuerza SEC-AUTH-014)

#### `SEC-HEADERS-020` — Atributos seguros en todas las cookies
**Severidad:** high · **Aplica a:** backend

Toda `Set-Cookie` sensible debe incluir atributos de seguridad; las no sensibles
también deben evaluarse.

**Verificar:**
- [ ] Cookies de sesión: `Secure`, `HttpOnly`, `SameSite`.
- [ ] Prefijos `__Host-` o `__Secure-` cuando aplique.
- [ ] `Domain` y `Path` lo más restrictivos posible.
- [ ] Las cookies persistentes tienen un `Expires`/`Max-Age` acotado.

---

## D. Rate limiting

#### `SEC-HEADERS-030` — Rate limiting global y por endpoint
**Severidad:** critical · **Tags:** `owasp-api4`, `cwe-770` · **Aplica a:** backend

Todos los endpoints, incluso de lectura, tienen rate limiting. Los endpoints de
autenticación y los que consumen recursos externos (IA, email) tienen cuotas
más estrictas.

**Verificar:**
- [ ] Existe un middleware global de rate limiting con política por defecto.
- [ ] Endpoints costosos (login, reset password, enviar email, llamar IA) tienen cuotas más bajas.
- [ ] Las respuestas 429 incluyen `Retry-After`.
- [ ] El store del rate limiter es compartido (Redis/BD), no in-memory.
- [ ] Hay límite por IP y por usuario autenticado.
- [ ] El rate limiter no se puede burlar con headers proxy (`X-Forwarded-For` validado contra proxy de confianza).

**Banderas rojas:**
- Endpoints sin rate limiting.
- Contador en memoria sin shared store.
- Headers `X-Forwarded-For` usados sin validar el proxy de confianza.

**Referencias:** OWASP API4:2023 · RFC 6585.

---

#### `SEC-HEADERS-031` — Headers informativos de rate limit
**Severidad:** medium · **Aplica a:** backend · api

Las respuestas de endpoints con rate limiting exponen cuánto queda de cuota.

**Verificar:**
- [ ] `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` presentes.
- [ ] En 429, `Retry-After` está presente (segundos o fecha HTTP).
- [ ] Los headers se documentan en OpenAPI.

---

## E. Protección anti-DoS a nivel aplicación

#### `SEC-HEADERS-040` — Límites de tamaño y profundidad de request
**Severidad:** high · **Tags:** `cwe-400`, `cwe-1321` · **Aplica a:** backend

Body máximo, profundidad máxima de JSON, tamaño máximo de arrays, para prevenir
DoS por consumo de CPU/memoria al parsear.

**Verificar:**
- [ ] Límite global de body (ej: 1 MB para JSON, más para upload explícito).
- [ ] Profundidad máxima de JSON (ej: 10–20 niveles).
- [ ] Límite de claves por objeto y elementos por array.
- [ ] `Content-Length` se valida ANTES de leer el body completo.

---

#### `SEC-HEADERS-041` — Timeouts en operaciones externas
**Severidad:** critical · **Aplica a:** backend

Todo I/O externo (BD, HTTP, cola, cache) tiene timeout explícito. Sin timeout,
un proveedor lento tumba toda la app.

**Verificar:**
- [ ] Clients HTTP con `timeout` configurado (connect + read).
- [ ] Pool de conexiones BD con `timeout` al adquirir.
- [ ] `asyncio.wait_for` o equivalente alrededor de llamadas externas largas.
- [ ] Timeout del servidor HTTP entrante (keep-alive, request body, headers).

**Banderas rojas:**
- `requests.get(url)` sin `timeout`.
- `httpx.AsyncClient()` sin `timeout`.
- Fetch/axios sin timeout configurado.
- Queries sin `statement_timeout` del lado BD o del driver.

---

#### `SEC-HEADERS-042` — Pool de conexiones acotado
**Severidad:** medium · **Aplica a:** backend

Los pools de conexiones (BD, HTTP, cache) tienen un tamaño máximo para evitar
agotar recursos del sistema.

**Verificar:**
- [ ] `pool_size`, `max_overflow`, o equivalente configurados.
- [ ] Alertas si el pool está frecuentemente al 100%.
- [ ] El pool se reutiliza (no se abre un cliente nuevo por request).

---

#### `SEC-HEADERS-043` — Paginación obligatoria en listados
**Severidad:** high · **Aplica a:** api · backend

Los endpoints de listado tienen paginación obligatoria con tamaño máximo para
prevenir response bombs.

(Detalle en `02-api-diseno/03-paginacion-filtros.md` `API-PAGE-001`.)

---

## Checklist resumen

| ID                 | Control                                                | Severidad |
| ------------------ | ------------------------------------------------------ | --------- |
| SEC-HEADERS-001    | HSTS                                                   | high      |
| SEC-HEADERS-002    | X-Content-Type-Options nosniff                         | high      |
| SEC-HEADERS-003    | Anti-clickjacking (frame-ancestors/X-Frame-Options)    | high      |
| SEC-HEADERS-004    | Referrer-Policy                                        | medium    |
| SEC-HEADERS-005    | Permissions-Policy                                     | medium    |
| SEC-HEADERS-006    | COOP/COEP/CORP                                         | medium    |
| SEC-HEADERS-007    | Ocultar headers informativos                           | low       |
| SEC-HEADERS-010    | CSP restrictivo                                        | high      |
| SEC-HEADERS-011    | CSP sin bypasses conocidos                             | high      |
| SEC-HEADERS-020    | Atributos seguros en cookies                           | high      |
| SEC-HEADERS-030    | Rate limiting global y por endpoint                    | critical  |
| SEC-HEADERS-031    | Headers informativos de rate limit                     | medium    |
| SEC-HEADERS-040    | Límites de tamaño y profundidad                        | high      |
| SEC-HEADERS-041    | Timeouts en operaciones externas                       | critical  |
| SEC-HEADERS-042    | Pool de conexiones acotado                             | medium    |
| SEC-HEADERS-043    | Paginación obligatoria (→ API)                         | high      |
