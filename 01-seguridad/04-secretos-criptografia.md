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

**Verificar:**
- [ ] Los roles/IAM están limitados por secreto, no "todos los secretos a todos los servicios".
- [ ] Entornos staging/prod usan secretos distintos.
- [ ] Los desarrolladores no tienen acceso rutinario a secretos de producción.

---

## B. Secretos en el código y logs

#### `SEC-CRYPTO-010` — Escaneo automático de secretos en repositorio
**Severidad:** high · **Tags:** `supply-chain` · **Aplica a:** ci-cd

El pipeline de CI bloquea commits que contengan patrones de secretos.

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
