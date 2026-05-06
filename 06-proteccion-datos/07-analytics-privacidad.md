# 06 · Protección de datos · Analytics y rastreo respetuoso

> Implementación de analytics y tracking que cumple con GDPR/LGPD: consentimiento
> real en código, sin PII en eventos, SDKs de terceros bajo control y auditable.
> La diferencia entre "tenemos un banner de cookies" y "el código lo respeta".
>
> **Marcos de referencia:** GDPR Art. 6 · 7 · 25 · ePrivacy Directive · IAB TCF 2.0 · CNIL Guidelines.

---

## A. Consentimiento y carga de SDKs

#### `DATA-ANALYTICS-002` — SDKs de tracking cargados solo tras consentimiento
**Severidad:** critical · **Tags:** `gdpr` `consent` `tracking` · **Aplica a:** frontend

El código de tracking (Google Analytics, Meta Pixel, Hotjar, etc.) no se ejecuta
ni se carga hasta que el usuario haya dado consentimiento afirmativo. El banner
visual sin bloqueo técnico no es suficiente.

**Dónde buscar:** `**/*.{html,htm,ejs,hbs,pug,jinja,j2}`, `**/templates/**`, `**/views/**`, `**/public/index.html`, `**/_app.{tsx,jsx,ts,js}`, `**/layout.{tsx,jsx}`, `**/consent*.{ts,js}`, `**/analytics*.{ts,js}`, `**/gtm*.{ts,js}`
**Patrones:**
- `gtag\(|ga\(|fbq\(|_hsp\.|hotjar\.|mixpanel\.|segment\.`                     # SDKs de analytics cargándose directamente
- `<script.*googletagmanager|<script.*google-analytics|<script.*fbevents`       # scripts embebidos sin guard
- `loadAnalytics\(|initTracking\(`                                              # funciones de init (verificar guard de consentimiento)
- `consentGiven\s*&&|hasConsent\(\)|getConsent\(\)|tcfapi\|Cookiebot`          # patrón correcto esperado
- `window\.__tcfapi|window\.Cookiebot|window\.OneTrust|window\.CookieControl`  # CMPs esperados
**Señal de N/A:** producto B2B sin tracking de comportamiento de usuario final (solo métricas de infraestructura).

**Verificar:**
- [ ] Los scripts de analytics se cargan dinámicamente solo cuando `consentGiven === true`.
- [ ] El consentimiento se persiste correctamente (cookie/localStorage) y se respeta en visitas posteriores.
- [ ] Si el usuario rechaza o revoca el consentimiento, los SDKs se descargan o se desinicializan.
- [ ] La CMP (Consent Management Platform) bloquea técnicamente los scripts antes del consentimiento, no solo visualmente.

**Banderas rojas:**
- `gtag('config', 'G-XXXXX')` en `<head>` sin condición de consentimiento.
- SDK de analytics en el bundle principal que ejecuta en carga de página.
- Consent banner que aparece pero no bloquea la carga de scripts.

---

#### `DATA-ANALYTICS-004` — Pixels y beacons de terceros bajo consentimiento
**Severidad:** high · **Tags:** `gdpr` `consent` `tracking` · **Aplica a:** frontend

Los pixels de retargeting (Meta, LinkedIn, TikTok, Google Ads) y beacons de
email marketing solo se activan con consentimiento de marketing, que es una
categoría distinta al analytics.

**Dónde buscar:** `**/*.{html,htm,tsx,jsx,vue,svelte}`, `**/templates/**`, `**/_document.{tsx,jsx}`, `**/tag-manager*.{ts,js}`, `**/pixel*.{ts,js}`
**Patrones:**
- `fbq\(['"]track|ttq\.|lintrk\(|_linkedin_partner_id|snap\.track`             # pixels de retargeting
- `<img.*pixel\.facebook|<img.*analytics\.twitter|<img.*bat\.bing`             # tracking pixels en img
- `new Image\(\).*pixel|navigator\.sendBeacon\(`                                # beacons (verificar guard)
- `marketingConsent|adsConsent|consentCategories.*marketing`                   # patrón correcto esperado
**Señal de N/A:** producto sin campañas de paid media ni retargeting.

**Verificar:**
- [ ] Los pixels de retargeting solo se activan con consentimiento de categoría "marketing" o "publicidad".
- [ ] El consentimiento de analytics (estadístico) no implica consentimiento de marketing.
- [ ] Los beacons de email (`<img>` tracking) tienen alternativa sin tracking para usuarios que rechazaron.
- [ ] Los pixels están listados en la política de privacidad con su propósito.

**Banderas rojas:**
- Meta Pixel activo para todos los usuarios, incluidos quienes rechazaron marketing.
- Pixel de retargeting cargado al mismo tiempo que el de analytics, sin distinción de consentimiento.

---

## B. Datos en eventos de analytics

#### `DATA-ANALYTICS-003` — Sin PII en eventos de analytics
**Severidad:** critical · **Tags:** `gdpr` `pii` `analytics` · **Aplica a:** frontend · backend

Los eventos enviados a plataformas de analytics no contienen datos personales
identificables. Las plataformas de analytics no son bases de datos de clientes.

**Dónde buscar:** `**/*.{ts,js,py,rb,go,java,cs}`, `**/analytics*.{ts,js}`, `**/tracking*.{ts,js}`, `**/events*.{ts,js}`, `**/segment*.{ts,js}`, `**/mixpanel*.{ts,js}`
**Patrones:**
- `identify\(\s*user\.(email|name|phone|rut|dni|ssn|cpf)`                      # identify con PII directa
- `track\([^)]*,\s*\{[^}]*(email|phone|name|address|rut|dni)\s*:`              # track con PII en props
- `gtag.*['"]email['"]|gtag.*['"]phone['"]`                                    # gtag con PII
- `analytics\.identify\(|mixpanel\.identify\(|heap\.identify\(`                # identify (verificar qué ID se pasa)
- `userId:\s*(user\.id|uuid\()|anonymousId`                                    # patrón correcto con ID anónimo
**Señal de N/A:** sistema de análisis interno sin envío a terceros, con datos solo en infraestructura propia.

