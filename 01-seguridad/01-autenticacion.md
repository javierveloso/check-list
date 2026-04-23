# 01 · Seguridad · Autenticación

> Controles de **autenticación** (verificación de identidad). No confundir con
> autorización (qué puede hacer cada identidad), que vive en `02-autorizacion.md`.
>
> **Marcos de referencia:** OWASP ASVS 2.x · OWASP API1:2023 · OWASP A07:2021 · CWE-256, CWE-287, CWE-307, CWE-798, CWE-522, CWE-384.

---

## A. Almacenamiento de credenciales

#### `SEC-AUTH-001` — Hash de contraseñas con algoritmo moderno
**Severidad:** critical · **Tags:** `owasp-a07`, `cwe-256` · **Aplica a:** backend

Las contraseñas deben almacenarse únicamente como hashes producidos por un KDF
diseñado para passwords (bcrypt, argon2id, scrypt o PBKDF2). Nunca en texto plano,
MD5, SHA-1, ni SHA-2 crudo.

**Verificar:**
- [ ] Las contraseñas no aparecen jamás en texto plano en BD, logs, archivos, ni memoria más allá del momento de hash.
- [ ] El algoritmo de hashing es bcrypt, argon2id, scrypt o PBKDF2 con parámetros recomendados.
- [ ] El factor de costo/iteraciones está alineado con las guías actuales (ej: bcrypt cost ≥ 12, argon2id m≥46 MiB).
- [ ] La comparación de hashes usa una función de tiempo constante.

**Banderas rojas:**
- Funciones de hash rápidas aplicadas directamente a passwords (MD5, SHA-1, SHA-256 sin KDF).
- Comparaciones con `==` de hashes de contraseña.
- Cost/iterations hardcodeado en 1 o valores muy bajos.
- Salts globales o vacíos; salts derivados del username sin aleatoriedad.

**Referencias:** OWASP ASVS 2.4 · NIST SP 800-63B §5.1.1.2 · CWE-256.

---

#### `SEC-AUTH-002` — Secretos nunca hardcodeados en código fuente
**Severidad:** critical · **Tags:** `cwe-798`, `supply-chain` · **Aplica a:** all

API keys, claves de firma, credenciales de BD y cualquier secreto deben cargarse
exclusivamente desde el entorno (variables de entorno, vault, secret manager).
Nunca vivir en el repositorio.

**Verificar:**
- [ ] No hay strings que parezcan tokens, API keys, o claves privadas en el código.
- [ ] Los archivos `.env`, `.env.local`, `credentials.*`, `*.pem`, `*.key` están en `.gitignore`.
- [ ] Existe un `.env.example` con nombres de variables pero sin valores reales.
- [ ] Hay escaneo de secretos en el pipeline (gitleaks, trufflehog, equivalente).

**Banderas rojas:**
- Strings largos tipo `sk-...`, `AKIA...`, `ghp_...`, `eyJ...` en diffs.
- Bloques `BEGIN PRIVATE KEY` o `BEGIN RSA PRIVATE KEY` commiteados.
- Fallback default a una API key visible: `key = os.getenv("X") or "abc123"`.
- URLs con credenciales incrustadas: `postgres://user:pass@host/db`.

**Referencias:** OWASP ASVS 14.3 · CWE-798 · CWE-259.

---

#### `SEC-AUTH-003` — Validación defensiva de secretos al arrancar
**Severidad:** high · **Aplica a:** backend

La aplicación debe negarse a arrancar (o fallar ruidosamente) si faltan secretos
obligatorios o si detecta valores inseguros por defecto.

**Verificar:**
- [ ] Existe verificación en bootstrap que aborta si faltan secretos obligatorios.
- [ ] Se rechazan valores por defecto triviales (`"changeme"`, `"secret"`, `"admin"`) en producción.
- [ ] La longitud/entropía mínima de claves de firma se valida al inicio.

**Banderas rojas:**
- `os.getenv("JWT_SECRET", "default-secret")`.
- Ausencia de checks al levantar servicio — app arranca con placeholder y sirve tráfico.

---

## B. Tokens, sesiones y cookies

#### `SEC-AUTH-010` — JWT firmado con algoritmo y clave robustos
**Severidad:** critical · **Tags:** `owasp-a02`, `cwe-347` · **Aplica a:** backend

Los tokens JWT deben estar firmados con un algoritmo asimétrico robusto
(RS256, ES256, EdDSA) o HMAC fuerte (HS256 con clave ≥ 256 bits). El servidor
debe fijar el algoritmo y rechazar cualquier otro.

**Verificar:**
- [ ] El algoritmo de firma está fijado explícitamente al decodificar; no se acepta `alg: none`.
- [ ] La clave de firma tiene al menos 256 bits de entropía y es única por entorno.
- [ ] Se valida `iss`, `aud`, `exp`, `iat` (y `nbf` si se emite) en cada request.
- [ ] El `kid` (key id) se valida si la app soporta rotación de claves.

