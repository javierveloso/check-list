# 02 · API REST · Protocolos en tiempo real

> Seguridad y fiabilidad de comunicaciones persistentes: WebSocket, Server-Sent Events
> (SSE) y gRPC streaming. Los riesgos difieren del modelo request/response clásico
> porque la conexión vive en el tiempo y el estado es implícito.
>
> **Marcos de referencia:** OWASP API Security Top 10 · RFC 6455 (WebSocket) · RFC 8441 · gRPC Security.

---

## A. Autenticación y autorización

#### `API-RT-001` — Autenticación en el handshake WebSocket/SSE
**Severidad:** critical · **Tags:** `websocket` `security` · **Aplica a:** backend

La autenticación se verifica durante el handshake inicial, antes de establecer
la conexión. Los protocolos en tiempo real no tienen el mecanismo de auth por
header automático de HTTP tras el upgrade.

**Dónde buscar:** `**/*.{js,ts,py,go,java,cs,rb}`, `**/ws*.{js,ts}`, `**/socket*.{js,ts}`, `**/gateway*.{js,ts}`, `**/hub*.cs`
**Patrones:**
- `new WebSocket\(.*\)(?![\s\S]{0,200}token|auth)`                             # cliente sin token en URL/header
- `ws\.on\(['"]connection['"][\s\S]{0,300}(?!verif|auth|token|jwt)`            # handler sin verificación visible
- `EventSource\(['"][^'"]+['"]\)(?![\s\S]{0,100}withCredentials)`              # SSE sin credenciales
- `upgrade.*websocket|101 Switching`                                            # upgrade HTTP (verificar auth antes)
- `req\.headers\[['"]authorization['"]\]|verifyToken|authenticate`             # patrón correcto esperado
**Señal de N/A:** endpoint de tiempo real solo para datos públicos sin autenticación requerida (ej: ticker de mercado público).

**Verificar:**
- [ ] El token se verifica antes de completar el handshake (no después de establecida la conexión).
- [ ] Se acepta token via query param (`?token=...`) o via subprotocolo, con validación robusta.
- [ ] La conexión se rechaza (código 401/403) si el token es inválido o expirado.
- [ ] Los tokens en URLs se rotan frecuentemente (vida corta) para evitar leakage en logs.

**Banderas rojas:**
- Handshake que completa sin verificar ninguna credencial.
- Token pasado solo después del upgrade en un mensaje de la aplicación.
- Aceptar conexiones sin auth y luego enviar datos sensibles.

---

#### `API-RT-002` — Autorización evaluada por canal o evento, no solo en conexión
**Severidad:** high · **Tags:** `websocket` `security` · **Aplica a:** backend

La autenticación inicial no garantiza acceso a todos los canales o tipos de
mensajes. La autorización se verifica por operación.

**Dónde buscar:** `**/*.{js,ts,py,go,java,cs,rb}`, `**/ws*.{js,ts}`, `**/socket*.{js,ts}`, `**/channel*.{js,ts}`
**Patrones:**
- `socket\.join\(|channel\.subscribe\(`                                         # suscripción a canal (verificar auth)
- `ws\.on\(['"]message['"]\s*,[\s\S]{0,500}(?!authz|authorize|canAccess|hasPermission)` # handler sin check visible
- `room\s*=\s*data\.room|channel\s*=\s*req\.body\.channel`                     # canal del cliente (verificar ownership)
- `hasPermission|canSubscribe|authorize\(`                                      # patrones correctos esperados
**Señal de N/A:** protocolo de tiempo real sin canales ni operaciones diferenciadas (un único stream público).

**Verificar:**
- [ ] Al unirse a un canal/room, se verifica que el usuario tiene acceso a ese canal.
- [ ] Los mensajes que modifican estado verifican permisos de escritura del usuario.
- [ ] El ID de canal no es predecible o no es suficiente para obtener acceso (anti-IDOR).
- [ ] La autorización se re-evalúa si el contexto del usuario cambia (revocación de permisos).

**Banderas rojas:**
- `socket.join(data.room)` sin verificar que el usuario tiene acceso a ese room.
- Autorización evaluada solo en el handshake y asumida permanente.

---

## B. Rate limiting y disponibilidad

#### `API-RT-003` — Rate limiting por conexión y por usuario
**Severidad:** high · **Tags:** `websocket` `dos` `cwe-770` · **Aplica a:** backend

