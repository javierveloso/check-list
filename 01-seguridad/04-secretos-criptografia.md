# 01 · Seguridad · Secretos y criptografía

> Gestión de secretos (storage, rotación, acceso) y uso correcto de primitivas
> criptográficas. Ver también `01-autenticacion.md` para hash de contraseñas.
>
> **Marcos de referencia:** OWASP A02:2021 · OWASP ASVS 6, 14 · NIST SP 800-131A · CWE-327, CWE-326, CWE-331, CWE-798, CWE-320.

---

## A. Gestión de secretos

#### `SEC-CRYPTO-001` — Secretos gestionados por un secret manager o vault
**Severidad:** critical · **Tags:** `cwe-798` · **Aplica a:** infra · backend

Los secretos de producción viven en un secret manager (AWS Secrets Manager, GCP
Secret Manager, Hashicorp Vault, Doppler, etc.) o en variables inyectadas por el
orquestador, nunca en archivos versionados.

**Dónde buscar:** `**/*`, `.env*`, `**/config/**`, `**/settings/**`, `docker-compose*.yml`, `**/k8s/**`, `**/.github/workflows/**`, `**/*.{tf,yml,yaml}`
**Patrones:**
- `(?i)(api[_-]?key|secret[_-]?key|password|token)\s*[:=]\s*['"][^'"\s$]{8,}['"]` # asignación literal con valor largo
- `sk-[a-zA-Z0-9]{20,}`                                                       # OpenAI / Anthropic API key
- `AKIA[0-9A-Z]{16}`                                                          # AWS access key ID
- `-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----`                      # clave privada commiteada
- `(postgres|mysql|mongodb|redis)://[^:]+:[^@\s]+@`                           # URL con credenciales
- `\.env\.production|\.env\.prod`                                             # archivo .env de prod (debe estar gitignored)
**Señal de N/A:** ninguna (este control aplica a todos los repos).

**Verificar:**
- [ ] Hay un inventario de secretos por entorno.
- [ ] Los secretos se inyectan en runtime (env vars o sidecar), no se compilan ni empaquetan.
- [ ] Existe documento de "cómo rotar cada secreto" con runbook.
- [ ] El acceso a secretos está auditado (logs de lectura).

**Banderas rojas:**
- Archivo `.env.production` commiteado.
- Secretos en variables de configuración de Terraform/CloudFormation sin `sensitive = true`.
- Secretos en repositorios de configuración (Git) sin cifrado.

---

#### `SEC-CRYPTO-002` — Rotación periódica y por compromiso
**Severidad:** high · **Aplica a:** infra · backend

Hay una política documentada de rotación de secretos, con período máximo y
procedimiento tras un compromiso o salida de un empleado.

**Dónde buscar:** `**/SECURITY.md`, `**/docs/**`, `**/runbooks/**`, `**/*.{md,tf,yml,yaml}`, `**/secrets-rotation*`
**Patrones:**
- `(?i)rotation|rotate.*(secret|key|credential)`                              # mención de rotación en docs
- `rotation_period|rotation_rules|rotate_at`                                  # campos de IaC con política
- `aws_secretsmanager_secret_rotation`                                        # Terraform rotación AWS
**Señal de N/A:** repo de proyecto sin secretos persistentes (ej: lib pura, sin credenciales propias).

**Verificar:**
- [ ] Existe plazo máximo de rotación por tipo de secreto (ej: 90d para DB, 30d para API keys críticas).
- [ ] La rotación funciona sin downtime (dos-credenciales activas durante la ventana).
- [ ] El procedimiento de revocación ante compromiso está probado.

**Banderas rojas:**
- Credenciales con años sin rotar.
- Procedimiento de rotación "manual, sin registro".

---

#### `SEC-CRYPTO-003` — Acceso a secretos por principio de mínimo privilegio
**Severidad:** high · **Aplica a:** infra

Solo los servicios/procesos/personas que realmente necesitan un secreto tienen
acceso a él.