**Verificar:**
- [ ] El `identify()` usa un ID interno opaco, nunca email, nombre o documento.
- [ ] Las propiedades de eventos no incluyen campos PII (email, teléfono, nombre, dirección).
- [ ] Los eventos de e-commerce no incluyen más datos de los necesarios (no datos completos de tarjeta, no dirección completa).
- [ ] Los user properties en herramientas como Mixpanel o Amplitude no contienen PII.
- [ ] Hay un proceso de revisión cuando se añaden nuevos eventos de analytics.

**Banderas rojas:**
- `analytics.identify(user.email, { name: user.fullName, email: user.email })`.
- `track('Purchase', { customerEmail: order.email, ... })`.
- PII en nombres de eventos: `track('john.doe@example.com logged in')`.

---

## C. Configuración de SDKs

#### `DATA-ANALYTICS-001` — IPs anonimizadas en configuración de SDKs de analytics
**Severidad:** high · **Tags:** `gdpr` `privacy` `analytics` · **Aplica a:** frontend · backend

La dirección IP es un dato personal bajo GDPR. Los SDKs de analytics deben
configurarse para anonimizarla antes de enviarla a servidores de terceros.

**Dónde buscar:** `**/*.{ts,js,html}`, `**/analytics*.{ts,js}`, `**/gtag*.{ts,js}`, `**/ga*.{ts,js}`, `**/matomo*.{ts,js}`
**Patrones:**
- `gtag\('config'[\s\S]{0,200}(?!anonymize_ip:\s*true)`                        # GA4 sin anonymize
- `ga\('set',\s*'anonymizeIp'`                                                 # Universal Analytics (legacy)
- `anonymize_ip:\s*true|anonymizeIp:\s*true`                                   # patrón correcto esperado
- `_paq\.push\(\['setDoNotTrack'|_paq\.push\(\['requireConsent'`               # Matomo DNT esperado
- `trackingID|measurementId|UA-\d+|G-[A-Z0-9]+`                               # IDs de GA (presencia, verificar config)
**Señal de N/A:** analytics solo con Plausible, Fathom u otras herramientas privacy-first que anonomizan por diseño.

**Verificar:**
- [ ] Google Analytics 4 tiene `anonymize_ip: true` en la configuración.
- [ ] Matomo tiene `setDoNotTrack` habilitado y `requireConsent` configurado.
- [ ] El servidor proxy de analytics (si existe) elimina la IP antes de reenviar.
- [ ] La documentación del SDK confirma que la anonimización ocurre antes de la transmisión.

**Banderas rojas:**
- `gtag('config', 'G-XXXXX')` sin `anonymize_ip: true`.
- SDK configurado con la IP completa enviada a servidores en terceros países sin adecuación.

---

## D. Inventario y gobernanza

#### `DATA-ANALYTICS-005` — Inventario de terceros con acceso a datos de usuario
**Severidad:** medium · **Tags:** `gdpr` `supply-chain` `ropa` · **Aplica a:** frontend · documentation

El ROPA (Registro de Actividades de Tratamiento) incluye todos los terceros
cargados en el frontend que reciben datos de usuarios. Solo se puede auditar
lo que está documentado.

**Dónde buscar:** `**/PRIVACY.md`, `**/privacy-policy*`, `**/data-processing*`, `**/*.{html,tsx,jsx}`, `**/package.json`, `**/index.html`
**Patrones:**
- `googletagmanager|google-analytics|hotjar|fullstory|mouseflow|clarity`        # analytics (verificar si están en inventario)
- `intercom|drift|crisp|hubspot|zendesk`                                        # chat SDKs
- `sentry|datadog-rum|newrelic.*browser`                                        # error/RUM tracking
- `stripe\.js|braintree|adyen`                                                  # payment SDKs (acceso a datos de pago)
- `third.?part|processor|sub.?processor|vendor`                                 # inventario esperado en docs
**Señal de N/A:** producto sin frontend (API pura sin UI).

**Verificar:**
- [ ] Existe un inventario documentado de todos los SDKs de terceros cargados en el frontend.
- [ ] El inventario especifica: proveedor, propósito, datos accedidos, base legal, país de transferencia.
- [ ] Los sub-procesadores listados tienen DPA (Data Processing Agreement) firmado.
- [ ] El inventario se revisa cuando se añade un SDK nuevo.

**Banderas rojas:**
- SDKs de terceros cargados sin estar documentados en la política de privacidad.
- Herramientas de session recording (Hotjar, FullStory) sin consentimiento explícito y sin estar en el inventario.

---

## Checklist resumen

| ID                    | Control                                                       | Severidad |
| --------------------- | ------------------------------------------------------------- | --------- |
| DATA-ANALYTICS-001    | IPs anonimizadas en SDKs de analytics                         | high      |
| DATA-ANALYTICS-002    | SDKs de tracking cargados solo tras consentimiento            | critical  |
| DATA-ANALYTICS-003    | Sin PII en eventos de analytics                               | critical  |
| DATA-ANALYTICS-004    | Pixels y beacons de terceros bajo consentimiento              | high      |
| DATA-ANALYTICS-005    | Inventario de terceros con acceso a datos de usuario          | medium    |