Sin rate limiting, un cliente puede inundar el servidor con mensajes o con
conexiones simultáneas, causando DoS.

**Dónde buscar:** `**/*.{js,ts,py,go,java,cs,rb}`, `**/ws*.{js,ts}`, `**/gateway*.{js,ts}`, `**/nginx*.conf`, `**/haproxy*.cfg`
**Patrones:**
- `throttle|rateLimit|rate_limit|messageCount|msgCount`                         # rate limiting esperado
- `ws\.on\(['"]message['"]\s*,(?![\s\S]{0,500}limit|throttle|count)`           # handler sin rate limit visible
- `limit_conn\s+\w+|limit_req\s+zone`                                          # Nginx connection/request limiting
- `leaky.bucket|token.bucket|sliding.window`                                   # algoritmos de rate limit
**Señal de N/A:** protocolo de tiempo real de solo lectura sin mensajes entrantes del cliente.

**Verificar:**
- [ ] Hay un límite de mensajes por segundo por conexión (ej: máximo 10 msg/s).
- [ ] Hay un límite de conexiones simultáneas por usuario/IP.
- [ ] El servidor cierra la conexión ante abuso sostenido.
- [ ] El rate limiting aplica también a reconexiones rápidas (backoff forzado).

**Banderas rojas:**
- Handler de mensajes sin ningún mecanismo de throttling.
- Sin límite en el número de conexiones simultáneas por IP.

---

#### `API-RT-006` — Límite de conexiones simultáneas por usuario/IP
**Severidad:** high · **Tags:** `websocket` `dos` · **Aplica a:** backend · infra

Un usuario o IP no puede abrir un número ilimitado de conexiones paralelas.

**Dónde buscar:** `**/*.{js,ts,py,go,java,cs,rb}`, `**/nginx*.conf`, `**/haproxy*.cfg`, `**/gateway*.{js,ts}`
**Patrones:**
- `limit_conn\s+\w+\s+\d+`                                                     # Nginx limit_conn
- `maxConnections|max_connections|connectionLimit`                              # límite en código
- `connections\.get\(userId\)|connectionMap\[ip\]`                             # tracking por usuario/IP esperado
- `ws\.server\.clients\.size`                                                  # conteo de clients (verificar límite)
**Señal de N/A:** servicio sin estado de conexión persistente (SSE de solo salida con ningún estado por cliente).

**Verificar:**
- [ ] Se rastrea el número de conexiones activas por usuario y por IP.
- [ ] Se rechaza la conexión (o se cierra la más antigua) cuando se supera el límite.
- [ ] El límite está configurado en el proxy/LB además del código (defensa en profundidad).

**Banderas rojas:**
- Sin tracking de conexiones por usuario; cualquiera puede abrir miles de sockets.

---

## C. Fiabilidad y resiliencia

#### `API-RT-004` — Reconexión con backoff exponencial y jitter
**Severidad:** medium · **Tags:** `websocket` `resilience` · **Aplica a:** frontend · backend

Si la conexión se pierde, el cliente no reintenta inmediatamente en loop sino
con backoff creciente y jitter aleatorio para evitar thundering herd.

**Dónde buscar:** `**/*.{js,ts}`, `**/ws*.{js,ts}`, `**/socket*.{js,ts}`, `**/reconnect*.{js,ts}`
**Patrones:**
- `reconnect|onclose[\s\S]{0,300}setTimeout`                                   # reconexión en onclose
- `setTimeout.*reconnect|setInterval.*reconnect`                               # reintento periódico (verificar backoff)
- `Math\.random\(\)|jitter|exponential`                                        # jitter esperado
- `reconnectDelay\s*\*=\s*\d+|delay\s*\*=\s*2`                                 # backoff multiplicativo esperado
- `new WebSocket\(.*\)[\s\S]{0,50}onclose`                                     # conexión con handler de cierre
**Señal de N/A:** cliente sin lógica de reconexión (conexión única, no persistente).

**Verificar:**
- [ ] El primer reintento tiene un delay inicial (ej: 1s).
- [ ] Los reintentos sucesivos aumentan exponencialmente (ej: 1s, 2s, 4s, 8s...) hasta un máximo.
- [ ] Se añade jitter aleatorio (`delay * (0.5 + Math.random() * 0.5)`) para evitar reconexiones sincronizadas.
- [ ] Hay un número máximo de reintentos antes de notificar al usuario.