**Dónde buscar:** `**/*.{tf,yml,yaml,json}`, `**/iam/**`, `**/policies/**`, `**/k8s/**`, `**/.aws/**`
**Patrones:**
- `secretsmanager:GetSecretValue.*Resource.*\*`                               # IAM con acceso a todos los secretos
- `"Resource"\s*:\s*"arn:aws:secretsmanager:[^"]*\*"`                          # mismo patrón ARN
- `roles/secretmanager\.admin|roles/secretmanager\.secretAccessor.*allUsers`  # GCP Secret Manager amplio
- `data\s+"vault_generic_secret"`                                             # Terraform que lee secretos — verificar scope
**Señal de N/A:** repo sin IaC ni manifests de cloud (no aplica revisión IAM/RBAC sobre secretos).

**Verificar:**
- [ ] Los roles/IAM están limitados por secreto, no "todos los secretos a todos los servicios".
- [ ] Entornos staging/prod usan secretos distintos.
- [ ] Los desarrolladores no tienen acceso rutinario a secretos de producción.

---

## B. Secretos en el código y logs

#### `SEC-CRYPTO-010` — Escaneo automático de secretos en repositorio
**Severidad:** high · **Tags:** `supply-chain` · **Aplica a:** ci-cd

El pipeline de CI bloquea commits que contengan patrones de secretos.

**Dónde buscar:** `.github/workflows/**`, `.gitlab-ci.yml`, `.pre-commit-config.yaml`, `**/Jenkinsfile`, `**/azure-pipelines.yml`, `package.json`, `pyproject.toml`
**Patrones:**
- `gitleaks|trufflehog|detect-secrets|ggshield|talisman`                      # herramientas esperadas
- `pre-commit-hooks.*detect-secrets`                                          # hook pre-commit
- `\.gitleaksignore|\.trufflehog-ignore|\.secrets\.baseline`                  # archivos de baseline (deben existir y revisarse)
**Señal de N/A:** repo sin CI/CD configurado (proyecto local, fork experimental sin pipeline).

**Verificar:**
- [ ] Hay un escáner (gitleaks, trufflehog, detect-secrets) corriendo en pre-commit y en CI.
- [ ] Las reglas cubren patrones de los proveedores que usa la org.
- [ ] Los falsos positivos se manejan con allowlist explícito, no desactivando la herramienta.

**Banderas rojas:**
- Repo sin escáner de secretos.
- Commits antiguos con secretos sin revocar (git history conserva).

---

#### `SEC-CRYPTO-011` — Secretos redactados en logs y errores
**Severidad:** critical · **Tags:** `cwe-532`, `cwe-209` · **Aplica a:** backend · frontend