**Banderas rojas:**
- Decodificadores permisivos: `jwt.decode(token, verify=False)`, `algorithms=["HS256","none"]`.
- Claves simétricas cortas (< 32 bytes).
- Ausencia de verificación de `aud`/`iss`.
- Uso de una sola clave HMAC para múltiples servicios.

**Referencias:** RFC 7519 · OWASP JWT Cheat Sheet · CWE-347.

---

#### `SEC-AUTH-011` — Expiración razonable y rotación de refresh tokens
**Severidad:** high · **Aplica a:** backend

Los access tokens deben ser de corta vida (minutos). Los refresh tokens, si se
usan, deben ser de un solo uso (rotación) y revocables.

**Verificar:**
- [ ] Los access tokens expiran en ~5–30 minutos.
- [ ] Los refresh tokens rotan en cada uso (el viejo queda inválido tras emitirse uno nuevo).
- [ ] Existe almacenamiento server-side de refresh tokens activos (o equivalente) para permitir revocación.
- [ ] Detección de reuso de refresh tokens (si se reutiliza uno ya rotado → revocar toda la familia).

**Banderas rojas:**
- Access tokens con expiración en horas/días sin refresh.
- Refresh tokens que no caducan nunca.
- Sin mecanismo de revocación (logout no invalida tokens emitidos).

---

#### `SEC-AUTH-012` — Almacenamiento seguro de tokens en el cliente
**Severidad:** high · **Tags:** `owasp-a07` · **Aplica a:** frontend

Los tokens no deben quedar accesibles a JavaScript si se evita, para mitigar XSS.

**Verificar:**
- [ ] Los tokens de sesión se guardan en cookies `HttpOnly`, `Secure`, `SameSite=Lax` o `Strict`, o en almacenamiento seguro del dispositivo.
- [ ] Se evita `localStorage` / `sessionStorage` para tokens con poder de autorización.
- [ ] Las cookies de sesión tienen `Path` y `Domain` lo más restrictivos posible.

**Banderas rojas:**
- `localStorage.setItem("token", ...)` para tokens de sesión.
- Cookies sin `HttpOnly`, o con `SameSite=None` sin `Secure`.
- Cookies con `Domain=.example.com` cuando solo el subdominio lo necesita.

**Referencias:** OWASP Session Management Cheat Sheet.

---

#### `SEC-AUTH-013` — Invalidación de sesión en eventos sensibles
**Severidad:** high · **Aplica a:** backend

Al cambiar credenciales, tras detectar compromiso, o en logout explícito, todas
las sesiones activas del usuario deben invalidarse.

**Verificar:**
- [ ] Cambio de contraseña invalida todas las sesiones/tokens emitidos.
- [ ] Logout global disponible y documentado.
- [ ] Cierre de sesión al detectar cambio de IP/device sospechoso (si la política lo requiere).

**Banderas rojas:**
- Cambio de password que no toca tabla de sesiones/tokens.
- Logout que solo borra la cookie local sin invalidar servidor-side.

---

#### `SEC-AUTH-014` — Cookies con flags de seguridad
**Severidad:** high · **Aplica a:** backend · frontend

Cualquier cookie que transporte sesión, CSRF token, o información sensible debe
tener `Secure`, `HttpOnly` (salvo CSRF tokens leídos por JS), y `SameSite`.

**Verificar:**
- [ ] Todas las cookies de sesión tienen `Secure` en producción.
- [ ] `SameSite=Lax` por defecto; `Strict` cuando no se necesita cross-site.
- [ ] `__Host-` o `__Secure-` prefix donde aplique.

**Banderas rojas:**
- Cookies sin flags al inspeccionar `Set-Cookie` en respuestas.
- `SameSite=None` sin justificación clara.

---

## C. Factores múltiples y autenticación fuerte

#### `SEC-AUTH-020` — MFA disponible (y obligatorio para cuentas privilegiadas)
**Severidad:** high · **Tags:** `owasp-a07` · **Aplica a:** backend

Las cuentas con permisos elevados (admin, billing, PII) deben exigir segundo factor.
El resto deben tenerlo disponible opcionalmente.

**Verificar:**
- [ ] Existe flujo de enrolamiento y verificación MFA (TOTP, WebAuthn, SMS como último recurso).
- [ ] Cuentas admin no pueden operar sin MFA habilitado.
- [ ] Los códigos OTP tienen ventana corta (30–60 s) y no se pueden reusar.
- [ ] Hay límite de intentos de verificación MFA.

**Banderas rojas:**
- Admin login con solo user+password.
- OTP aceptados aún tras expirar.
- Sin rate-limit en verificación de OTP (facilita fuerza bruta al TOTP).

---

#### `SEC-AUTH-021` — Códigos de recuperación manejados con cuidado
**Severidad:** medium · **Aplica a:** backend

Los códigos de recuperación/single-use backup codes deben almacenarse hasheados y
marcarse como usados al consumirlos.

**Verificar:**
- [ ] Recovery codes se guardan hasheados, no en texto plano.
- [ ] Cada código es de un solo uso.
- [ ] Regenerar recovery codes invalida los anteriores.

