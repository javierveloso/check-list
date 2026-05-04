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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf,yml,yaml}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/app.{ts,js,py}`, `**/nginx.conf`, `**/ingress/**`
**Patrones:**
- `Strict-Transport-Security`                                                 # presencia esperada del header
- `helmet\(\s*\{[\s\S]*?hsts:\s*false`                                        # helmet con HSTS deshabilitado
- `max-age\s*=\s*0`                                                            # HSTS desactivado en runtime
- `add_header\s+Strict-Transport-Security`                                    # nginx HSTS
- `SECURE_HSTS_SECONDS\s*=\s*0`                                               # Django HSTS off
**Señal de N/A:** servicio interno-only sin HTTPS público (HSTS no aplica al no haber riesgo de downgrade).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`
**Patrones:**
- `X-Content-Type-Options[^\n]*nosniff`                                        # presencia esperada
- `helmet\(\s*\{[\s\S]*?noSniff:\s*false`                                     # helmet noSniff off
- `SECURE_CONTENT_TYPE_NOSNIFF\s*=\s*False`                                   # Django flag off
**Señal de N/A:** API que solo retorna JSON consumida por clientes no-navegador (curl, móvil nativo).

**Verificar:**
- [ ] `X-Content-Type-Options: nosniff` en todas las respuestas.

---

#### `SEC-HEADERS-003` — Protección contra clickjacking
**Severidad:** high · **Tags:** `cwe-1021` · **Aplica a:** backend · frontend

El contenido no se puede embeber en iframes de otros orígenes salvo cuando es
intencional.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`
**Patrones:**
- `X-Frame-Options[^\n]*(DENY|SAMEORIGIN)`                                    # presencia esperada del header
- `frame-ancestors\s+['"]?(none|self)['"]?`                                   # CSP frame-ancestors
- `X-Frame-Options[^\n]*ALLOW-FROM`                                           # variante obsoleta
- `helmet\(\s*\{[\s\S]*?frameguard:\s*false`                                  # helmet frameguard off
- `X_FRAME_OPTIONS\s*=\s*['"]ALLOWALL`                                        # Django ALLOWALL
**Señal de N/A:** la app no genera HTML (API JSON pura sin UI propia).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf,html}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`, `**/templates/**`
**Patrones:**
- `Referrer-Policy`                                                            # presencia esperada del header
- `<meta\s+name=["']referrer["']`                                              # configuración via meta tag
- `Referrer-Policy[^\n]*unsafe-url`                                            # política permisiva
- `helmet\(\s*\{[\s\S]*?referrerPolicy:\s*false`                              # helmet off
**Señal de N/A:** la app no genera HTML para navegadores (sin sesión de usuario en navegador).

**Verificar:**
- [ ] `Referrer-Policy: strict-origin-when-cross-origin` o más restrictivo (`same-origin`, `no-referrer`).
- [ ] No se envía `Referer` completo a terceros cuando contenga IDs o tokens en path/query.

---

#### `SEC-HEADERS-005` — Permissions-Policy limitando APIs del navegador
**Severidad:** medium · **Aplica a:** frontend · backend

Se deshabilitan explícitamente las APIs del navegador que no se usan (cámara,
micrófono, geolocalización, etc.).

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`
**Patrones:**
- `Permissions-Policy|Feature-Policy`                                         # presencia del header (Permissions reemplaza Feature)
- `(camera|microphone|geolocation|payment|usb)\s*=\s*\(?\s*\*\s*\)?`          # feature abierta a *
- `helmet\.permittedCrossDomainPolicies`                                      # helmet relacionado
**Señal de N/A:** la app no se carga en navegador (API JSON pura, sin UI ni iframes).

**Verificar:**
- [ ] `Permissions-Policy` declara las features habilitadas, las demás implícitamente negadas.
- [ ] Si se usa una feature, se limita por origen (`camera=(self)`, no `*`).

**Ejemplo:** `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(), usb=()`

---

#### `SEC-HEADERS-006` — Cross-Origin-*-Policy para aislamiento
**Severidad:** medium · **Aplica a:** backend

Los headers COEP/COOP/CORP endurecen el aislamiento entre orígenes.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`
**Patrones:**
- `Cross-Origin-Opener-Policy`                                                # COOP esperado
- `Cross-Origin-Resource-Policy`                                              # CORP esperado
- `Cross-Origin-Embedder-Policy`                                              # COEP esperado
- `helmet\(\s*\{[\s\S]*?crossOriginOpenerPolicy:\s*false`                     # helmet COOP off
**Señal de N/A:** la app no maneja sesión sensible en navegador (no requiere isolamiento cross-origin).

**Verificar:**
- [ ] `Cross-Origin-Opener-Policy: same-origin` en páginas que manejan sesión.
- [ ] `Cross-Origin-Resource-Policy: same-origin` en recursos privados.
- [ ] `Cross-Origin-Embedder-Policy: require-corp` si se requiere aislamiento fuerte.

---

#### `SEC-HEADERS-007` — Eliminar/neutralizar headers informativos
**Severidad:** low · **Aplica a:** backend · infra

Headers que revelan el stack o versión se remueven en producción.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`
**Patrones:**
- `X-Powered-By|X-AspNet-Version|X-Runtime|Server\s*:\s*['"]?(Express|nginx/|Apache/)` # headers que filtran stack
- `app\.disable\(['"]x-powered-by['"]\)|express\(\)\.disable\(`               # disable explícito esperado
- `server_tokens\s+off`                                                        # nginx ocultar versión
- `expose_php\s*=\s*Off`                                                      # PHP off
**Señal de N/A:** ninguna (todo servicio HTTP debe esconder banners de stack).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`
**Patrones:**
- `Content-Security-Policy[^\n]*\*`                                           # CSP con comodín
- `script-src[^;]*['"]?unsafe-inline['"]?`                                    # CSP con unsafe-inline
- `script-src[^;]*['"]?unsafe-eval['"]?`                                      # CSP con unsafe-eval
- `default-src\s+\*`                                                          # CSP base abierto
- `helmet\(\s*\{[\s\S]*?contentSecurityPolicy:\s*false`                        # helmet con CSP desactivado
- `nonce-[a-zA-Z0-9+/=]{8,}`                                                  # uso esperado de nonce
**Señal de N/A:** la app no genera HTML interactivo (API JSON pura).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`
**Patrones:**
- `script-src[^;]*\*\.googleapis\.com|script-src[^;]*\*\.cloudflare`          # allowlist amplio de CDN
- `script-src[^;]*ajax\.googleapis|script-src[^;]*\*\.amazonaws`              # CDNs con JSONP/redirects
- `strict-dynamic`                                                            # patrón seguro esperado
- `unsafe-inline\b[\s\S]*nonce-`                                              # mezcla nonce + unsafe-inline (problema)
**Señal de N/A:** no hay CSP definido aún (cubrir primero SEC-HEADERS-010).

**Verificar:**
- [ ] Orígenes allowlisted no tienen endpoints JSONP abiertos.
- [ ] Se prefiere `'strict-dynamic'` con nonces frente a allowlists frágiles.
- [ ] Se actualiza el CSP cuando se añaden terceros (analytics, mapas, chat).

---

#### `SEC-HEADERS-012` — Subresource Integrity (SRI) para scripts y estilos externos
**Severidad:** high · **Tags:** `supply-chain`, `cwe-829` · **Aplica a:** frontend

Los `<script>` y `<link>` que cargan recursos desde CDNs externos llevan el
atributo `integrity` con el hash SHA del recurso exacto. Si el CDN es comprometido
y sirve un archivo distinto, el navegador lo rechaza automáticamente.

**Dónde buscar:** `**/*.{html,htm,ejs,pug,hbs,jinja,j2,vue,jsx,tsx,svelte}`, `**/templates/**`, `**/views/**`, `**/public/**`, `**/index.html`
**Patrones:**
- `<script\s+[^>]*src\s*=\s*["']https?://[^"']+["'][^>]*>(?![\s\S]*integrity=)` # script externo sin integrity
- `<link\s+[^>]*href\s*=\s*["']https?://[^"']+["'][^>]*rel\s*=\s*["']stylesheet["'][^>]*>(?![\s\S]*integrity=)` # link externo sin integrity
- `cdn\.jsdelivr\.net.*@latest|unpkg\.com.*@latest`                            # versión flotante en CDN
- `integrity\s*=\s*["']sha(256|384|512)-`                                      # uso esperado de SRI
**Señal de N/A:** la app no carga assets desde CDNs externos (todo se sirve desde el propio dominio o bundle).

**Verificar:**
- [ ] Todo `<script src="https://cdn.externo.com/...">` incluye `integrity="sha256-..."` o `sha384-...` y `crossorigin="anonymous"`.
- [ ] Todo `<link rel="stylesheet" href="https://cdn.externo.com/...">` también lleva `integrity`.
- [ ] El hash se genera sobre el contenido exacto del asset de producción (no del de desarrollo).
- [ ] Cuando el recurso externo se actualiza, el hash se actualiza y el diff se revisa.
- [ ] Para recursos que no admiten SRI (Google Fonts dinámico, analytics con versioning flotante): se auto-hospeda el recurso, o se aplica CSP `connect-src` restrictivo como compensación.

**Banderas rojas:**
- `<script src="https://cdn.jsdelivr.net/npm/library@latest/dist/lib.min.js">` sin `integrity` — "latest" cambia sin aviso.
- Scripts de CDN corporativo interno sin SRI asumiendo que "es de confianza".
- Hash calculado sobre el bundle minificado de desarrollo, diferente del de producción.

**Herramientas:** https://www.srihash.org/ · bundler plugin `webpack-subresource-integrity` · CLI `openssl dgst -sha384 -binary file | openssl base64`.

**Referencias:** W3C Subresource Integrity · MDN SRI · CWE-829.

---

## C. Cookies (refuerza SEC-AUTH-014)

#### `SEC-HEADERS-020` — Atributos seguros en todas las cookies
**Severidad:** high · **Aplica a:** backend

Toda `Set-Cookie` sensible debe incluir atributos de seguridad; las no sensibles
también deben evaluarse.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/middleware/**`, `**/auth/**`, `**/session/**`, `**/main.{ts,js,py}`
**Patrones:**
- `cookie\s*\(.*\{[\s\S]*?secure:\s*false`                                    # cookie secure: false
- `httpOnly:\s*false|http_only=False`                                         # httpOnly off
- `sameSite:\s*['"]?(none|None)['"]?(?![\s\S]*secure:\s*true)`                # SameSite=None sin Secure
- `SESSION_COOKIE_SECURE\s*=\s*False|SESSION_COOKIE_HTTPONLY\s*=\s*False`     # Django flags off
- `Set-Cookie:[^;\n]*(?!.*Secure)(?!.*HttpOnly)`                              # cookie sin atributos
- `__Host-|__Secure-`                                                          # prefijos esperados
**Señal de N/A:** la app no usa cookies (auth solo via Bearer token en header).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`, `package.json`, `requirements*.txt`, `pyproject.toml`
**Patrones:**
- `(rate[_-]?limit|throttle|slow[_-]?down|express-rate-limit|slowapi|ratelimit)` # libs/middleware esperados
- `limit_req_zone|limit_conn_zone`                                            # nginx rate limit
- `MemoryStore\(\)|new\s+Map\(\)[\s\S]*?rateLimit`                            # store en memoria
- `X-Forwarded-For[\s\S]*?(?!trusted)`                                        # uso de XFF — verificar trust
- `key:\s*req\.ip|keyGenerator:\s*\(req\)\s*=>\s*req\.ip`                     # key del rate limiter
**Señal de N/A:** servicio interno-only detrás de API gateway que aplica rate limit (verificar gateway externamente).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/middleware/**`, `**/openapi*.{yml,yaml,json}`, `**/swagger*.{yml,yaml,json}`
**Patrones:**
- `X-RateLimit-(Limit|Remaining|Reset)`                                       # headers esperados
- `Retry-After`                                                                # header de 429
- `429\b[\s\S]{0,200}Retry-After`                                             # 429 documentando Retry-After
**Señal de N/A:** repo sin rate limiting implementado (cubrir primero SEC-HEADERS-030).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/nginx.conf`
**Patrones:**
- `bodyParser\.(json|urlencoded)\(\s*\)`                                       # body-parser sin limit
- `express\.json\(\s*\)`                                                      # Express json sin opts
- `client_max_body_size\s+\d+[gG]`                                            # nginx con límite alto
- `DATA_UPLOAD_MAX_MEMORY_SIZE|FILE_UPLOAD_MAX_MEMORY_SIZE`                   # Django config esperado
- `max_depth|maxDepth|MAX_NESTING`                                            # profundidad de JSON
**Señal de N/A:** repo sin endpoints HTTP entrantes que reciban JSON.

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/clients/**`, `**/services/**`, `**/integrations/**`, `**/repositories/**`
**Patrones:**
- `requests\.(get|post|put|delete|patch)\(\s*[^)]*\)(?![^,)]*timeout)`         # Python requests sin timeout
- `httpx\.(get|post|AsyncClient)\(\s*\)`                                      # httpx default sin timeout
- `axios\.(get|post)\(\s*[^,)]*\)(?![^,)]*timeout)`                           # axios sin timeout
- `fetch\(\s*[^,)]*\)(?![^,)]*signal)`                                        # fetch sin AbortController
- `urlopen\(\s*[^,)]*\)(?![^,)]*timeout)`                                     # urlopen sin timeout
- `statement_timeout|connect_timeout|read_timeout`                            # timeouts esperados
**Señal de N/A:** la app no realiza I/O externo (lib pura, sin BD ni HTTP saliente).

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

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,yml,yaml}`, `**/database.{yml,yaml,json,ts,js,py}`, `**/config/**`
**Patrones:**
- `pool_size|poolSize|max_connections|maxConnections`                         # patrones esperados
- `max_overflow|connection_limit|max_pool_size`                               # config pool esperada
- `new\s+Pool\(\s*\)|createPool\(\s*\)`                                       # pool sin opciones
- `new\s+\w*Client\(\)\s*[\s\S]{0,200}for\s*\(`                               # cliente nuevo dentro de loop
**Señal de N/A:** la app no usa pools (single-shot CLI, scripts batch sin conexiones persistentes).

**Verificar:**
- [ ] `pool_size`, `max_overflow`, o equivalente configurados.
- [ ] Alertas si el pool está frecuentemente al 100%.
- [ ] El pool se reutiliza (no se abre un cliente nuevo por request).

---

#### `SEC-HEADERS-043` — Paginación obligatoria en listados
**Severidad:** high · **Aplica a:** api · backend

Los endpoints de listado tienen paginación obligatoria con tamaño máximo para
prevenir response bombs.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/controllers/**`, `**/handlers/**`, `**/repositories/**`, `**/openapi*.{yml,yaml,json}`
**Patrones:**
- `\.findAll\(\s*\)|\.find\(\s*\{\s*\}\s*\)|Model\.objects\.all\(\s*\)`       # query sin limit
- `(page_size|pageSize|limit)\s*[:=]\s*(req|request)\.(query|params)`         # tamaño desde cliente sin cap
- `LIMIT\s+\$\{|LIMIT\s+["']\s*\+`                                            # LIMIT por interpolación sin cap
- `\.toList\(\)|\.collect\(\)`                                                # carga en memoria sin paginar
- `MAX_PAGE_SIZE|max_page_size|DEFAULT_LIMIT`                                 # constantes esperadas
**Señal de N/A:** repo sin endpoints de listado (solo CRUD por id, sin colecciones).

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
| SEC-HEADERS-012    | Subresource Integrity (SRI) para CDN externos          | high      |
| SEC-HEADERS-020    | Atributos seguros en cookies                           | high      |
| SEC-HEADERS-030    | Rate limiting global y por endpoint                    | critical  |
| SEC-HEADERS-031    | Headers informativos de rate limit                     | medium    |
| SEC-HEADERS-040    | Límites de tamaño y profundidad                        | high      |
| SEC-HEADERS-041    | Timeouts en operaciones externas                       | critical  |
| SEC-HEADERS-042    | Pool de conexiones acotado                             | medium    |
| SEC-HEADERS-043    | Paginación obligatoria (→ API)                         | high      |