**Banderas rojas:**
- `onclose: () => setTimeout(connect, 1000)` — reintento fijo sin backoff.
- Reconexión inmediata sin delay al detectar cierre.

---

#### `API-RT-005` — Heartbeat/ping-pong con timeout de desconexión
**Severidad:** medium · **Tags:** `websocket` · **Aplica a:** backend

El servidor detecta conexiones zombie (cliente desaparecido sin close frame)
via ping-pong y libera recursos a tiempo.

**Dónde buscar:** `**/*.{js,ts,py,go,java,cs,rb}`, `**/ws*.{js,ts}`, `**/gateway*.{js,ts}`
**Patrones:**
- `ping\s*\(|ws\.ping\(|send.*ping|heartbeat`                                  # heartbeat esperado
- `isAlive|pong|lastSeen|lastPing`                                             # tracking de liveness
- `setInterval.*ping|pingInterval|pingTimeout`                                 # timer de heartbeat
- `ws\.terminate\(\)|connection\.close\(`                                       # cierre por timeout
**Señal de N/A:** SSE de solo salida donde el servidor puede detectar desconexión via señal de escritura fallida.

**Verificar:**
- [ ] El servidor envía ping frames periódicamente (ej: cada 30s).
- [ ] Si no se recibe pong en un timeout (ej: 10s), la conexión se termina.
- [ ] Los recursos del servidor (memoria, handles) se liberan al terminar la conexión.
- [ ] El mecanismo funciona detrás de proxies que podrían mantener el TCP abierto.

**Banderas rojas:**
- Sin mecanismo de heartbeat: conexiones zombie acumulan memoria indefinidamente.
- Servidor que solo detecta desconexiones al intentar escribir.

---

## D. Validación de mensajes

#### `API-RT-007` — Schemas de mensajes validados en entrada y salida
**Severidad:** high · **Tags:** `websocket` `validation` · **Aplica a:** backend

Cada mensaje recibido se valida contra un schema antes de procesarse. Sin esto,
el protocolo en tiempo real es un vector de inyección equivalente a un endpoint
REST sin validación.

**Dónde buscar:** `**/*.{js,ts,py,go,java,cs,rb}`, `**/ws*.{js,ts}`, `**/socket*.{js,ts}`, `**/gateway*.{js,ts}`
**Patrones:**
- `JSON\.parse\(data\)(?![\s\S]{0,300}validat|schema|zod|joi|yup)`            # parse sin validación
- `ws\.on\(['"]message['"]\s*,\s*\([\s\S]{0,500}JSON\.parse(?![\s\S]{0,200}validat))` # message handler sin schema
- `zod\.parse|joi\.validate|schema\.validate|ajv\.validate`                    # validación esperada
- `typeof\s+msg\.|msg\?\.type|msg\?\.action`                                  # duck-typing (incompleto)
**Señal de N/A:** protocolo binario propio con validación nativa en el codec (ej: Protobuf con tipos forzados).

**Verificar:**
- [ ] Todos los mensajes entrantes se validan contra un schema (Zod, Joi, AJV, Pydantic, etc.).
- [ ] Los campos desconocidos se descartan o se rechazan.
- [ ] Se aplican límites de tamaño máximo de mensaje.
- [ ] Los mensajes inválidos devuelven un error al cliente y se registran.

**Banderas rojas:**
- `const data = JSON.parse(event.data)` seguido de acceso directo a propiedades sin validación.
- Sin límite de tamaño de mensaje (vector de DoS por mensaje gigante).

---

## Checklist resumen

| ID          | Control                                                        | Severidad |
| ----------- | -------------------------------------------------------------- | --------- |
| API-RT-001  | Autenticación en el handshake WebSocket/SSE                    | critical  |
| API-RT-002  | Autorización por canal o evento                                | high      |
| API-RT-003  | Rate limiting por conexión y por usuario                       | high      |
| API-RT-004  | Reconexión con backoff exponencial y jitter                    | medium    |
| API-RT-005  | Heartbeat/ping-pong con timeout de desconexión                 | medium    |
| API-RT-006  | Límite de conexiones simultáneas por usuario/IP                | high      |
| API-RT-007  | Schemas de mensajes validados en entrada y salida              | high      |