Los logs, trazas de error, y respuestas al cliente nunca contienen secretos,
tokens, contraseñas ni datos de autenticación.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/middleware/**`, `**/logger.{ts,js,py}`, `**/utils/log*`
**Patrones:**
- `log(ger)?\.(info|debug|error|warn)\([^)]*request[^.)]`                     # log del request entero
- `console\.log\([^)]*req(uest)?\b[^.)]`                                      # console.log del request
- `print\(\s*request[^.)]|print\(\s*headers\b`                                # Python print de request/headers
- `(?i)log.*\b(token|password|secret|api[_-]?key|authorization)\s*[=:]`       # logger con campo sensible
- `traceback|stack[_-]?trace.*response|res\.send\([^)]*err`                   # stack trace al cliente
- `(?i)redact|sanitize|filter[_-]?headers`                                    # uso esperado de redacción
**Señal de N/A:** la app no escribe logs ni emite errores con stack al cliente (servicio mudo, solo métricas).

**Verificar:**
- [ ] Hay una capa de sanitización/redacción en el logger (allowlist o blocklist de campos).
- [ ] Los headers `Authorization`, `Cookie`, `Set-Cookie`, `X-API-Key` se redactan antes de loggear.
- [ ] Los cuerpos de requests con password/token se sanitizan antes de loggear.
- [ ] Las trazas de excepción no incluyen variables que puedan contener secretos.

**Banderas rojas:**
- `logger.info(f"request={request}")` con request completo.
- `logger.error(f"failed with token={token}")`.
- Errores 500 que retornan stack trace al cliente.

---

## C. Algoritmos y primitivas

#### `SEC-CRYPTO-020` — Solo algoritmos criptográficos modernos
**Severidad:** critical · **Tags:** `owasp-a02`, `cwe-327` · **Aplica a:** all

No se usan algoritmos rotos o deprecados para operaciones criptográficas reales.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,cs}`, `**/crypto/**`, `**/security/**`, `**/auth/**`
**Patrones:**
- `\b(DES|3DES|TripleDES|RC4|Blowfish)\b`                                     # cifrado roto
- `hashlib\.(md5|sha1)\(|MessageDigest\.getInstance\(["'](MD5|SHA-?1)`        # hash débil
- `crypto\.createHash\(['"](md5|sha1)['"]\)`                                  # Node hash débil
- `MD4|md4`                                                                   # MD4
- `RSA.*1024|RSA.*512|generateKeyPair.*1024`                                  # RSA débil
- `PKCS1[_-]?v1[._]?5`                                                        # padding viejo (revisar contexto)
**Señal de N/A:** repo sin operaciones criptográficas (sin hashing/encrypt/sign en el código).

**Verificar:**
- [ ] **Simétrico:** AES-GCM, ChaCha20-Poly1305. No DES, 3DES, RC4, Blowfish.
- [ ] **Asimétrico:** RSA ≥ 2048 (preferible 3072/4096), ECDSA P-256+, Ed25519.
- [ ] **Hashing criptográfico:** SHA-256+, BLAKE2/3. No MD5, SHA-1.
- [ ] **Password hashing:** bcrypt/argon2/scrypt/PBKDF2 (ver SEC-AUTH-001).
- [ ] **MAC:** HMAC-SHA256+ o HKDF. No MACs triviales (hash(key||msg)).

**Banderas rojas:**
- Uso de `md5()`, `sha1()` para integridad o firma.
- `DES.new(...)`, `RC4(...)` en código.
- RSA con padding PKCS#1 v1.5 para nuevos usos (usar OAEP para encrypt, PSS para firmar).
- Construcciones caseras: `hash(key + message)` como MAC.

**Referencias:** OWASP Cryptographic Storage Cheat Sheet · NIST SP 800-131A.

---

#### `SEC-CRYPTO-021` — Modos de cifrado con autenticación (AEAD)
**Severidad:** critical · **Tags:** `cwe-327` · **Aplica a:** backend

El cifrado simétrico usa modos AEAD (GCM, ChaCha20-Poly1305). No se usan
modos sin autenticación (ECB siempre prohibido; CBC solo con HMAC explícito
y encrypt-then-MAC).

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,cs}`, `**/crypto/**`, `**/security/**`
**Patrones:**
- `(?i)AES[._/-]?ECB|MODE_ECB|"AES/ECB`                                       # ECB prohibido
- `(?i)AES[._/-]?CBC|MODE_CBC|"AES/CBC`                                       # CBC — verificar HMAC asociado
- `crypto\.createCipher\(`                                                    # Node API deprecada (sin IV explícito)
- `==\s*hmac|hmac\s*==|signature\s*==\s*expected`                             # comparación no constante
- `tag\s*==|mac\s*==`                                                         # comparación de tag con ==
**Señal de N/A:** la app no realiza cifrado simétrico propio (solo TLS por terceros).

**Verificar:**
- [ ] Cifrado con AES-GCM o ChaCha20-Poly1305 por defecto.
- [ ] Si se usa CBC/CTR, se acompaña de HMAC con encrypt-then-MAC y se documenta por qué.
- [ ] ECB prohibido para cualquier dato no uniformemente aleatorio.
- [ ] La comparación del tag de autenticación es de tiempo constante.

**Banderas rojas:**
- `Cipher.new(key, AES.MODE_ECB)`.
- Cifrado CBC sin HMAC.
- Comparaciones de MAC/tag con `==`.

---

#### `SEC-CRYPTO-022` — IV/nonce aleatorio y único por operación
**Severidad:** critical · **Tags:** `cwe-329`, `cwe-330` · **Aplica a:** backend

Los IV/nonces se generan con un CSPRNG y nunca se reutilizan con la misma clave
(especialmente crítico en GCM, donde el reuso rompe la confidencialidad y
autenticidad).

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,cs}`, `**/crypto/**`, `**/security/**`
**Patrones:**
- `iv\s*=\s*b?["']\\?x00`                                                     # IV de zeros
- `iv\s*=\s*['"][a-zA-Z0-9]{8,32}['"]`                                        # IV hardcoded literal
- `nonce\s*=\s*0|counter\s*=\s*0`                                             # nonce/counter constante
- `(?i)nonce.*timestamp|iv.*time\(\)`                                         # IV derivado de tiempo
- `os\.urandom\(|crypto\.randomBytes\(|secrets\.token_bytes\(`                # patrones esperados de IV seguro
**Señal de N/A:** la app no usa cifrado simétrico propio (sin IV/nonce que generar).

**Verificar:**
- [ ] IV/nonce por cifrado viene de `os.urandom`, `crypto.randomBytes`, `secrets.token_bytes`, o similar.
- [ ] Si se usa counter para GCM, hay lógica para evitar overlapping (y rotar la clave antes del wrap).
- [ ] Los IV no son derivados de contadores predecibles por operación.

**Banderas rojas:**
- IV hardcodeado: `b"\x00" * 16`.
- IV derivado del timestamp en baja resolución.
- Mismo IV para múltiples mensajes.

---

#### `SEC-CRYPTO-023` — Generación de aleatorios criptográficos
**Severidad:** high · **Tags:** `cwe-338`, `cwe-330` · **Aplica a:** backend · frontend

Tokens, IDs de sesión, códigos de recuperación, nonces, salt, se generan con
un CSPRNG.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/auth/**`, `**/services/**`, `**/utils/**`
**Patrones:**
- `Math\.random\(\)`                                                          # JS random no-CSPRNG
- `\brandom\.(random|randint|choice|randrange|sample)\(`                      # Python random no-CSPRNG
- `Random\(\)\.next|new\s+Random\(\)`                                         # Java/C# Random básico
- `rand\(\)|srand\(`                                                          # C-style rand
- `uuid\.uuid1\(|uuidv1\(`                                                    # UUID v1 (timestamp-based)
- `secrets\.token_|crypto\.randomBytes|SecureRandom`                          # patrones esperados (CSPRNG)
**Señal de N/A:** el código no genera tokens/IDs/secretos (todo viene de un identity provider externo).

**Verificar:**
- [ ] Uso de `secrets` (Python), `crypto.randomBytes` (Node), `SecureRandom` (Java), `crypto/rand` (Go).
- [ ] No se usa `random`/`Math.random` para secretos.
- [ ] Los tokens tienen al menos 128 bits de entropía.

**Banderas rojas:**
- `random.randint()` usado para tokens.
- `Math.random().toString(36)` como ID de sesión.
- UUID v1 (tiempo-basado) usado como token secreto.

---

#### `SEC-CRYPTO-024` — Derivación de claves con KDF apropiado
**Severidad:** high · **Aplica a:** backend

Cuando se deriva material criptográfico (clave de cifrado desde password,
claves por tenant), se usa un KDF estándar.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/crypto/**`, `**/security/**`, `**/auth/**`
**Patrones:**
- `key\s*=\s*sha\d+\(\s*password|key\s*=\s*hashlib\.\w+\(\s*password`         # password→clave por hash directo
- `key\s*=\s*password\.encode|key\s*=\s*bytes\(\s*password`                   # password usado como clave directa
- `Cipher\([^)]*key\s*=\s*password`                                           # cifrado con password sin KDF
- `pbkdf2|argon2|scrypt|HKDF|hkdf`                                            # patrones esperados de KDF
- `iterations\s*=\s*\d{1,4}\b`                                                # PBKDF2 con iteraciones bajas
**Señal de N/A:** el código no deriva claves criptográficas (sin KDF necesario).

**Verificar:**
- [ ] Password → clave: argon2id / scrypt / PBKDF2 con parámetros modernos.
- [ ] Clave raíz → subclaves: HKDF con contexto por propósito.
- [ ] Cada propósito tiene su subclave, no se reutiliza la misma clave para múltiples usos.

**Banderas rojas:**
- Usar el password directamente como clave AES.
- Truncar `sha256(password)` como clave.
- Una sola clave para firmar y cifrar.

---

## D. Datos en reposo y en tránsito

#### `SEC-CRYPTO-030` — TLS obligatorio y moderno en producción
**Severidad:** critical · **Tags:** `owasp-a02` · **Aplica a:** infra · backend

Todo tráfico externo se cifra con TLS 1.2+. HTTP simple no se sirve en
producción, excepto para redireccionar a HTTPS.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf,yml,yaml,tf}`, `**/nginx.conf`, `**/k8s/**`, `**/ingress/**`
**Patrones:**
- `verify\s*=\s*False|rejectUnauthorized:\s*false|InsecureSkipVerify:\s*true` # validación TLS desactivada
- `ssl_protocols\s+[^;]*(SSLv3|TLSv1(?!\.[23]))`                              # nginx con TLS antiguo
- `MinTLSVersion.*TLS1[._]?0|MinTLSVersion.*TLS1[._]?1`                       # TLS mínimo 1.0/1.1
- `http://[^/'"\s]*\.(com|net|org|io|cl|es)`                                  # URLs http hardcoded a producción
- `disable_warnings\(.*InsecureRequestWarning`                                # silenciar warning de TLS
**Señal de N/A:** servicio interno-only sin tráfico cruzando red no confiable (mTLS u overlay manejan TLS fuera del proceso).

**Verificar:**
- [ ] TLS 1.2 mínimo, TLS 1.3 preferido. SSLv3, TLS 1.0/1.1 deshabilitados.
- [ ] Cipher suites modernas (AEAD; Forward Secrecy — ECDHE).
- [ ] Certificados renovados automáticamente; alerta antes de expirar.
- [ ] HSTS habilitado (ver `05-headers-http.md`).
- [ ] Las APIs internas también usan TLS (mTLS si pasan por redes no confiables).

**Banderas rojas:**
- `InsecureRequestWarning` desactivado en clientes.
- `verify=False` en clientes HTTP de producción.
- Certificados autofirmados en producción sin justificación.

---

#### `SEC-CRYPTO-031` — Datos sensibles cifrados en reposo
**Severidad:** high · **Aplica a:** data · infra

Datos sensibles (PII, credenciales de terceros, tokens de OAuth a servicios
externos, datos de salud/financieros) se cifran a nivel de campo o disco.

**Dónde buscar:** `**/*.{tf,yml,yaml,sql,prisma}`, `**/migrations/**`, `**/models/**`, `**/k8s/**`
**Patrones:**
- `(oauth_token|refresh_token|access_token)\s+(VARCHAR|TEXT)`                 # token guardado como texto
- `storage_encrypted\s*=\s*false`                                             # Terraform RDS sin cifrado
- `encryption_at_rest|TDE|TransparentDataEncryption|kms_key_id`               # patrones esperados de cifrado
- `backup.*encryption\s*=\s*false`                                            # backup sin cifrar
**Señal de N/A:** la app no almacena datos sensibles (solo datos públicos/efímeros).

**Verificar:**
- [ ] Los disks/volúmenes de BD están cifrados (LUKS, EBS encryption, TDE).
- [ ] Campos especialmente sensibles están cifrados a nivel de columna con clave gestionada por KMS.
- [ ] Las claves de cifrado NO están junto a los datos cifrados.
- [ ] Los backups están cifrados con su propio key wrapping.

**Banderas rojas:**
- Tokens de OAuth almacenados en texto plano en BD.
- Backups sin cifrar expuestos a almacenamiento de objetos público.

---

#### `SEC-CRYPTO-032` — No se almacenan datos que no deberían guardarse
**Severidad:** critical · **Aplica a:** data

No se almacenan CVVs, tracks de tarjetas, contraseñas (ver SEC-AUTH-001),
respuestas a preguntas secretas en plano.

**Dónde buscar:** `**/*.{sql,prisma,ts,js,py,go,java,rb}`, `**/migrations/**`, `**/models/**`, `**/dto/**`
**Patrones:**
- `(?i)\b(cvv|cvc|cvv2|card[_-]?verification)\b`                              # CVV — nunca debe persistirse
- `(?i)\b(track1|track2|magstripe|pan_full)\b`                                # tracks de tarjeta
- `(?i)card[_-]?number\s*(VARCHAR|TEXT|String)`                               # PAN como columna libre (debe ser tokenizado)
- `(?i)security[_-]?question[_-]?answer\b.*(VARCHAR|TEXT)`                    # respuesta a pregunta secreta en claro
**Señal de N/A:** la app no maneja datos de pago ni preguntas de seguridad (solo dominios neutros).

**Verificar:**
- [ ] Nunca se guarda el CVV (PCI-DSS 3.2.2 Req 3.2).
- [ ] Datos de tarjeta se manejan vía proveedor PCI-compliant (token, no PAN bruto).
- [ ] Solo se almacena lo necesario para el caso de uso.

---

## E. Firmas y verificación

#### `SEC-CRYPTO-040` — Verificación de firma antes de confiar en el contenido
**Severidad:** critical · **Aplica a:** backend

Webhooks, mensajes entre servicios, tokens firmados: se verifica la firma
antes de procesar el contenido.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/webhooks/**`, `**/handlers/**`, `**/integrations/**`, `**/services/**`
**Patrones:**
- `(?i)webhook|stripe|github|slack|twilio`                                    # localizar handlers de webhook
- `signature\s*==|expected\s*==\s*signature|hmac\s*==`                        # comparación no constante
- `crypto\.timingSafeEqual|hmac\.compare_digest|MessageDigest\.isEqual`       # comparación segura esperada
- `req(uest)?\.body[\s\S]*?verify(Signature|Hmac)`                            # ver orden: parse antes de verify
- `x-signature|x-hub-signature|stripe-signature`                              # headers de firma
**Señal de N/A:** la app no recibe webhooks ni mensajes firmados (sin entidades externas que envíen payloads autenticados).

**Verificar:**
- [ ] Webhooks entrantes validan la firma HMAC con el secreto compartido, antes de parsear el body.
- [ ] La comparación de firmas es en tiempo constante.
- [ ] Se valida timestamp para prevenir replay (ventana de pocos minutos).
- [ ] Clock skew y replay protection documentados.

**Banderas rojas:**
- Handler de webhook que procesa el body y al final verifica (demasiado tarde).
- `if signature != expected:` (comparación no constante).
- Sin validación de timestamp → replay attacks posibles.

---

#### `SEC-CRYPTO-041` — Pinning/validación de certificados en conexiones salientes
**Severidad:** medium · **Aplica a:** backend

Para conexiones críticas a servicios externos, se considera pinning o al menos
validación estricta del certificado.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/clients/**`, `**/integrations/**`, `**/services/**`, `**/http/**`
**Patrones:**
- `verify\s*=\s*False|rejectUnauthorized:\s*false`                            # validación TLS off en cliente
- `InsecureSkipVerify:\s*true`                                                # Go cliente TLS off
- `TrustManager.*checkServerTrusted.*\{\s*\}`                                 # Java TrustManager nulo
- `ssl_context\.check_hostname\s*=\s*False`                                   # Python check_hostname off
- `pin(ned)?_(certificates?|fingerprint)|certificate[_-]?pin`                 # pinning explícito esperado
**Señal de N/A:** la app no hace conexiones HTTPS salientes a APIs críticas.

**Verificar:**
- [ ] Las conexiones TLS salientes validan el certificado (no `verify=False`).
- [ ] Si hay pinning, se documenta el procedimiento de rotación.
- [ ] Se alerta ante cambio inesperado de certificado en endpoints críticos.

---

## Checklist resumen

| ID                 | Control                                                | Severidad |
| ------------------ | ------------------------------------------------------ | --------- |
| SEC-CRYPTO-001     | Secret manager / vault                                 | critical  |
| SEC-CRYPTO-002     | Rotación de secretos                                   | high      |
| SEC-CRYPTO-003     | Acceso mínimo privilegio a secretos                    | high      |
| SEC-CRYPTO-010     | Escaneo automático de secretos                         | high      |
| SEC-CRYPTO-011     | Secretos redactados en logs                            | critical  |
| SEC-CRYPTO-020     | Algoritmos modernos únicamente                         | critical  |
| SEC-CRYPTO-021     | Cifrado AEAD                                           | critical  |
| SEC-CRYPTO-022     | IV/nonce único por operación                           | critical  |
| SEC-CRYPTO-023     | CSPRNG para tokens/IDs                                 | high      |
| SEC-CRYPTO-024     | KDF apropiado                                          | high      |
| SEC-CRYPTO-030     | TLS 1.2+ en producción                                 | critical  |
| SEC-CRYPTO-031     | Cifrado en reposo de datos sensibles                   | high      |
| SEC-CRYPTO-032     | No almacenar lo que no debe                            | critical  |
| SEC-CRYPTO-040     | Verificación de firma antes de procesar                | critical  |
| SEC-CRYPTO-041     | Validación de certs en clientes salientes              | medium    |
