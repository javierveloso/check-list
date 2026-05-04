# 01 · Seguridad · Autorización

> Controles sobre **qué** puede hacer una identidad autenticada (permisos, alcance,
> aislamiento entre tenants).
>
> **Marcos de referencia:** OWASP API1:2023 (BOLA), API3:2023 (BOPLA), OWASP A01:2021 · CWE-285, CWE-639, CWE-732.

---

## A. Control de acceso básico

#### `SEC-AUTHZ-001` — Cada endpoint exige autenticación por defecto
**Severidad:** critical · **Tags:** `owasp-api5`, `cwe-306` · **Aplica a:** backend

La política por defecto debe ser **deny** (autenticación requerida). Las rutas
públicas se marcan explícitamente con un allowlist.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,cs}`, `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/middleware/**`, `**/main.{ts,js,py}`, `**/app.{ts,js,py}`
**Patrones:**
- `@(Public|AllowAnonymous|SkipAuth|NoAuth)\b`                                # decorador que abre ruta sin auth
- `(?i)permit_?all\(\)|anonymous\s*=\s*true`                                  # config Spring/Django que abre todo
- `app\.(get|post|put|delete|patch)\([^,)]+,\s*(?!.*auth).*=>\s*\{`           # ruta Express sin middleware auth
- `//\s*TODO.*auth|//\s*FIXME.*auth`                                          # auth pendiente
- `passthrough|allow_unauthenticated|skip_authentication`                     # bypass declarado
**Señal de N/A:** repo no expone HTTP/RPC (lib pura, CLI, worker sin endpoints).

**Verificar:**
- [ ] Existe middleware / guard global que bloquea acceso sin autenticación.
- [ ] Las rutas públicas están en un allowlist explícito (login, healthcheck, docs públicas).
- [ ] Agregar una ruta nueva sin anotaciones la hace privada por omisión, no pública.

**Banderas rojas:**
- Ruta nueva expuesta sin decorador de autenticación en frameworks donde eso es opcional.
- Comentarios `// TODO: add auth` en rutas productivas.
- Middleware de auth aplicado por pattern matching frágil (whitelist por prefijo).

---

#### `SEC-AUTHZ-002` — Autorización evaluada en cada request (nunca solo en frontend)
**Severidad:** critical · **Tags:** `owasp-a01`, `cwe-602` · **Aplica a:** backend · frontend

La decisión de permitir o no una operación se toma en el servidor, basada en la
identidad y el recurso. El frontend puede ocultar botones por UX pero nunca es
la fuente de verdad.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/controllers/**`, `**/handlers/**`, `**/services/**`, `**/routes/**`
**Patrones:**
- `req(uest)?\.body\.(role|isAdmin|is_admin|userId|user_id|tenantId|owner_id|permissions)` # campo privilegiado leído del body
- `req(uest)?\.(query|params)\.(role|isAdmin|user_id|tenant_id)`              # mismo, vía query/params
- `request\.(json|data|POST)\[['"](role|is_admin|user_id|owner)`              # Python equivalente
- `headers\[['"]?(x-)?role['"]?\]|headers\.get\(['"](x-)?role`                # rol leído de header arbitrario
- `if\s+(user|payload)\.role\s*==\s*['"]admin`                                # check después de mutación, revisar contexto
**Señal de N/A:** ningún endpoint server-side (SPA estática sin backend propio).

**Verificar:**
- [ ] Ningún endpoint confía en campos `role`, `is_admin`, `can_edit` enviados por el cliente.
- [ ] Los permisos se derivan de la sesión/token verificado y de la BD.
- [ ] Las comprobaciones ocurren ANTES de cualquier efecto (query, escritura, llamada externa).

**Banderas rojas:**
- Lectura de `request.body.user_role` o equivalente como fuente de autorización.
- Frontend que esconde UI admin pero la ruta API está abierta.
- "Security through obscurity": URLs no documentadas sin protección real.

---

## B. IDOR y aislamiento por dueño

#### `SEC-AUTHZ-010` — Los recursos se filtran por el usuario autenticado (anti-IDOR)
**Severidad:** critical · **Tags:** `owasp-api1`, `cwe-639`, `idor` · **Aplica a:** backend

Las queries que retornan o mutan un recurso deben incluir el ID del propietario
(usuario, tenant, org) en el `WHERE`, no basarse solo en el ID del recurso.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/repositories/**`, `**/services/**`, `**/models/**`, `**/dao/**`, `**/*.{sql,prisma}`
**Patrones:**
- `findOne\(\s*\{\s*where:\s*\{\s*id\s*[:}]`                                  # Prisma/TypeORM sin owner
- `\.(update|delete|destroy)\(\s*\{\s*where:\s*\{\s*id\s*[:}]`                # mutación sin owner
- `findByPk\(|findById\(|get\(\s*pk=`                                         # patrones get-by-id sin scope
- `SELECT\s+.+\s+FROM\s+\w+\s+WHERE\s+id\s*=\s*[:?$]\d?\s*(?!.*(owner|tenant|user))` # SQL sin owner
- `Model\.objects\.get\(\s*id\s*=`                                            # Django sin filter por user
- `\.filter\(\s*id__in\s*=\s*request`                                         # bulk sin scope owner
**Señal de N/A:** la app no tiene noción de "dueño" del recurso (recursos globales públicos solamente).

**Verificar:**
- [ ] Toda query de tipo `GET /resource/{id}` filtra por `WHERE id = ? AND owner_id = ?`.
- [ ] En updates/deletes, si el recurso no pertenece al usuario se retorna 404 (no 403, para no confirmar existencia).
- [ ] Los bulk operations también aplican el filtro (no solo los individuales).
- [ ] Si hay multi-tenancy, todo query incluye `tenant_id` en el scope.

**Banderas rojas:**
- `SELECT * FROM docs WHERE id = :id` sin restricción de propietario.
- `db.doc.update({where: {id}})` sin chequeo de dueño.
- Acceso a recurso ajeno con ID incremental y sin control.
- IDs secuenciales visibles en URLs (facilita enumeración — usar UUID).

**Referencias:** OWASP API1:2023 BOLA.

---

#### `SEC-AUTHZ-011` — IDs de recursos no-enumerables
**Severidad:** medium · **Tags:** `enumeration`, `idor-defense-in-depth` · **Aplica a:** backend

Los identificadores expuestos públicamente deben ser UUID/ULID/opacos, no
incrementales, para evitar enumeración aunque existan bugs de autorización.

**Dónde buscar:** `**/*.{sql,prisma}`, `**/migrations/**`, `**/models/**`, `**/schema.{prisma,sql,graphql}`, `**/entity/**`
**Patrones:**
- `id\s+(SERIAL|BIGSERIAL|INT(EGER)?\s+AUTO_INCREMENT|INT\s+IDENTITY)`        # PK autoincremental SQL
- `@PrimaryGeneratedColumn\(\s*\)|@PrimaryGeneratedColumn\(['"]increment`     # TypeORM increment
- `id\s+Int\s+@id\s+@default\(autoincrement\(\)\)`                            # Prisma autoincrement
- `models\.AutoField|models\.BigAutoField`                                    # Django auto PK
- `/(invoices|orders|users|documents)/\$\{[^}]*id[^}]*\}`                     # URL con id incremental visible
**Señal de N/A:** no existen IDs expuestos en URLs/APIs públicas (todo via slug, hash o lookup interno).

**Verificar:**
- [ ] IDs de recursos sensibles expuestos en URLs son UUID v4, ULID o similar.
- [ ] Si se usan IDs incrementales internamente, se exponen hashids/surrogate keys.

**Banderas rojas:**
- URLs tipo `/invoices/103421` en un sistema con multi-tenancy.
- IDs tipo autoincrement visibles en APIs públicas.

---

## C. Control de acceso basado en roles / atributos

#### `SEC-AUTHZ-020` — Permisos centralizados y reutilizables
**Severidad:** high · **Aplica a:** backend

Las decisiones de autorización viven en un módulo/middleware reutilizable, no
duplicadas en cada endpoint.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/controllers/**`, `**/handlers/**`, `**/services/**`, `**/guards/**`, `**/policies/**`
**Patrones:**
- `if\s+(user|current_user|ctx\.user)\.role\s*[!=]=\s*['"]`                   # check de rol inline en handler
- `if\s+(not\s+)?(is_admin|isAdmin|user\.admin)\b`                            # mismo
- `request\.user\.has_perm\(['"][^'"]+['"]\)`                                 # check repetido (validar centralización)
- `\@(Roles|HasRole|RequiresPermission|Authorize)\(`                          # decoradores declarativos esperados
- `\@UseGuards\(|\@PreAuthorize\(`                                            # guards declarativos esperados
**Señal de N/A:** repo sin lógica de autorización (solo authn binaria pasa/no pasa, sin permisos diferenciados).

**Verificar:**
- [ ] Existe un componente centralizado (policy engine, guards, dependencies) para checks de permiso.
- [ ] Los endpoints declaran el permiso requerido de forma declarativa (decorador, atributo, metadata).
- [ ] Los roles/permisos están documentados (matriz de permisos) y versionados.

**Banderas rojas:**
- `if user.role == "admin"` repetido en decenas de handlers.
- Lógica de permisos mezclada con lógica de negocio en el mismo método.

---

#### `SEC-AUTHZ-021` — Principio de mínimo privilegio
**Severidad:** high · **Tags:** `least-privilege` · **Aplica a:** backend

Usuarios, tokens de servicio y roles tienen solo los permisos estrictamente
necesarios para su función.

**Dónde buscar:** `**/*.{tf,yml,yaml,json}`, `**/iam/**`, `**/policies/**`, `**/k8s/**`, `**/.aws/**`, `**/database.{yml,yaml,json}`, `.env*`, `**/config/**`
**Patrones:**
- `(?i)(DATABASE_URL|DB_USER).*[:=]\s*['"]?(root|postgres|sa|admin)\b`        # usuario BD privilegiado
- `"Action"\s*:\s*"\*"|"Resource"\s*:\s*"\*"`                                 # IAM AWS comodín
- `AdministratorAccess|PowerUserAccess`                                        # políticas AWS muy amplias
- `roles/(owner|editor)\b`                                                     # GCP IAM amplio
- `cluster-admin|ClusterRoleBinding.*subject.*system:`                         # K8s rol amplio
- `GRANT\s+ALL\s+PRIVILEGES.*TO`                                               # SQL grant amplio
**Señal de N/A:** repo sin IaC/IAM ni manifests de cloud (proyecto de código puro sin infraestructura).

**Verificar:**
- [ ] No existe un rol "superadmin" usado como comodín en múltiples contextos.
- [ ] Los tokens de servicio/API keys tienen scopes limitados.
- [ ] Las credenciales de BD de la app tienen solo los permisos mínimos (no DDL en runtime).
- [ ] Se audita regularmente qué roles otorgan qué permisos.

**Banderas rojas:**
- Usuario de BD `root` / `postgres` / `sa` en conexiones de aplicación.
- Tokens cloud (AWS IAM) con `*:*` o `AdministratorAccess`.
- Roles que acumulan permisos históricos nunca revocados.

---

#### `SEC-AUTHZ-022` — Verificación a nivel de campo (BOPLA) cuando aplica
**Severidad:** high · **Tags:** `owasp-api3`, `bopla`, `mass-assignment` · **Aplica a:** backend

Los endpoints de escritura no deben permitir actualizar campos que el usuario no
debería tocar (ej: `role`, `is_verified`, `balance`).

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/controllers/**`, `**/services/**`, `**/handlers/**`, `**/dto/**`, `**/serializers/**`
**Patrones:**
- `\.update\(\s*\*\*?(req|request)\.(body|json|data)`                         # mass-assignment Python
- `Object\.assign\(\s*\w+\s*,\s*req\.body\s*\)`                               # JS spread del body sobre modelo
- `\{\s*\.\.\.req\.body\s*\}|new\s+\w+\(\s*req\.body\s*\)`                    # spread/constructor con body
- `Model\.update\(\s*req(uest)?\.(body|json)`                                 # ORM update con body crudo
- `fields\s*=\s*['"]__all__['"]`                                              # Django serializer abierto
- `attr_accessible|permit!\(\)`                                               # Rails sin allowlist
**Señal de N/A:** no hay endpoints de update/PATCH (solo lecturas o creates con campos cerrados).

**Verificar:**
- [ ] El schema de entrada de updates excluye campos privilegiados (allowlist de campos editables).
- [ ] Los campos "internos" (timestamps, ownership, flags admin) se setean en el servidor.
- [ ] Mass-assignment está desactivado en el ORM o filtrado explícitamente.

**Banderas rojas:**
- `User.update(**request.json)` sin sanitización.
- `model.save(request.body)` donde body puede incluir `role=admin`.
- Schemas de entrada que comparten campos con modelos internos sensibles.

**Referencias:** OWASP API3:2023 BOPLA · CWE-915.

---

## D. Endpoints y superficie expuesta

#### `SEC-AUTHZ-030` — Endpoints administrativos segregados
**Severidad:** high · **Aplica a:** backend

Las rutas de administración deben requerir rol explícito y, si es posible, estar
en una superficie de red separada (subdominio restringido, red privada).

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/routes/**`, `**/controllers/**`, `**/urls.py`, `**/main.{ts,js,py}`
**Patrones:**
- `['"]/(debug|test|reset|seed|admin/reset|_internal|dev)/`                   # ruta admin/debug expuesta
- `app\.(get|post)\(['"]/(admin|internal)/`                                   # admin route — verificar guard
- `swagger|/docs|/openapi`                                                    # docs — revisar si exponen admin
- `\@RequestMapping\(['"]/admin`                                              # Spring admin route
- `path\(['"]admin/`                                                          # Django admin route
**Señal de N/A:** la app no tiene panel/funciones administrativas (todo se administra fuera del proceso, vía DB/CLI).

**Verificar:**
- [ ] Rutas `/admin/*` protegidas por rol admin + MFA.
- [ ] Endpoints de mantenimiento (migrations, flush cache) no son invocables por usuarios normales.
- [ ] No hay endpoints de debug expuestos en producción (`/debug`, `/test`, `/reset`, `/seed`).

**Banderas rojas:**
- Rutas `/dev/...` o `/_internal/...` accesibles desde internet.
- Swagger/OpenAPI UI pública con endpoints admin visibles.
- Endpoints de "reset password de cualquier usuario" sin MFA.

---

#### `SEC-AUTHZ-031` — Métodos HTTP restringidos
**Severidad:** medium · **Aplica a:** backend

Cada ruta declara explícitamente qué métodos soporta. Métodos no usados
retornan 405.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/routes/**`, `**/controllers/**`, `**/nginx.conf`, `**/*.conf`
**Patrones:**
- `app\.(all|any)\(['"]`                                                      # captura todos los métodos
- `methods=\[['"](TRACE|CONNECT)['"]`                                         # método peligroso habilitado
- `allowed_methods\s*=\s*\[?\s*['"]?\*`                                       # lista de métodos comodín
- `\@RequestMapping\(\s*\)`                                                   # Spring sin restringir verb
- `Allow:\s*.*TRACE`                                                          # header allow con TRACE
**Señal de N/A:** framework restringe verbos automáticamente y no hay rutas catch-all (router declarativo cerrado).

**Verificar:**
- [ ] Solo los métodos previstos están habilitados por ruta.
- [ ] `TRACE` y `CONNECT` deshabilitados.
- [ ] `OPTIONS` habilitado si hay CORS, sin revelar información de más.

---

## E. CORS

#### `SEC-AUTHZ-040` — Configuración CORS explícita y estricta
**Severidad:** high · **Tags:** `cwe-942` · **Aplica a:** backend

Los orígenes permitidos, métodos y headers se listan explícitamente. Nunca
comodín con credenciales.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/main.{ts,js,py}`, `**/app.{ts,js,py}`, `**/middleware/**`, `**/nginx.conf`, `**/*.conf`
**Patrones:**
- `\bcors\(\s*\{\s*origin:\s*(true|['"]\*['"])`                               # Express cors abierto
- `Access-Control-Allow-Origin['"]?\s*[:,]\s*['"]\*`                          # header comodín
- `CORS_ALLOW_ALL_ORIGINS\s*=\s*True`                                         # Django CORS abierto
- `allow_origins\s*=\s*\[?\s*['"]?\*`                                         # FastAPI/Starlette comodín
- `origin:\s*(req|request)\.headers\.origin`                                  # reflexión del Origin sin allowlist
- `Allow-Origin:\s*\*[\s\S]*?Allow-Credentials:\s*true`                       # combinación inválida
**Señal de N/A:** API consumida solo same-origin (sin CORS configurado, sin frontend cross-domain).

**Verificar:**
- [ ] `Access-Control-Allow-Origin` es una lista explícita, no `*` si se usan cookies/auth.
- [ ] `Access-Control-Allow-Methods` lista solo los métodos necesarios.
- [ ] `Access-Control-Allow-Headers` lista solo los headers necesarios.
- [ ] `Access-Control-Allow-Credentials: true` solo cuando es indispensable.
- [ ] `Access-Control-Max-Age` configurado para reducir preflights innecesarios.

**Banderas rojas:**
- `Access-Control-Allow-Origin: *` junto con `Allow-Credentials: true` (inválido y peligroso).
- Reflexión del `Origin` del request sin validación contra allowlist.

---

## F. Revocación y auditoría

#### `SEC-AUTHZ-050` — Revocación inmediata de permisos
**Severidad:** high · **Aplica a:** backend

Cuando se quita un permiso a un usuario, el efecto es inmediato — no espera a
que caduque el token.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/auth/**`, `**/services/**`, `**/middleware/**`
**Patrones:**
- `jwt\.sign\([^,)]*,[^,)]*,\s*\{[^}]*expiresIn:\s*['"]?(\d+d|\d{2,}h|\d{4,}m)` # JWT de larga vida
- `expires_in\s*[:=]\s*(86400|604800|2592000|\d{6,})`                         # expiración >= 1 día en segundos
- `(?i)permissions?\s*[:=].*payload\.|claims\.permissions`                     # permisos embebidos en token
- `cache\.(get|set)\([^,)]*permissions?[^,)]*\)`                              # cache de permisos — verificar TTL
**Señal de N/A:** sesiones server-side opacas con lookup en cada request (no JWT con claims).

**Verificar:**
- [ ] Cambiar rol / desactivar usuario invalida sesiones vivas o se verifica en cada request.
- [ ] Hay un plazo máximo de staleness documentado (ej: < 5 minutos para cambios de rol).

**Banderas rojas:**
- JWT con permisos embedded y vida de 24 h que sobreviven al cambio de rol.
- Cache de permisos sin invalidación activa.

---

#### `SEC-AUTHZ-051` — Auditoría de operaciones privilegiadas
**Severidad:** high · **Aplica a:** backend

Las acciones admin (cambios de permisos, acceso a datos de otro usuario, exports
masivos) se registran en un log inmutable o de solo append.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/audit/**`, `**/services/**`, `**/admin/**`, `**/*.{sql,prisma}`
**Patrones:**
- `\b(audit|auditLog|audit_log|AuditEvent|securityLog)\b`                     # uso esperado de logger de auditoría
- `(grant|revoke|impersonate|export|delete_user|change_role)\s*\(`            # operaciones críticas — verificar audit cerca
- `CREATE\s+TABLE\s+\w*audit`                                                 # tabla de auditoría
- `logger\.(info|warn)\(['"](admin|impersonate|grant|revoke)`                 # log de operación admin
**Señal de N/A:** la app no tiene operaciones privilegiadas auditables (sin admins, sin permisos diferenciados, sin exports).

**Verificar:**
- [ ] Se loggea quién, qué, cuándo, sobre qué recurso, resultado.
- [ ] El log es inmutable o firmado (no editable por los propios admins).
- [ ] Hay revisiones periódicas del log de auditoría.

---

## Checklist resumen

| ID                | Control                                             | Severidad |
| ----------------- | --------------------------------------------------- | --------- |
| SEC-AUTHZ-001     | Endpoints autenticados por defecto                  | critical  |
| SEC-AUTHZ-002     | Autorización en servidor (no en frontend)           | critical  |
| SEC-AUTHZ-010     | Filtros por dueño en queries (anti-IDOR)            | critical  |
| SEC-AUTHZ-011     | IDs no-enumerables                                  | medium    |
| SEC-AUTHZ-020     | Permisos centralizados                              | high      |
| SEC-AUTHZ-021     | Mínimo privilegio                                   | high      |
| SEC-AUTHZ-022     | Verificación a nivel de campo (anti-BOPLA)          | high      |
| SEC-AUTHZ-030     | Endpoints admin segregados                          | high      |
| SEC-AUTHZ-031     | Métodos HTTP restringidos                           | medium    |
| SEC-AUTHZ-040     | CORS estricto                                       | high      |
| SEC-AUTHZ-050     | Revocación inmediata de permisos                    | high      |
| SEC-AUTHZ-051     | Auditoría de operaciones privilegiadas              | high      |
