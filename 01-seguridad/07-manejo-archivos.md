# 01 · Seguridad · Manejo de archivos

> Controles sobre upload, download y almacenamiento de archivos.
>
> **Marcos de referencia:** OWASP A04:2021 · OWASP File Upload Cheat Sheet · CWE-434, CWE-22, CWE-73, CWE-79.

---

## A. Upload

#### `SEC-FILE-001` — Tamaño máximo verificado antes de leer en memoria
**Severidad:** high · **Tags:** `dos`, `cwe-400` · **Aplica a:** backend

Antes de consumir el body del request, se verifica el `Content-Length`. El
streaming/parsing respeta un tamaño máximo y aborta al superarlo.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/middleware/**`, `**/controllers/**`, `**/handlers/**`, `**/upload*`, `**/nginx.conf`
**Patrones:**
- `client_max_body_size\s+\d+[gG]`                                            # nginx con límite alto
- `multer\(\s*\{(?!\s*[\s\S]*?limits)`                                        # multer sin limits
- `MAX_CONTENT_LENGTH|FILE_UPLOAD_MAX_MEMORY_SIZE|MULTIPART_MAX_FILE_SIZE`    # constantes esperadas
- `\.read\(\s*\)|file\.read\(\s*\)`                                           # leer todo el body sin cap
- `request\.files\[[^\]]+\]\.read\(\s*\)`                                     # Flask read sin cap
**Señal de N/A:** la app no recibe uploads de archivos (solo JSON pequeño).

**Verificar:**
- [ ] Límite de tamaño por archivo definido y verificado.
- [ ] `Content-Length` rechaza valores excesivos antes de leer el body.
- [ ] El parseo es streaming (no "cargar todo y luego validar").
- [ ] El límite está también en el reverse proxy (nginx `client_max_body_size`, etc.).

**Banderas rojas:**
- `file = request.files["f"]; content = file.read(); if len(content) > LIMIT:` (tarde).
- Ausencia de límite en el proxy → el backend nunca recibe el body completo pero carga memoria.

---

#### `SEC-FILE-002` — Tipo de archivo validado por contenido, no solo por extensión
**Severidad:** high · **Tags:** `cwe-434` · **Aplica a:** backend

Se valida que el archivo sea del tipo declarado inspeccionando magic bytes /
headers, no solo confiando en la extensión o el `Content-Type`.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/upload*`, `**/services/**`, `**/handlers/**`, `**/validators/**`
**Patrones:**
- `(?i)magic|libmagic|python-magic|file-type|file-magic|fleece`                # libs esperadas de detección
- `\.endswith\(['"]\.\w+['"]\)|filename\.split\(['"]\.['"]\)`                  # validación solo por extensión
- `(?i)content[_-]?type\s*==\s*['"][^'"]+['"]`                                 # confiar en Content-Type del cliente
- `mimetypes\.guess_type\(`                                                    # guess por nombre — verificar
- `mime\.lookup\(`                                                            # mime sólo por nombre
**Señal de N/A:** la app no acepta uploads de archivos (sin endpoints multipart).

**Verificar:**
- [ ] Tipo validado vía `libmagic`, `file-type`, o librería equivalente.
- [ ] La extensión del archivo está en allowlist y coincide con el tipo real.
- [ ] El `Content-Type` del upload se corrobora con el detectado.
- [ ] Los archivos compuestos (ZIP, docx, imágenes con metadatos) se analizan con cuidado.

**Banderas rojas:**
- Aceptar PDF basándose solo en `filename.endswith(".pdf")`.
- `Content-Type` reportado por el cliente usado como fuente de verdad.

---

#### `SEC-FILE-003` — Nombre de archivo server-side, no del cliente
**Severidad:** high · **Tags:** `cwe-22`, `cwe-434` · **Aplica a:** backend

El nombre con el que se guarda el archivo en disco/storage es generado por el
servidor (UUID/hash). El nombre original se guarda como metadato si se necesita
para mostrar al usuario.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/upload*`, `**/services/**`, `**/handlers/**`
**Patrones:**
- `path\.join\([^,)]*\.(originalname|filename|name)`                          # path con nombre del cliente
- `os\.path\.join\([^,)]*request\.files\[`                                    # Python equivalente
- `\.(originalname|filename|originalFilename)`                                # uso del nombre original
- `secure_filename\(|sanitize[_-]?filename\(`                                 # patrones esperados de sanitize
- `uuid\.uuid4\(\)|uuidv4\(\)|nanoid\(`                                       # generación esperada de nombre opaco
**Señal de N/A:** la app no escribe archivos basados en uploads (sin storage de uploads del cliente).

**Verificar:**
- [ ] Filename en storage = UUID u otro identificador opaco.
- [ ] El nombre original se almacena sanitizado en BD como metadato (para mostrar).
- [ ] No se usa el nombre del cliente en paths de disco.
- [ ] Los caracteres de control y rutas (`/`, `\`, `..`, `%00`) se filtran.

**Banderas rojas:**
- `open(os.path.join(UPLOAD_DIR, uploaded_file.filename))`.
- Conservar el nombre original en S3/blob storage como clave principal.

---

#### `SEC-FILE-004` — Archivos almacenados fuera de la raíz web
**Severidad:** critical · **Tags:** `cwe-434` · **Aplica a:** backend · infra

Los archivos subidos no se colocan en rutas servidas directamente por el web
server. Se sirven vía endpoint controlado (con autorización).

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,conf}`, `**/upload*`, `**/main.{ts,js,py}`, `**/nginx.conf`, `**/routes/**`
**Patrones:**
- `(UPLOAD_DIR|UPLOAD_PATH).*['"](public|static|www|htdocs|wwwroot)`          # carpeta de uploads bajo raíz web
- `app\.(use|static)\(['"]/uploads['"]`                                       # serve estático de uploads
- `autoindex\s+on|Options\s+\+Indexes`                                         # listado de directorio activo
- `getSignedUrl\(|generate_presigned_url\(`                                    # patrones esperados de signed URLs
- `expires?[_-]?in\s*[:=]\s*\d{4,}`                                           # signed URL con TTL muy largo
**Señal de N/A:** la app no almacena archivos uploadeados.

**Verificar:**
- [ ] Los uploads van a un directorio / bucket separado, no `/public/`, `/static/`.
- [ ] El acceso pasa por un endpoint que aplica autorización.
- [ ] Las URLs de descarga, si son públicas, usan tokens firmados de corta vida (S3 signed URLs, CDN signed URLs).
- [ ] No existe listado de directorio habilitado.

**Banderas rojas:**
- Upload servido desde ruta estática predecible.
- Links permanentes a objetos sin autenticación ni expiración.

---

#### `SEC-FILE-005` — Escaneo antimalware de uploads
**Severidad:** high · **Aplica a:** backend · infra

Los archivos subidos que serán procesados, almacenados, o compartidos pasan
por un escaneo antimalware.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/upload*`, `**/services/**`, `package.json`, `requirements*.txt`, `pyproject.toml`, `Dockerfile`
**Patrones:**
- `clamav|clamd|clamscan|node-clam|pyclamd|virustotal`                         # libs/servicios esperados
- `MalwareScan|virus_scan|antivirus|av_scan`                                  # naming esperado
- `(?i)quarantine`                                                            # cuarentena esperada
**Señal de N/A:** uploads no se redistribuyen (procesados internamente, no compartidos con otros usuarios; o ningún upload).

**Verificar:**
- [ ] Integración con ClamAV u otro motor antes de aceptar el archivo.
- [ ] El resultado del escaneo se registra.
- [ ] Los archivos infectados se cuarentenan y se notifica al usuario con código genérico.
- [ ] El timeout del escaneo está configurado.

**Banderas rojas:**
- Archivos distribuidos sin escanear (ej: adjuntos reenviados a otros usuarios).

---

#### `SEC-FILE-006` — Imágenes re-encodificadas antes de servir
**Severidad:** medium · **Tags:** `cwe-434`, `cwe-79` · **Aplica a:** backend

Las imágenes subidas se re-encoden (ej: pasar a PNG/JPEG limpios) para eliminar
metadatos, payloads EXIF maliciosos y SVG ejecutable.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/upload*`, `**/services/**`, `**/images/**`
**Patrones:**
- `Pillow|PIL\.Image|sharp\(|jimp|imagemagick|gm\(`                            # libs de procesamiento esperadas
- `\.svg['"]?\s*[\s\S]{0,200}(send|render|inline)`                             # SVG sin sanear servido
- `DOMPurify|svg-sanitizer|defusedxml`                                         # saneadores esperados
- `(?i)max[_-]?(width|height|pixels|dimensions)`                              # límites esperados (decompression bomb)
- `Image\.MAX_IMAGE_PIXELS\s*=\s*None`                                         # Pillow límite desactivado
**Señal de N/A:** la app no recibe ni redistribuye imágenes de usuarios.

**Verificar:**
- [ ] PNG/JPEG se re-encoden con una librería (Pillow, sharp, ImageMagick con policy restrictiva).
- [ ] SVG se sanea o se convierte a PNG antes de servir en contexto ejecutable.
- [ ] Los metadatos EXIF privados se remueven en re-encode (GPS, dispositivo).
- [ ] Se limita dimensiones máximas (decompression bomb defense).

**Banderas rojas:**
- Servir SVG user-uploaded inline sin sanitización (XSS).
- ImageMagick con policy permisiva (vulnerabilidades históricas de Ghostscript, PDF/PS delegates).

---

#### `SEC-FILE-007` — Límite de archivos concurrentes y total por usuario
**Severidad:** medium · **Tags:** `dos`, `quota` · **Aplica a:** backend

Cada usuario/tenant tiene cuota total de almacenamiento y número de archivos.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,sql,prisma}`, `**/models/**`, `**/services/**`, `**/upload*`
**Patrones:**
- `(?i)quota|storage[_-]?limit|max[_-]?files|file[_-]?count[_-]?limit`        # naming esperado de cuotas
- `SUM\(\s*size\s*\)|sum\(.*file.*size`                                       # query esperado de uso actual
- `413\b|StorageQuotaExceeded|QuotaExceededException`                         # respuestas esperadas
**Señal de N/A:** la app no tiene multitenancy ni cuotas definidas (uso interno acotado).

**Verificar:**
- [ ] Cuota de storage por usuario/org enforced.
- [ ] Cuota de archivos simultáneos subidos (connection-level).
- [ ] Al superar la cuota, se retorna 413/429 con mensaje claro.

---

## B. Descarga

#### `SEC-FILE-010` — Autorización en cada descarga
**Severidad:** critical · **Tags:** `owasp-a01`, `idor` · **Aplica a:** backend

El endpoint de descarga valida que el solicitante tiene permiso sobre el archivo,
por recurso individual (no solo "es usuario válido").

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/controllers/**`, `**/handlers/**`, `**/routes/**`, `**/files/**`
**Patrones:**
- `app\.get\(['"]/files?/[^'"]*\)?['"][^)]*\)\s*=>\s*\{(?![\s\S]*?(owner|user|tenant|authorize))` # endpoint /files sin check
- `send_file\(\s*[^,)]+\)(?![\s\S]{0,200}(owner|user|authorize))`             # send_file sin check de owner cerca
- `getSignedUrl\([\s\S]*?expires:\s*\d{5,}|Expiration:\s*\d{5,}`              # signed URL con TTL alto
- `presigned_url\(.*expires_in\s*=\s*\d{5,}`                                  # mismo en Python
**Señal de N/A:** la app no expone endpoint de descarga de archivos.

**Verificar:**
- [ ] La descarga verifica ownership/ACL antes de servir el archivo.
- [ ] Los tokens/URLs firmadas, si se usan, son de corta vida y single-use cuando aplique.
- [ ] Los IDs de archivo son opacos (UUID) para dificultar enumeración.
- [ ] El 404 es indistinguible del 403 para evitar enumeración.

**Banderas rojas:**
- `/files/{id}` que solo requiere estar autenticado, sin check de dueño.
- URLs firmadas con TTL de horas/días sin necesidad.

---

#### `SEC-FILE-011` — Content-Disposition y Content-Type correctos
**Severidad:** high · **Tags:** `cwe-79` · **Aplica a:** backend

Las respuestas de descarga establecen headers que evitan ejecución indebida
en el navegador.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/controllers/**`, `**/handlers/**`, `**/files/**`, `**/downloads/**`
**Patrones:**
- `Content-Disposition[^\n]*inline`                                            # inline para tipos potencialmente ejecutables
- `Content-Type[^\n]*text/html.*user`                                          # text/html sobre user content
- `set_header\(['"]Content-Disposition['"]\s*,\s*['"]?attachment`             # patrón esperado attachment
- `send_file\([^)]*as_attachment\s*=\s*False`                                 # Flask sin attachment
- `Content-Type\s*:\s*[^\n]*\.(svg|html|xml)`                                 # sirviendo tipos peligrosos
**Señal de N/A:** la app no sirve descargas (sin endpoints que retornen blobs).

**Verificar:**
- [ ] `Content-Disposition: attachment; filename="..."` para archivos no-inline.
- [ ] `Content-Type` derivado del tipo real validado (no del nombre de archivo).
- [ ] `X-Content-Type-Options: nosniff` presente.
- [ ] `filename` en el header se encoda correctamente (`filename*` con RFC 5987 para unicode).

**Banderas rojas:**
- `Content-Type: text/html` en respuestas con contenido user-uploaded.
- Content-Disposition inline para tipos potencialmente ejecutables (SVG, HTML, XML).

---

#### `SEC-FILE-012` — Streaming en descargas grandes
**Severidad:** medium · **Tags:** `performance` · **Aplica a:** backend

Los archivos grandes se sirven mediante streaming, no cargando todo en memoria.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/controllers/**`, `**/handlers/**`, `**/files/**`
**Patrones:**
- `\.read\(\s*\)\s*[\s\S]{0,100}(send|return|response)`                       # leer todo y devolver
- `StreamingResponse|ReadableStream|FileResponse|sendFile`                    # patrones esperados
- `(?i)Range|Accept-Ranges`                                                    # soporte ranges esperado
- `Transfer-Encoding\s*:\s*chunked`                                           # streaming HTTP
**Señal de N/A:** la app no sirve archivos grandes (>10 MB) ni streaming.

**Verificar:**
- [ ] Se usa `StreamingResponse`, `Transfer-Encoding: chunked`, o equivalente.
- [ ] Se soporta `Range` para descargas parciales y resumibles cuando aplica.
- [ ] Hay timeout y backpressure apropiado.

---

## C. Path traversal y almacenamiento

#### `SEC-FILE-020` — Path resolution segura
**Severidad:** critical · **Tags:** `cwe-22`, `cwe-73` · **Aplica a:** backend

Cualquier path derivado de input del usuario (parcialmente) se resuelve y se
verifica que queda dentro del directorio base.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/services/**`, `**/files/**`, `**/upload*`, `**/storage/**`
**Patrones:**
- `path\.join\([^,)]*req(uest)?\.|os\.path\.join\([^,)]*request\.`            # join con input
- `\.\.[/\\]|%2e%2e[/\\]`                                                     # secuencia traversal
- `Path\.resolve\(|realpath\(|os\.path\.realpath`                             # canonicalización esperada
- `is_relative_to\(|startswith\(\s*base`                                      # verificación esperada
- `open\(\s*[^,)]*req(uest)?\.|fs\.readFile\([^,)]*req\.`                     # open con input directo
**Señal de N/A:** la app no maneja paths derivados de input externo (filesystem solo accedido con paths fijos).

**Verificar:**
- [ ] Base directory absoluto.
- [ ] `Path.resolve()` / `realpath()` aplicado, y se compara con el base con `is_relative_to` / string prefix normalizado.
- [ ] Se rechazan nullbytes (`\x00`) y caracteres inválidos.
- [ ] Symlinks se resuelven antes de la verificación (o se prohíben en el directorio base).

**Banderas rojas:**
- `open(os.path.join(base, userinput))` sin verificación posterior.
- Concatenación con `/` simple sin normalización.

(Duplica parcialmente `SEC-INPUT-030` — aquí enfocado al contexto de archivos.)

---

#### `SEC-FILE-021` — Archivos temporales con nombres impredecibles y limpieza garantizada
**Severidad:** medium · **Tags:** `cwe-377` · **Aplica a:** backend

Los archivos temporales usan nombres aleatorios y se limpian aunque haya
excepciones.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/services/**`, `**/upload*`, `**/utils/**`
**Patrones:**
- `tempfile\.NamedTemporaryFile|tempfile\.mkstemp|os\.tmpfile`                # patrón seguro Python
- `Files\.createTempFile|File\.createTempFile`                                # Java seguro
- `os\.tmpdir\(\)|tmp\.\w+\(\s*\{\s*name`                                     # node tmp lib
- `/tmp/[a-z_]+_\$\{|/tmp/[a-z_]+_['"]\s*\+`                                  # path tmp predecible
- `(?i)finally|with\s+\w+\s+as|defer\s+\w+\.close`                            # cleanup esperado
**Señal de N/A:** la app no crea archivos temporales (todo procesamiento en memoria).

**Verificar:**
- [ ] `tempfile.NamedTemporaryFile`, `mkstemp`, `Files.createTempFile` (nunca nombre predecible en `/tmp`).
- [ ] Limpieza en `finally` o con context manager.
- [ ] Existe un job de limpieza periódica para temporales huérfanos.
- [ ] Los temporales se crean con permisos restrictivos (0600) en sistemas compartidos.

**Banderas rojas:**
- `/tmp/upload_{timestamp}.pdf` (predecible → symlink attacks).
- Temporales sin cleanup en rutas de error.

---

## D. Procesamiento de archivos

#### `SEC-FILE-030` — Procesamiento en sandbox
**Severidad:** high · **Aplica a:** backend · infra

El procesamiento de archivos (OCR, conversión, extracción) corre en un contexto
aislado cuando el formato es complejo (PDF con JS, Office con macros, XML con
entidades externas).

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/services/**`, `**/workers/**`, `**/processors/**`, `Dockerfile`, `**/k8s/**`
**Patrones:**
- `pdfplumber|pypdf|PyPDF2|pdfminer|pdf2image|pdftotext`                      # parsers PDF — verificar versión y aislamiento
- `python-docx|openpyxl|xlrd|apache-poi`                                       # parsers Office
- `subprocess|child_process|spawn|fork|worker_threads`                        # ejecución aislada esperada
- `(?i)resource\s*=\s*['"]?(memory|cpu|timeout)`                              # límites de recurso esperados
- `(?i)pdf.*javascript|pdf.*allow_js`                                         # JS en PDF habilitado
**Señal de N/A:** la app no procesa formatos complejos (solo almacena archivos sin parsear).

**Verificar:**
- [ ] Librerías usadas están actualizadas (muchas vulnerabilidades en parsers PDF/Office).
- [ ] Se procesan en un worker separado, con límites de CPU/memoria y timeout.
- [ ] Se desactivan features peligrosas (JavaScript en PDF, macros en Office, entidades externas en XML).

**Banderas rojas:**
- Parseo de PDF/Office en el mismo proceso web con librería desactualizada.
- XML parser con `resolve_entities=True` (XXE).

---

#### `SEC-FILE-031` — XXE prevenido en parseo XML/Office
**Severidad:** critical · **Tags:** `cwe-611` · **Aplica a:** backend

Los parsers XML se configuran para no resolver entidades externas ni DTDs remotos.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb,php}`, `**/services/**`, `**/parsers/**`, `**/workers/**`
**Patrones:**
- `xml\.etree|xml\.dom|xml\.sax|lxml\.etree(?!.*defusedxml)`                  # XML stdlib Python sin defusedxml
- `defusedxml`                                                                # patrón seguro esperado
- `DocumentBuilderFactory(?![\s\S]{0,300}setFeature.*disallow-doctype-decl)`  # Java sin disable DTD
- `XMLInputFactory(?![\s\S]{0,300}IS_SUPPORTING_EXTERNAL_ENTITIES.*false)`    # Java StAX
- `setFeature\([^,)]*external-general-entities[^,)]*,\s*true\)`               # entidades externas habilitadas
- `resolve_entities\s*=\s*True|no_network\s*=\s*False`                        # lxml inseguro
**Señal de N/A:** la app no parsea XML (incluyendo formatos que lo envuelven: docx/xlsx/SVG/SOAP).

**Verificar:**
- [ ] `XMLParser` configurado con `resolve_entities=False`, `no_network=True`, `forbid_dtd=True`.
- [ ] Librerías modernas (defusedxml en Python, similar en otros ecosistemas).
- [ ] Los formatos que envuelven XML (docx, xlsx, SVG, SOAP) también se parsean seguros.

**Banderas rojas:**
- Uso directo de `xml.etree.ElementTree` en Python sin defusedxml con input del usuario.
- Parser SAX con `setFeature("external-general-entities", True)`.

**Referencias:** CWE-611 · OWASP XXE Cheat Sheet.

---

#### `SEC-FILE-032` — Zip/archive bomb protection
**Severidad:** high · **Tags:** `cwe-409`, `dos` · **Aplica a:** backend

Al descomprimir archivos, se limita el tamaño total descomprimido, profundidad
y número de entradas.

**Dónde buscar:** `**/*.{ts,js,py,go,java,rb}`, `**/services/**`, `**/upload*`, `**/parsers/**`
**Patrones:**
- `zipfile\.ZipFile.*\.extractall\(\s*\)`                                     # extractall sin verificar
- `tarfile\.open.*\.extractall\(\s*\)`                                        # tar extractall
- `unzipper|adm-zip.*extractAllTo|node-stream-zip`                            # libs JS — verificar uso
- `(?i)compression[_-]?ratio|max[_-]?(uncompressed|extract)[_-]?size`         # protección esperada
- `name\.startswith\(['"]\.\.[/\\]['"]?\)|\.\.[/\\]`                           # check zip slip esperado
**Señal de N/A:** la app no descomprime archivos del cliente (sin uploads de zip/tar/etc).

**Verificar:**
- [ ] Se limita el ratio de compresión (ratio ≥ N → abortar).
- [ ] Se limita el tamaño total descomprimido.
- [ ] Se limita el número de entradas.
- [ ] Se verifica que cada entrada no escape del directorio destino (zip slip).

**Banderas rojas:**
- `zipfile.extractall()` sobre archivos del cliente sin validar paths (zip slip, CVE-2020-27225...).
- Extraer sin mirar tamaño descomprimido.

---

## E. Contenedores y runtime

#### `SEC-FILE-040` — Proceso de la aplicación corre como usuario no-root
**Severidad:** critical · **Tags:** `cwe-250`, `least-privilege`, `container-security` · **Aplica a:** infra · backend

El proceso de la aplicación dentro del contenedor (Docker, OCI) corre con un
usuario no privilegiado. UID=0 (root) solo se acepta durante las fases de build
estrictamente necesarias.

**Dónde buscar:** `**/Dockerfile*`, `**/Containerfile`, `docker-compose*.{yml,yaml}`, `**/k8s/**/*.{yml,yaml}`, `**/helm/**`
**Patrones:**
- `^USER\s+(\w+)`                                                              # USER esperado
- `USER\s+root|USER\s+0\b`                                                     # USER root explícito
- `runAsNonRoot:\s*false|runAsUser:\s*0\b`                                     # K8s root
- `allowPrivilegeEscalation:\s*true`                                           # K8s priv escalation
- `--privileged|privileged:\s*true`                                            # privileged container
- `(addgroup|adduser|useradd|groupadd)\s+\S`                                   # creación de user esperada
**Señal de N/A:** workload sin contenedor (binario, Lambda, Cloud Function).

**Verificar:**
- [ ] El `Dockerfile` incluye una instrucción `USER <non-root>` antes del `CMD`/`ENTRYPOINT`.
- [ ] El usuario del proceso tiene solo los permisos necesarios sobre los archivos que debe leer/escribir.
- [ ] Si se usa imagen base oficial (ej: `node:20-alpine`), se agrega un usuario dedicado explícitamente.
- [ ] En orquestadores (Kubernetes, ECS), el `securityContext.runAsNonRoot: true` está configurado.
- [ ] Volúmenes montados tienen ownership correcto para el usuario de la app.

**Banderas rojas:**
- `Dockerfile` sin ninguna instrucción `USER` antes del `CMD` — corre como root por defecto.
- `USER root` explícito al final del Dockerfile sin revertir.
- Imagen base que ya corre como root y no se sobreescribe.
- `whoami` / `id` en logs de arranque mostrando `root` o `uid=0`.

**Ejemplo de hallazgo:**
```yaml
control_id: SEC-FILE-040
severity: critical
file: Dockerfile
line: 1
evidence: |
  FROM node:20-alpine
  WORKDIR /app
  COPY . .
  RUN npm ci && npm run build
  EXPOSE 3000
  CMD ["node", "dist/main.js"]
  # Sin instrucción USER — corre como UID=0 (root)
explanation: |
  El proceso de Express corre como root dentro del contenedor. Si un atacante
  logra RCE a través de la aplicación (ej: explotando una vulnerabilidad de
  inyección), tendrá privilegios root dentro del contenedor, facilitando la
  escalada de privilegios o la extracción de secretos montados como volúmenes.
suggestion: |
  RUN addgroup -S appgroup && adduser -S appuser -G appgroup
  COPY --chown=appuser:appgroup dist/ dist/
  USER appuser
  CMD ["node", "dist/main.js"]
```

**Referencias:** CWE-250 · OWASP Docker Security Cheat Sheet · Docker docs — "Best practices: USER instruction" · CIS Docker Benchmark 4.1.

---

## Checklist resumen

| ID               | Control                                               | Severidad |
| ---------------- | ----------------------------------------------------- | --------- |
| SEC-FILE-001     | Tamaño máximo verificado antes de memoria             | high      |
| SEC-FILE-002     | Tipo validado por contenido                           | high      |
| SEC-FILE-003     | Nombre server-side                                    | high      |
| SEC-FILE-004     | Fuera de la raíz web                                  | critical  |
| SEC-FILE-005     | Escaneo antimalware                                   | high      |
| SEC-FILE-006     | Re-encode de imágenes                                 | medium    |
| SEC-FILE-007     | Cuotas por usuario                                    | medium    |
| SEC-FILE-010     | Autorización en descarga                              | critical  |
| SEC-FILE-011     | Content-Disposition/Type correctos                    | high      |
| SEC-FILE-012     | Streaming en descargas grandes                        | medium    |
| SEC-FILE-020     | Path resolution segura                                | critical  |
| SEC-FILE-021     | Temporales impredecibles y limpios                    | medium    |
| SEC-FILE-030     | Procesamiento en sandbox                              | high      |
| SEC-FILE-031     | XXE prevenido                                         | critical  |
| SEC-FILE-032     | Zip bomb / zip slip prevenido                         | high      |
| SEC-FILE-040     | Proceso no-root en contenedor                         | critical  |
