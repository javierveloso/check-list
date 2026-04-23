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