---

## D. Flujo de login

#### `SEC-AUTH-030` — Rate limiting y lockout progresivo
**Severidad:** critical · **Tags:** `cwe-307`, `owasp-api4` · **Aplica a:** backend

Los endpoints de login y verificación MFA deben tener rate limiting por IP, por
cuenta, y lockout temporal tras múltiples intentos fallidos.

**Verificar:**
- [ ] Hay límite de intentos por minuto por IP y por usuario (ej: 5–10/min).
- [ ] Hay lockout exponencial tras N fallos consecutivos (ej: 5 min, luego 15, luego 60).
- [ ] El store de rate limiting es compartido entre réplicas (Redis, BD, etc.), no in-memory local.
- [ ] El rate limit no se puede burlar cambiando `X-Forwarded-For` u otros headers.

**Banderas rojas:**
- Endpoint `/login` sin decorador/middleware de rate limit.
- Rate limiter que confía ciegamente en `X-Forwarded-For`.
- Contador en variable del proceso (no compartido), derrotable escalando.

**Referencias:** CWE-307 · OWASP ASVS 2.2.

---

#### `SEC-AUTH-031` — Mensajes de error genéricos en autenticación
**Severidad:** medium · **Tags:** `cwe-203`, `username-enumeration` · **Aplica a:** backend

Las respuestas de login, registro, y recuperación de contraseña no deben revelar
si un usuario existe.

**Verificar:**
- [ ] Respuesta de login fallida es la misma para "usuario no existe" y "password incorrecta".
- [ ] "Recuperar contraseña" responde idéntico exista o no el email.
- [ ] Los códigos de estado HTTP no diferencian entre esos casos.
- [ ] Los tiempos de respuesta no son observablemente distintos (protección contra timing attacks).

**Banderas rojas:**
- Mensajes como "Usuario no existe" vs "Contraseña incorrecta".
- 404 para user-not-found vs 401 para bad-password.
- Comparación de password solo cuando el user existe (leak por timing).

---

#### `SEC-AUTH-032` — Comparación de credenciales en tiempo constante
**Severidad:** high · **Tags:** `cwe-208`, `timing-attack` · **Aplica a:** backend

La comparación de hashes de contraseña, tokens CSRF, códigos OTP y API keys debe
ser en tiempo constante.

**Verificar:**
- [ ] Se usa una función de comparación segura (`hmac.compare_digest`, `crypto.timingSafeEqual`, equivalente).
- [ ] No se sale temprano de bucles de comparación byte-a-byte.

**Banderas rojas:**
- `if stored == provided:` en comparación de secretos.
- Loops manuales `for i in range(len(a)): if a[i] != b[i]: return False`.

---

## E. Auditoría

#### `SEC-AUTH-040` — Log de auditoría de eventos de autenticación
**Severidad:** high · **Aplica a:** backend

Todos los eventos de autenticación importantes deben quedar registrados en
logs de auditoría (con retención definida en privacidad).

**Verificar:**
- [ ] Se registra: login exitoso, login fallido, logout, cambio de password, habilitación MFA, emisión de tokens privilegiados.
- [ ] Los logs incluyen timestamp, identidad (user id, no PII innecesaria), IP, user-agent, resultado.
- [ ] Los logs NO incluyen la contraseña, el token, ni el código OTP.
- [ ] Existe alerta automática ante patrones anómalos (picos de fallos, login desde países inesperados).

**Banderas rojas:**
- `log.info(f"login attempt password={password}")` — loggeo de credenciales.
- Ausencia de logs en rutas de autenticación.

**Referencias:** OWASP ASVS 7.2 · PCI-DSS 10.

---

## Checklist resumen

| ID             | Control                                          | Severidad |
| -------------- | ------------------------------------------------ | --------- |
| SEC-AUTH-001   | Hash de contraseñas moderno                      | critical  |
| SEC-AUTH-002   | Secretos no hardcodeados                         | critical  |
| SEC-AUTH-003   | Validación de secretos al arrancar               | high      |
| SEC-AUTH-010   | JWT con algoritmo fijado                         | critical  |
| SEC-AUTH-011   | Expiración y rotación de tokens                  | high      |
| SEC-AUTH-012   | Tokens bien almacenados en el cliente            | high      |
| SEC-AUTH-013   | Invalidación de sesión en eventos sensibles      | high      |
| SEC-AUTH-014   | Cookies con flags de seguridad                   | high      |
| SEC-AUTH-020   | MFA disponible (obligatorio en admin)            | high      |
| SEC-AUTH-021   | Recovery codes hasheados y single-use            | medium    |
| SEC-AUTH-030   | Rate limit y lockout en login                    | critical  |
| SEC-AUTH-031   | Mensajes de error genéricos                      | medium    |
| SEC-AUTH-032   | Comparación en tiempo constante                  | high      |
| SEC-AUTH-040   | Log de auditoría de eventos auth                 | high      |
