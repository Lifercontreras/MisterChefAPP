# DOCUMENTACIÓN COMPLETA - LOGIGO

## 1. Visión General

**LogiGo** es un sistema de gestión para distribución de productos alimentarios a domicilio. Fue adaptado para la empresa **Mister Chef**, de ahí que la app muestre el nombre LogiGo mientras la empresa, los correos del seed y algunos identificadores técnicos conservan el nombre Mister Chef.

> **Nombres técnicos que se conservan a propósito:** el paquete Flutter `mister_chef`, los repositorios `misterChefApi` y `MisterChefAPP`, la URL de Railway `misterchefapi-production.up.railway.app`, los correos `@misterchef.com` del seed y el archivo de configuración `config/misterchef.php`. Son identificadores históricos, no el nombre visible del producto.

Está conformado por:

- **Backend:** API REST desarrollada con Laravel 12 (PHP 8.2), desplegada en **Railway** (producción)
- **Frontend:** Aplicación móvil desarrollada con Flutter (Dart)
- **Autenticación:** Laravel Sanctum con tokens Bearer
- **Comunicación:** HTTP/JSON entre Flutter y Laravel API (HTTPS en producción)
- **Rutas en carretera:** servidor público **OSRM** (OpenStreetMap), sin clave de API

El sistema gestiona empleados, clientes, productos, facturas/pedidos, rutas de domicilio, geolocalización en tiempo real, distribución automática de clientes por zonas y un chatbot con IA (Groq).

**URL de producción de la API:** `https://misterchefapi-production.up.railway.app/api/v1`

---

## 2. Estructura del Repositorio

```
C:\Archivos\Sistemas\MisterChef\
├── DOCUMENTACION.md         # Este archivo
├── comandos.txt             # Comandos rápidos del entorno local
├── misterChefApi\           # Backend Laravel API
└── MisterChefAPP\
    └── mister_chef\         # Aplicación Flutter
```

### 2.1 Backend (misterChefApi)

```
misterChefApi/
├── app/
│   ├── Http/Controllers/     # AuthController, EmployeeController, ProductController,
│   │                         # ClientController, InvoiceController, RouteController,
│   │                         # LocationController, ChatbotController
│   ├── Models/               # Employee, Client, Product, ProductType, Invoice, Detail,
│   │                         # Department, City, DeliveryRoute, RouteSuggestion,
│   │                         # EmployeeLocation, AuditInvoice, User
│   └── Services/
│       └── RouteDistributionService.php  # Algoritmo de distribución por zonas
├── config/
│   ├── misterchef.php       # Config propia: LOCATION_STALE_MINUTES, ADMIN_PASSWORD
│   └── services.php         # Config de Groq (key, url, model)
├── database/
│   ├── migrations/           # Esquema completo (última: date de invoice → dateTime)
│   └── seeders/              # DepartmentSeeder, CitySeeder, ProductTypeSeeder,
│                             # EmployeeSeeder, ProductSeeder, ClientSeeder,
│                             # InvoiceSeeder, RouteSeeder, RouteSuggestionSeeder,
│                             # EmployeeLocationSeeder, DatabaseSeeder
├── routes/
│   └── api.php               # Todas las rutas de la API v1 (con rate limiting)
├── tests/                    # Pruebas Pest (Feature: rutas, clientes, facturas, etc.)
├── boost.json                # Config de Laravel Boost (guías para agentes)
├── AGENTS.md                 # Directrices del proyecto para agentes de IA
└── .env                      # Variables de entorno (configuración local)
```

### 2.2 Frontend (MisterChefAPP/mister_chef)

```
mister_chef/
├── env/
│   ├── prod.example.json     # Plantilla de variables de compilación (solo API_BASE_URL)
│   └── prod.json             # API_BASE_URL real (NO versionada)
├── lib/
│   ├── config/
│   │   ├── constants.dart    # Endpoints, intervalos GPS, roles, estados, timeouts
│   │   ├── app_routes.dart   # Rutas de navegación nombradas
│   │   ├── app_colors.dart   # Colores de la app (claro/oscuro)
│   │   ├── app_theme.dart    # Temas Material 3 (Inter / Lexend para dislexia)
│   │   ├── client_map_logic.dart          # Lógica pura del mapa de clientes
│   │   ├── distribution_preview_logic.dart # Resumen y cambios de la vista previa de reparto
│   │   ├── route_clients_logic.dart       # Filtro de clientes activos de la ruta
│   │   ├── road_route_logic.dart          # Firma y reintento de la ruta por OSRM
│   │   └── location_polling_logic.dart    # Reglas del polling de ubicaciones (admin)
│   ├── models/               # Stubs vacíos (0 bytes) — la app usa Map<String, dynamic>
│   ├── providers/            # accessibility_provider.dart (único real),
│   │                         # auth/chat/order/route/theme_provider son stubs
│   ├── screens/
│   │   ├── auth/             # splash_screen, login_screen, change_password_screen
│   │   ├── home/             # home_screen (main_navigation.dart es stub)
│   │   ├── admin/            # employees, create_employee, employee_detail,
│   │   │                     # products, create_product, delivery_map
│   │   ├── customers/        # customers, create_customer, customer_detail
│   │   ├── orders/           # orders, new_order, order_detail (select_products es stub)
│   │   ├── route/            # route_screen (vendedor), route_admin_screen,
│   │   │                     # route_distribution_preview_screen, map_widget (stub)
│   │   ├── settings/         # accessibility_screen (settings_screen es stub)
│   │   └── chatbot/          # chatbot_screen
│   ├── services/
│   │   ├── api_service.dart           # Cliente HTTP base (singleton, manejo 401/429/5xx)
│   │   ├── auth_service.dart          # Login, logout, sesión local
│   │   ├── employee_service.dart
│   │   ├── product_service.dart
│   │   ├── customer_service.dart
│   │   ├── order_service.dart
│   │   ├── route_service.dart         # Rutas, distribución y OSRM (OpenStreetMap)
│   │   ├── location_service.dart       # Enviar/desactivar ubicación GPS
│   │   ├── tracking_service.dart      # Rastreo en primer plano (ChangeNotifier)
│   │   ├── location_send_throttle.dart # Regla de throttling GPS (8 s mín.)
│   │   ├── chatbot_service.dart
│   │   ├── maps_service.dart          # Marcadores, polilíneas, cámara
│   │   └── storage_service.dart       # Stub vacío
│   ├── utils/                # location_helper.dart (formatters/validators/snackbar son stubs)
│   └── widgets/              # role_bottom_nav.dart (los demás son stubs)
├── test/
│   ├── api_response_test.dart          # Pruebas de parseApiResponse
│   ├── location_send_throttle_test.dart # Pruebas del throttle GPS
│   ├── route_service_test.dart          # Pruebas con http.Client falso (incluye OSRM)
│   ├── client_map_logic_test.dart       # Lógica del mapa de clientes
│   ├── distribution_preview_logic_test.dart # Resumen de la vista previa de reparto
│   ├── location_polling_logic_test.dart # Reglas del polling del mapa admin
│   ├── road_route_logic_test.dart       # Firma/reintento de la ruta por carretera
│   └── route_clients_logic_test.dart    # Filtro de clientes activos
├── android/
│   ├── key.properties.example # Plantilla de firma del release (real NO versionada)
│   └── ...                    # Permisos de servicio en primer plano y notificaciones
├── README.md                 # Instrucciones de compilación y firma del APK
└── pubspec.yaml              # Dependencias Flutter
```

---

## 3. Backend - API Laravel

### 3.1 Stack Tecnológico

| Tecnología | Versión | Uso |
|---|---|---|
| PHP | ^8.2 | Lenguaje base |
| Laravel Framework | ^12.0 | Framework principal |
| Laravel Sanctum | ^4.0 | Autenticación API con tokens |
| Laravel Tinker | ^2.10.1 | REPL para debugging |
| awobaz/compoships | ^3.0 | Soporte para claves compuestas (City) |
| Pest | ^3.8 | Testing |
| Laravel Pint | ^1.24 | Code style formatter |
| Laravel Boost | ^2.2 (dev) | Guías/MCP para agentes de IA |

### 3.2 Autenticación

- **Sistema:** Laravel Sanctum con `HasApiTokens` en modelo `Employee`
- **Login:** `POST /api/v1/login` con `email` y `password` — **rate limit 10 intentos/min** (`throttle:10,1`)
- **Protección:** Rutas bajo `auth:sanctum` middleware
- **Tokens:** Generados con `$employee->createToken('auth_token')->plainTextToken`
- **Logout:** `POST /api/v1/logout` (borra el token actual)
- **Cambio de contraseña:** `POST /api/v1/change-password` (fuerza cambio si `first_login = true`)

### 3.3 Modelos

| Modelo | Tabla | PK | Timestamps | Notas |
|---|---|---|---|---|
| `Employee` | `employee` | `document_employee` (string) | No | Authenticatable, `HasApiTokens`. Roles: `type` = `A` (Admin) / `V` (Vendedor/Domiciliario). `status` = `A`/`I`. `can_modify_invoice` = `S`/`N`. `first_login` = boolean (cast). `commission_percentage` = decimal:2. |
| `Client` | `client` | `id_client` (string, auto CLI###) | No | Pertenece a empleado, departamento y ciudad. `status` boolean. ID autogenerado en el controller. |
| `Product` | `product` | `id_product` (string, auto P####) | No | Pertenece a ProductType. `status` boolean. Usa `id_produc_type`. ID autogenerado en el controller. |
| `ProductType` | `product_type` | `id_produc_type` (string) | No | Categorías de productos. |
| `Invoice` | `invoice` | `id_invoice` (string, máx 5) | No | `status` = `P` (Pendiente) / `C` (Confirmada) / `A` (Anulada). `date` es **dateTime** (migración 2026_06_15 cambió de date a dateTime). |
| `Detail` | `detail` | Compuesta [`line_number`, `id_invoice`] | No | Líneas de factura. `line_number` es string en BD. |
| `Department` | `department` | `id_departament` (string) | No | Departamentos de Colombia. Tiene accessor `department_name`. |
| `City` | `city` | Compuesta [`id_departament`, `id_city`] | No | Usa Compoships. Tiene accessor `city_name`. |
| `DeliveryRoute` | `routes` | `id_ruta` (string) | No | Asignación cliente-vendedor. |
| `RouteSuggestion` | `route_suggestion` | `id_suggestion` (string 10) | No | `status` = `P` / `A` / `R`. Incluye `resolved_by`, `resolved_at`, `distance_km`. |
| `EmployeeLocation` | `employee_location` | `document_employee` (string) | Sí (updated_at) | GPS en tiempo real. `is_active` boolean. Se actualiza con `updateOrCreate`: hay **una sola fila por empleado**, no hay historial de posiciones. |
| `AuditInvoice` | `audit_invoice` | `id_audit` (string 10) | No | `action_type` = `C` (Creación) / `M` (Modificación) / `A` (Anulación). |

### 3.4 Rutas API (`routes/api.php`)

**Públicas (sin auth):**

| Endpoint | Middleware | Descripción |
|---|---|---|
| `POST /api/v1/login` | `throttle:10,1` | Login (máx 10 intentos por minuto) |

**Protegidas con `auth:sanctum`:**

| Grupo | Endpoints |
|---|---|
| Auth | `POST /logout`, `GET /me`, `POST /change-password` |
| Empleados (solo Admin) | `GET /employees`, `POST /employees`, `GET /employees/{id}`, `PUT /employees/{id}`, `PATCH /employees/{id}/status` |
| Productos | `GET /products` (filtro `?status=`), `GET /products/low-stock`, `GET /products/{id}`, `POST /products`, `PUT /products/{id}`, `PATCH /products/{id}/status`, `PATCH /products/{id}/stock`, `GET /product-types` |
| Clientes | `GET /clients`, `POST /clients`, `GET /clients/map` (Admin), `GET /clients/{id}`, `PUT /clients/{id}`, `PATCH /clients/{id}/status` |
| Facturas | `GET /invoices` (filtros `?status=` y `?date=`), `GET /invoices/stats`, `POST /invoices`, `GET /invoices/{id}`, `GET /invoices/{id}/audit`, `PATCH /invoices/{id}/confirm`, `PATCH /invoices/{id}/cancel` |
| Geolocalización | `POST /location` (`throttle:30,1`), `GET /location`, `PATCH /location/deactivate`, `GET /departments`, `GET /cities` (filtro `?id_departament=`) |
| Rutas | `GET /routes`, `GET /routes/navigate/{clientId}`, `DELETE /routes/{id}`, `POST /routes/distribution/preview` (Admin), `POST /routes/distribution/apply` (Admin) |
| Rutas — **LEGADO** | `POST /routes/distribute`, `GET /route-suggestions`, `PATCH /route-suggestions/{id}/approve`, `PATCH /route-suggestions/{id}/reject` |
| Chatbot | `POST /chatbot` (acepta `latitude`/`longitude` opcionales) |

> Los endpoints marcados como **LEGADO** siguen registrados en el servidor por compatibilidad, pero la app ya no los usa: el flujo actual es vista previa + aplicar (ver 3.4.1).

#### 3.4.1 Distribución de clientes (flujo actual)

**`POST /routes/distribution/preview`** (solo administrador; no escribe en la base de datos)

- 403 `Solo los administradores pueden distribuir rutas.`
- 422 `No hay vendedores activos para distribuir.`
- 422 `No hay clientes elegibles para distribuir.`
- 200 con:
  - `fingerprint`: SHA-1 del mapa `id_client → document_employee` calculado.
  - `summary`: `clients`, `sellers`, `skipped_without_coordinates`.
  - `sellers[]`: por vendedor `document_employee`, `name`, `current_clients`, `new_clients` y `clients[]` (con `previous_document_employee`).
  - `skipped[]`: clientes activos sin coordenadas, con `reason: "sin_coordenadas"`.

**`POST /routes/distribution/apply`** (solo administrador)

- Body obligatorio: `fingerprint` (string).
- 403 `Solo los administradores pueden distribuir rutas.`
- 422 `No hay vendedores activos para distribuir.` / `No hay clientes elegibles para distribuir.`
- 409 `El reparto cambió desde la vista previa. Vuelve a calcularlo.` cuando el fingerprint recibido no coincide con el plan actual.
- 200 `Distribución aplicada correctamente.` con `applied: { clients, routes, suggestions_closed }`.
- Es una **redistribución total desde cero**: sobrescribe las asignaciones manuales de los clientes elegibles.
- No reasigna clientes desactivados ni clientes sin coordenadas (sus filas de `routes`, si existen, **no se borran**).
- Cierra **todas** las sugerencias pendientes (`status = 'P'`) como rechazadas (`'R'`), registrando `resolved_at` y `resolved_by`.

**Algoritmo (`RouteDistributionService::assign`)** — agrupación por zonas geográficas:

1. Solo participan clientes activos con `latitude` y `longitude`, y vendedores activos (`type = 'V'`, `status = 'A'`).
2. Los clientes se proyectan a un plano local (equirectangular; la longitud se escala por el coseno de la latitud media).
3. Se calculan **cupos exactos** por zona: `intdiv(K, N)` y las primeras `K % N` zonas reciben un cliente más, así que la diferencia máxima entre zonas es 1 cliente.
4. Se parte el conjunto con **bisecciones sucesivas** (eje de mayor extensión; desempates deterministas por `id_client`).
5. Se refinan los límites con **intercambios** que reducen la distancia cuadrada a los centroides: máximo **20 pasadas**, umbral de mejora `1e-12`.
6. Cada zona se empareja con el vendedor que hoy tiene **más clientes en ella** (solapamiento con la asignación vigente); empates: zona de menor índice y luego vendedor de menor documento.
7. El resultado es **determinista** y los clientes de cada vendedor se ordenan por `id_client`.

> `haversineDistance()` sigue existiendo en el servicio y se usa en el chatbot para calcular clientes cercanos, no en la distribución por zonas.

#### 3.4.2 Asignación manual y estado de clientes

- **Crear cliente (`POST /clients`):** si lo hace un vendedor, el cliente queda asignado a él mismo (`document_employee` del token, sin importar lo que envíe). Si lo hace el administrador, puede enviar `document_employee` o `null` (= sin asignar).
- **Editar cliente (`PUT /clients/{id}`):** solo el administrador puede cambiar la asignación (`document_employee`). El vendedor no puede reasignar.
- Vendedor inexistente, inactivo o que no sea vendedor (por ejemplo, un administrador) → 422 `El vendedor seleccionado no existe o no está activo.`
- Cualquier cambio de asignación (o alta de cliente) **sincroniza la tabla `routes`**: se borra la fila anterior del cliente y se crea una nueva si el cliente está activo y su vendedor sigue activo.
- **`PATCH /clients/{id}/status`:** el administrador cambia el estado de cualquier cliente; el vendedor solo de los suyos (403 `No tienes permiso para actualizar este cliente.`). Desactivar borra la fila de `routes` pero conserva el vendedor en `client`; reactivar la recrea si el vendedor sigue activo.
- `GET /clients` filtra por vendedor cuando el token es de vendedor; `GET /clients/{id}` ajeno → 403 `No tienes permiso para ver este cliente.`

**Sobre la tabla `routes`:** la API intenta mantener **una fila por cliente activo con vendedor activo**, pero `routes` **no lo impone a nivel de base de datos** (no hay índice único por `id_client` ni restricciones de estado). Los caminos normales la mantienen sincronizada, pero pueden quedar filas obsoletas o huérfanas:

- `DELETE /routes/{id}` borra la fila pero **no** limpia `client.document_employee`, así que un cliente activo puede quedar con vendedor y sin fila.
- `apply` solo borra/recrea las filas de los clientes elegibles (activos y con coordenadas); las filas viejas de clientes inactivos o sin coordenadas permanecen.
- `GET /routes` oculta las filas cuyo cliente está inactivo, pero no las repara.
- `approve`/`reject` de sugerencias no validan que el cliente siga activo, por lo que pueden crear una fila para un cliente desactivado.

#### 3.4.3 Otras notas de comportamiento

- **Facturas por vendedor:** Un vendedor (`type = V`) solo ve las facturas de sus clientes (`GET /invoices`, `GET /invoices/{id}` con 403 si no es suyo, `GET /invoices/stats`).
- **Crear factura:** `POST /invoices` valida que el vendedor solo facture a sus propios clientes (403 `No tienes permiso para facturar a este cliente.`); un cliente inactivo responde 422 `No se puede crear una factura para un cliente inactivo.`
- **Anular factura:** Pueden anular tanto Admin como Vendedor (`PATCH /invoices/{id}/cancel`).
- **Auditoría:** `GET /invoices/{id}/audit` ordena por `action_date` descendente e incluye `employee` embebido.
- **Ubicaciones obsoletas:** `GET /location` es solo para administradores (403 para vendedores) y devuelve únicamente ubicaciones activas, de empleados activos, actualizadas en los últimos `LOCATION_STALE_MINUTES` (default 5). Respuesta: `document_employee`, `name`, `latitude`, `longitude`, `last_update`.
- **Rutas del vendedor:** `GET /routes` devuelve el array agrupado por vendedor y **solo incluye clientes activos**; si no hay clientes devuelve `[]`.
- **Navegar:** `GET /routes/navigate/{clientId}` responde 422 `Este cliente está desactivado.` si el cliente fue desactivado.
- **Legado de sugerencias:** `PATCH /route-suggestions/{id}/approve` y `reject` validan administrador, que el vendedor destino exista y esté activo, y sincronizan `routes` con la asignación; `reject` exige `document_employee` en el body. La app no los invoca.
- **Desactivar vendedor:** `PATCH /employees/{id}/status` con `status = 'I'` borra sus tokens, deja sus clientes sin vendedor (`document_employee = null`), elimina sus filas de `routes`, cierra sus sugerencias pendientes como `'R'` y desactiva su ubicación. La respuesta incluye `released: { clients, routes, suggestions }` con cuántos registros se liberaron. Todo ocurre en una transacción.

### 3.5 Seeders

Los seeders crean datos completos para probar la app sin crear nada manualmente. Se ejecutan en orden desde `DatabaseSeeder`:

| Seeder | Descripción |
|---|---|
| `DepartmentSeeder` | 32 departamentos de Colombia (D001-D032) |
| `CitySeeder` | ~210 ciudades incluyendo todas las de Norte de Santander (Ocaña, Cúcuta, Tibú, etc.) |
| `ProductTypeSeeder` | Condimentos, Cereales, Frutos secos, Salsas |
| `EmployeeSeeder` | admin@misterchef.com, vendedor@misterchef.com, vendedor2@misterchef.com, inactivo@misterchef.com. **La contraseña del admin viene de `ADMIN_PASSWORD`** (obligatoria en producción; `admin123` solo en local/dev) |
| `ProductSeeder` | 12 productos P0001-P0012, uno con stock bajo (P0009) |
| `ClientSeeder` | 8 clientes CLI001-CLI008 en Ocaña, asignados a vendedores |
| `InvoiceSeeder` | 7 facturas F0001-F0007 (mezcla P/C/A), 4 del día para estadísticas |
| `RouteSeeder` | 6 rutas asignadas, 2 clientes sin ruta |
| `RouteSuggestionSeeder` | 1 sugerencia pendiente (SG00000001) |
| `EmployeeLocationSeeder` | GPS activo en Ocaña para el vendedor |

### 3.6 Tests (Pest)

Suite completa: **101 pruebas, 2532 aserciones** (`php artisan test --compact`, ~30 s).

| Archivo | Pruebas | Cubre |
|---|---:|---|
| `ClientAssignmentTest` | 10 | Asignación manual, `null` = sin asignar, sincronización de `routes`, vendedor inválido/inactivo/administrador → 422 |
| `ClientMapTest` | 7 | `GET /clients/map` (solo admin, solo activos con coordenadas, `seller_name`) |
| `ClientStatusRouteTest` | 13 | `PATCH /clients/{id}/status`, borrado/recreación de `routes`, `GET /routes` sin rutas → `[]`, `navigate` 422 |
| `ClientVisibilityTest` | 11 | Visibilidad de clientes por rol, `GET /clients/{id}` ajeno → 403 |
| `EmployeeDeactivationTest` | 11 | Desactivación de empleado: clientes liberados, rutas, sugerencias, tokens, `released`, reactivación sin restauración |
| `InvoiceOwnershipTest` | 7 | `POST /invoices`: vendedor solo factura a sus clientes (403), cliente inactivo (422), admin, 401, stock intacto |
| `RouteDistributionTest` | 17 | Vista previa/aplicar, fingerprint, 409, redistribución total, sugerencias cerradas, filas obsoletas |
| `RouteZoneDistributionTest` | 8 | Algoritmo por zonas: cupos exactos, determinismo, emparejamiento por solapamiento |
| `ProductionReadinessTest` | 4 | Ubicaciones obsoletas fuera del mapa, modelo de Groq desde config, rate limit de `/location` (429 tras 30/min), `ADMIN_PASSWORD` obligatoria en producción |
| `SeedDatabaseTest` | 9 | Seeders básicos |
| `OcanaClientsSeederTest` | 2 | Semilla de clientes de Ocaña |
| `ExampleTest` (Feature + Unit) | 2 | Página de bienvenida de Laravel |
| **Total** | **101** | |

Los tests usan SQLite in-memory (`phpunit.xml`).

> `php artisan test --list-tests` es la fuente autoritativa del conteo: un grep ingenuo de `test(`/`it(` cuenta de más porque también coincide con llamadas auxiliares como `test()->withToken(...)`.

---

## 4. Frontend - Aplicación Flutter

### 4.1 Stack Tecnológico

| Dependencia | Uso |
|---|---|
| `http` | Peticiones HTTP |
| `provider` | Estado (AccessibilityProvider) |
| `google_maps_flutter` | Mapas de Google |
| `geolocator` | GPS, stream de posiciones, servicio en primer plano |
| `geocoding` | Conversión coordenadas ↔ dirección |
| `shared_preferences` | Almacenamiento local (token, datos usuario, preferencias) |
| `url_launcher` | Abrir Google Maps externo para navegación |
| `google_fonts` | Tipografías Inter (normal) y Lexend (dislexia) |
| `supabase_flutter` | Declarada en pubspec (aún sin uso en el código) |

> Ya no se usan: `permission_handler`, `intl`, `flutter_svg`, `flutter_dotenv`. El manejo de permisos lo hace `geolocator` directamente.

### 4.2 Configuración (`lib/config/constants.dart` + `env/prod.json`)

**La URL base NO se escribe en el código.** Se inyecta en tiempo de compilación con `--dart-define-from-file=env/prod.json`:

```json
{
  "API_BASE_URL": "https://misterchefapi-production.up.railway.app/api/v1"
}
```

- Si falta `API_BASE_URL`, la app muestra una pantalla de ayuda en vez de arrancar rota.
- `API_BASE_URL` se normaliza quitando la barra final si la tiene.
- **No hay clave de rutas:** las rutas en carretera se piden al servidor público OSRM (OpenStreetMap), que no usa llave.
- `MAPS_API_KEY` (distinta) la lee Gradle para el SDK de Google Maps en Android desde `android/local.properties` o variable de entorno.

**Claves SharedPreferences:** `auth_token`, `employee_doc`, `user_name`, `user_role`, `first_login`, `dark_mode`, `font_scale`

**Roles:** `roleAdministrador = 'A'`, `roleVendedor = 'V'`

**Estados factura:** `P` (Pendiente), `C` (Confirmada), `A` (Anulada)

**GPS:** El stream de posiciones emite cada **10 s** (`AppConstants.locationUpdateInterval`); el envío al servidor respeta un mínimo de **8 s** entre envíos exitosos (`locationMinSendInterval` / `LocationSendThrottle`). Timeout HTTP de 15 s. En iOS el intervalo no se aplica: `LocationSettings` no acepta `intervalDuration` y el sistema decide la frecuencia.

**Versión de la app:** `0.1.0` (mostrada en el splash)

### 4.3 Navegación por Rol

| Rol | Menú Inferior |
|---|---|
| **Administrador (A)** | Inicio / Pedidos / Clientes / Empleados / Asistente |
| **Vendedor (V)** | Inicio / Pedidos / Ruta / Clientes / Acceso (Accesibilidad) |

Rutas nombradas registradas en `MaterialApp` (ver `app_routes.dart`): splash, login, change-password, home, orders, orders/new, orders/detail, customers, customers/detail, customers/new, route, chatbot, employees, products, delivery-map, route-admin, accessibility, settings, reports (pendiente).

### 4.4 Servicios Principales

| Servicio | Función |
|---|---|
| `api_service.dart` | Singleton HTTP con token Bearer, `ApiException`, `parseApiResponse` (maneja 2xx vacío, 429, 5xx, HTML de proxies, errores 422 de Laravel), timeout de 15 s, handler global de 401 |
| `auth_service.dart` | Login, logout (detiene rastreo → desactiva ubicación → invalida token), `me`, cambio de contraseña, sesión local |
| `employee_service.dart` | CRUD empleados (solo admin) |
| `product_service.dart` | CRUD productos, stock, tipos, low-stock |
| `customer_service.dart` | CRUD clientes con departamentos/ciudades |
| `order_service.dart` | CRUD facturas, confirmar/anular, estadísticas |
| `route_service.dart` | Rutas, navegación, distribución (vista previa/aplicar) y **rutas por carretera con OSRM** (`router.project-osrm.org`, OpenStreetMap, sin clave) |
| `location_service.dart` | Enviar/desactivar ubicación GPS |
| `tracking_service.dart` | Rastreo continuo del domiciliario: stream único cada 10 s con `AndroidSettings` (servicio en primer plano, notificación **"LogiGo"** y wake lock), estados observables (`detenido`, `activo`, `sinPermiso`, `errorRed`), tolerante a fallos de red |
| `location_send_throttle.dart` | Regla pura de throttling (mín. 8 s entre envíos exitosos), testeable sin red |
| `chatbot_service.dart` | Chat con IA (Groq) |
| `maps_service.dart` | Permisos GPS, marcadores (clientes/vendedores), polilíneas, cámara |

### 4.5 Funcionalidades Clave

- **Splash y sesión persistente:** `SplashScreen` verifica el token guardado; si la sesión es de un vendedor **reanuda automáticamente el rastreo GPS** al abrir la app.
- **Tracking GPS en primer plano:** El vendedor comparte ubicación mientras la app viva; en Android corre como servicio en primer plano con notificación **"LogiGo"** / "Compartiendo tu ubicación con la central" y wake lock. El stream emite cada 10 s y el envío respeta 8 s mínimos. Si la app muere, la notificación también desaparece (limitación conocida).
- **Sesión expirada (401):** Cualquier petición autenticada que reciba 401 limpia la sesión, detiene el rastreo y lleva al login con un SnackBar. El aviso se dispara una sola vez por sesión (`resetUnauthorizedGuard` al iniciar sesión).
- **Logout ordenado:** Detiene el stream local → avisa al servidor (`/location/deactivate`, timeout 5 s) → invalida el token → limpia SharedPreferences.
- **Accesibilidad:** Modo oscuro, escala de fuente (0.7–1.4), fuente Lexend para dislexia y niveles de saturación de color (normal / alta / baja / escala de grises) aplicados a TODA la app mediante `ColorFilter` y `TextScaler`. Persistidas en SharedPreferences.
- **Mapas:** Google Maps como mapa base (`MAPS_API_KEY`) para visualizar rutas y el mapa de admin en tiempo real; navegación turn-by-turn con Google Maps externo; **las polilíneas de carretera se calculan con OSRM** y se muestra la atribución `Rutas © OpenStreetMap · OSRM`.
- **Ruta por carretera:** La ruta general del vendedor (`mi_ruta`) se traza por vías con **2 a 50 paradas**, en el orden de la lista. Si OSRM falla o responde 429, queda la línea recta y un refresco posterior (mínimo 2 s) reintenta; no hay bucle automático de reintentos.
- **Mapa del administrador:** Refresca solo `GET /location` cada 10 s, sin solapar peticiones y pausado cuando la app pasa a segundo plano. Los clientes se cargan una vez (y con refresco manual), nunca entran al polling.
- **First Login:** Al primer inicio de sesión con `first_login=true`, fuerza cambio de contraseña.
- **Validaciones:** Control de stock al confirmar factura, cliente inactivo bloqueado, permisos por rol.

### 4.6 Rutas por carretera (OSRM)

`RouteService.getRoadRoute(waypoints)` calcula la polilínea por vías con el servidor público de OSRM:

- Base: `https://router.project-osrm.org/route/v1/driving`.
- Exige al menos **2 puntos** `{lat, lng}` en el orden de recorrido.
- Coordenadas en orden **longitud,latitud** (6 decimales), unidas por `;`.
- Parámetros `overview=full` y `geometries=polyline`; decodifica la polilínea con precisión 5.
- Envía `User-Agent: LogiGo-MisterChef/0.1 (proyecto academico)`.
- HTTP 429 → `ApiException` "Demasiadas solicitudes de ruta. Intenta de nuevo en unos segundos."
- `getDirections(...)` es un envoltorio que arma una ruta de **2 puntos** y llama a `getRoadRoute`.
- La atribución `Rutas © OpenStreetMap · OSRM` se muestra solo cuando hay una ruta por carretera válida.

### 4.7 Pantallas de rutas y clientes

- **`route_admin_screen`:** ya **no tiene pestaña "Sugerencias"**. Es una sola pantalla "Gestión de rutas" con el botón **"Distribuir clientes"**, que abre la vista previa.
- **`route_distribution_preview_screen`:** carga la vista previa al abrir (sin escribir nada), muestra el resumen (`Clientes a repartir`, `Vendedores`, `Omitidos`), el cambio por vendedor ("Tiene X → recibirá Y"), los clientes nuevos/cambian y la advertencia de que se reasigna todo desde cero. El botón **"Aplicar distribución"** pide confirmación; si el servidor responde **409**, avisa y recarga la vista previa.
- **`route_screen`:** filtra los clientes inactivos de la ruta y muestra un mensaje claro cuando no hay rutas o no hay clientes asignados.
- **Detalle de empleado:** al desactivar un vendedor indica cuántos clientes quedarán sin asignar y muestra el resultado con los conteos de `released`. La lista de empleados se **recarga al volver del detalle**.
- **Detalle de cliente:** desactivar pide confirmación y explica que dejará de aparecer en la ruta y que al reactivarlo vuelve si el vendedor sigue activo.
- **Formulario de cliente (administrador):** el dropdown de vendedor solo lista **vendedores activos** más **"Sin asignar"**; si el vendedor anterior ya no está activo, la selección vuelve a "Sin asignar".

### 4.8 Pruebas y análisis estático

| Archivo | Pruebas |
|---|---:|
| `api_response_test.dart` | 8 |
| `client_map_logic_test.dart` | 11 |
| `distribution_preview_logic_test.dart` | 11 |
| `location_polling_logic_test.dart` | 4 |
| `location_send_throttle_test.dart` | 9 |
| `road_route_logic_test.dart` | 8 |
| `route_clients_logic_test.dart` | 7 |
| `route_service_test.dart` | 10 |
| **Total** | **68** |

Línea base (13/11/2026):

```powershell
flutter test --no-pub    # +68: All tests passed!
flutter analyze --no-pub # 126 issues: 0 errores, 5 warnings, 121 infos
```

> `location_send_throttle_test.dart` y `route_service_test.dart` se actualizaron para el throttle de 8 s y para OSRM. Los cuatro tests de lógica nueva (`distribution_preview_logic`, `route_clients_logic`, `road_route_logic`, `location_polling_logic`) se agregaron junto con `client_map_logic_test.dart`.

---

## 5. Comunicación API <-> App Flutter

### 5.1 Configuración

- **Base URL:** inyectada en compilación vía `--dart-define-from-file=env/prod.json` (`API_BASE_URL`); en producción apunta a Railway
- **Headers:** `Content-Type: application/json`, `Accept: application/json`, `Authorization: Bearer {token}`
- **Autenticación:** Laravel Sanctum con tokens
- **Timeout:** 15 segundos de conexión
- **Errores:** La app traduce 401/403/404/422/429/5xx y fallos de red a mensajes claros en español (`ApiException`)

### 5.2 Convenciones

- **Listas:** Siempre retornan arrays planos `[...]`, **NO** `{data: [...]}`
- **Cliente detalle:** Incluye `invoices[]` embebido
- **Factura detalle:** Incluye `details[]` con `product` embebido y `audits[]` con `employee` embebido
- **Producto:** Incluye `product_type` embebido
- **Cliente:** Incluye `city.city_name`, `city.department.department_name`, `employee` embebido
- **Rutas vendedor:** Retorna array agrupado por vendedor con `clients[]` (id_ruta, id_client, name, business_name, address, latitude, longitude, phone_number, status). Solo incluye clientes activos y devuelve `[]` si no hay rutas.
- **Distribución:** La vista previa devuelve `fingerprint`, `summary`, `sellers[]` y `skipped[]`; aplicar exige ese `fingerprint` (409 si el reparto cambió).
- **Ubicaciones activas:** Array con `document_employee`, `name`, `latitude`, `longitude`, `last_update`
- **Fechas factura:** Columna `date` es dateTime; la app la interpreta como hora local

---

## 6. Requisitos del Entorno

### 6.1 Backend

| Requisito | Versión Mínima |
|---|---|
| PHP | 8.2 |
| Composer | Última versión |
| MySQL/MariaDB | 5.7+ / 10.3+ (Railway usa MySQL gestionado) |
| Node.js & npm | Para Vite (opcional en desarrollo) |

### 6.2 Frontend

| Requisito | Versión Mínima |
|---|---|
| Flutter SDK | 3.47.7+ (Dart 3.13.5+) |
| Android Studio / VS Code | Recomendado |
| JDK 17 | Para compilar Android (ver `comandos.txt`) |
| Google Maps API Key (Android) | `MAPS_API_KEY` en `android/local.properties` o variable de entorno (mapa base del SDK) |
| Conexión a Internet | Necesaria para OSRM (rutas por carretera) y Google Maps |
| Keystore de firma | `android/key.properties` (para APK release) |

### 6.3 Externos

| Servicio | Uso |
|---|---|
| Railway | Hosting de la API en producción (HTTPS) |
| Groq API | Chatbot con IA (requiere `GROQ_API_KEY`) |
| Google Maps SDK | Mapa base y navegación externa (requiere `MAPS_API_KEY`) |
| OSRM público (`router.project-osrm.org`) | Cálculo de rutas en carretera con datos de OpenStreetMap. Sin llave; uso razonable no comercial, máx. 1 petición por segundo, sin garantías de disponibilidad y con atribución obligatoria |

---

## 7. Instalación y Ejecución

### 7.1 Backend (Laravel)

```bash
# 1. Clonar/ir al proyecto
cd C:\Archivos\Sistemas\MisterChef\misterChefApi

# 2. Instalar dependencias
composer install

# 3. Configurar entorno
cp .env.example .env
# Editar .env con credenciales de BD MySQL

# 4. Generar key
php artisan key:generate

# 5. Crear base de datos MySQL (misterchef)

# 6. Ejecutar migraciones y seeders
php artisan migrate --seed
# En producción: definir ADMIN_PASSWORD antes de seedear

# 7. Levantar servidor (accesible en red)
php artisan serve --host=0.0.0.0 --port=8000
```

> En producción (Railway) la API corre con HTTPS y las variables se configuran en el panel de Railway. `.env.example` ya viene orientado a producción (`APP_ENV=production`, `APP_DEBUG=false`).

### 7.2 Frontend (Flutter)

```powershell
# 1. Ir al proyecto
cd C:\Archivos\Sistemas\MisterChef\MisterChefAPP\mister_chef

# 2. Instalar dependencias
flutter pub get

# 3. Configurar variables de compilación (una sola vez)
Copy-Item env/prod.example.json env/prod.json
# Editar env/prod.json con la API_BASE_URL real (no hay clave de rutas)

# 4. Ejecutar en emulador/dispositivo
flutter run --dart-define-from-file=env/prod.json

# 5. Compilar APK de release
flutter build apk --release --dart-define-from-file=env/prod.json
# Resultado: build/app/outputs/flutter-apk/app-release.apk
```

En Android Studio: **Run > Edit Configurations > Additional run args** → `--dart-define-from-file=env/prod.json`.

### 7.3 Entorno local Windows (comandos.txt)

```powershell
# JDK 17 para Gradle
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
flutter run -d emulator-5554

# Servidor local de la API
php artisan serve --host=0.0.0.0 --port=8000
```

### 7.4 Firma del APK (release)

1. Generar keystore (una sola vez, fuera del repo):
   ```powershell
   keytool -genkey -v -keystore "$env:USERPROFILE\mister-chef-release.jks" `
     -keyalg RSA -keysize 2048 -validity 10000 -alias mister-chef
   ```
2. Copiar `android/key.properties.example` → `android/key.properties` y completar `storeFile` (ruta absoluta), `storePassword`, `keyAlias`, `keyPassword`.
3. Sin `key.properties` el build release **falla con mensaje claro** en lugar de firmar con la clave debug.

Archivos NO versionados: `env/prod.json`, `android/key.properties`, `android/local.properties`, `*.jks`.

---

## 8. Usuarios de Prueba

| Rol | Email | Password | Tipo | Estado | can_modify_invoice | first_login | Notas |
|---|---|---|---|---|---|---|---|
| **Administrador** | `admin@misterchef.com` | `ADMIN_PASSWORD` (local: `admin123`) | `A` | `A` | `S` | `false` | Acceso completo |
| **Vendedor 1** | `vendedor@misterchef.com` | `vendedor123` | `V` | `A` | `S` | `false` | Ruta con 3 clientes asignados |
| **Vendedor 2** | `vendedor2@misterchef.com` | `vendedor123` | `V` | `A` | `S` | `false` | Ruta con 3 clientes asignados |
| **Inactivo** | `inactivo@misterchef.com` | `vendedor123` | `V` | `I` | `N` | `false` | **NO puede iniciar sesión** |

> Empleados nuevos creados desde la app nacen con `first_login = true` y contraseña temporal = número de documento (o la que envíe el admin). La respuesta del `POST /employees` incluye `temp_password`.

---

## 9. Variables de Entorno

### 9.1 Backend (`.env` — base `.env.example`)

```env
APP_NAME=LogiGo
APP_ENV=production   # local en desarrollo
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=misterchef
DB_USERNAME=root
DB_PASSWORD=

SESSION_DRIVER=database
QUEUE_CONNECTION=database
CACHE_STORE=database

MAIL_MAILER=log

# Chatbot IA
GROQ_API_KEY=tu_api_key_aqui
GROQ_URL=https://api.groq.com/openai/v1/chat/completions
GROQ_MODEL=llama-3.1-70b-versatile

# Minutos tras los cuales una ubicación se considera obsoleta en el mapa del admin
# En producción se recomienda 2: el GPS emite cada 10 s
LOCATION_STALE_MINUTES=5

# Contraseña inicial del admin que crea el seeder (obligatoria en producción)
ADMIN_PASSWORD=
```

### 9.2 Frontend (`env/prod.json`)

```json
{
  "API_BASE_URL": "https://misterchefapi-production.up.railway.app/api/v1"
}
```

> Las rutas por carretera se piden a OSRM, que no requiere clave. `MAPS_API_KEY` no va en `env/prod.json`: la lee Gradle desde `android/local.properties` o el entorno.

---

## 10. Flujo de Negocio

### 10.1 Pedidos/Facturas
1. Vendedor crea pedido desde app (`POST /invoices`) → Estado `P` (Pendiente). La fecha la pone el servidor (`now()`). El vendedor solo puede facturar a sus propios clientes (403 si el cliente es de otro o no tiene vendedor).
2. Admin confirma pedido (`PATCH /invoices/{id}/confirm`) → Estado `C` (Confirmada), **se descuenta stock** (se valida stock suficiente por producto)
3. Admin o vendedor anulan (`PATCH /invoices/{id}/cancel`) → Estado `A` (Anulada). Si estaba confirmada, **se restaura stock**
4. Cliente inactivo no puede recibir facturas nuevas
5. Cada acción registra auditoría (`audit_invoice`): tipo C/M/A, estado previo/nuevo, totales y empleado responsable
6. El vendedor solo ve sus propias facturas (las de sus clientes)

### 10.2 Inventario
- Stock se descuenta solo al **confirmar** factura
- Stock se restaura al **anular** factura confirmada
- Productos con `stock <= minimun_stock` aparecen en "Bajo Stock"
- Solo admin puede crear/editar productos; IDs `P####` autogenerados

### 10.3 Rutas y Domicilios

**Distribución automática (vista previa + aplicar)**

1. El administrador entra a **Gestión de rutas** y pulsa **"Distribuir clientes"**. Se abre `route_distribution_preview_screen`.
2. La app llama a `POST /routes/distribution/preview`: **no escribe nada**. Muestra cuántos clientes se repartirán, cuántos vendedores hay, los clientes omitidos por no tener coordenadas y, por vendedor, cuántos tiene hoy y cuántos recibirá ("Tiene X → recibirá Y").
3. La vista previa incluye el `fingerprint` del reparto. Al pulsar **"Aplicar distribución"** se confirma y se envía a `POST /routes/distribution/apply`.
4. Si el reparto cambió entre la vista previa y el aplicar, el servidor responde **409**; la app avisa ("El reparto cambió, se recalculó la vista previa") y recarga la vista previa sin escribir nada.
5. Al aplicar, el servidor hace una **redistribución total desde cero**: agrupa por zonas geográficas con cupos exactos, empareja cada zona con el vendedor que más clientes tiene hoy en ella y **sobrescribe las asignaciones manuales** de los clientes elegibles. No reasigna clientes desactivados ni sin coordenadas y cierra las sugerencias pendientes como rechazadas (`'R'`).

**Asignación manual**

- En el formulario de cliente, el administrador elige vendedor en un dropdown que solo lista **vendedores activos** más la opción **"Sin asignar"**.
- Guardar la asignación sincroniza la tabla `routes`: el cliente aparece en la ruta del vendedor (si ambos están activos) o queda fuera.
- Un vendedor que crea un cliente queda asignado a él mismo.

**Desactivar vendedor**

- Desde el detalle del empleado, la confirmación indica cuántos clientes quedarán sin asignar ("Sus N clientes quedarán sin asignar").
- Al confirmar: se borran sus tokens, sus clientes quedan con `document_employee = null`, se eliminan sus filas de `routes`, sus sugerencias pendientes pasan a `'R'` y su ubicación se marca inactiva.
- La app muestra el resultado real: "Quedaron sin asignar N clientes y se eliminaron M rutas."

**Desactivar cliente**

- La app pide confirmación: "¿Desactivar a …? Dejará de aparecer en la ruta de su vendedor. Al reactivarlo volverá a su ruta si el vendedor sigue activo."
- Desactivar borra su fila de `routes` pero conserva el vendedor; reactivar la recrea si el vendedor sigue activo.

**Ruta del vendedor**

- El vendedor ve solo sus clientes activos (los inactivos se filtran) y un mensaje claro si no tiene ruta.
- La ruta general (`mi_ruta`) se traza por carretera con OSRM (2 a 50 paradas, en el orden de la lista). Si el servicio falla, se dibuja la línea recta y se reintenta en un refresco posterior (≥ 2 s).
- El rastreo GPS se activa automáticamente al abrir la app (splash) o al entrar a la pantalla de ruta, para vendedores.

**Mapa en tiempo real del administrador**

- Refresca solo `GET /location` cada 10 s, sin solapar peticiones, y se pausa en segundo plano.
- Solo muestra vendedores con ubicación fresca (< `LOCATION_STALE_MINUTES`; en producción se recomienda `2`).
- Un 429 en el rastreo no marca error en el vendedor: se ignora y el siguiente evento reintenta.

### 10.4 Chatbot IA
- Usa Groq API con modelo configurable vía `GROQ_MODEL` (default `llama-3.1-70b-versatile`), leído desde `config/services.php`
- El asistente se presenta como **LogiGo**, el asistente inteligente **para la empresa Mister Chef**
- Detecta intención por palabras clave y arma contexto con datos reales de la BD: inventario/stock, clientes de la ruta, reporte del día, semanas sin compra, clientes cercanos (Haversine con la ubicación enviada), recomendaciones de ruta
- Requiere `GROQ_API_KEY` válido
- En producción la llamada a Groq usa HTTPS normal (ya no hay `verify => false`)

---

## 11. Comandos Útiles

### Backend
```bash
# Servidor
php artisan serve --host=0.0.0.0 --port=8000

# Migraciones y seeders
php artisan migrate:fresh --seed

# Solo seeders
php artisan db:seed

# Limpiar caché (importante tras cambios en .env)
php artisan config:clear
php artisan cache:clear
php artisan optimize:clear

# Ver rutas registradas
php artisan route:list --path=api

# Tests
php artisan test --compact
php artisan test --compact --filter=ProductionReadinessTest

# Formateo
vendor/bin/pint --dirty --format agent
```

### Frontend
```powershell
flutter pub get
flutter run --dart-define-from-file=env/prod.json
flutter build apk --release --dart-define-from-file=env/prod.json
flutter clean

# Análisis estático y pruebas
flutter analyze --no-pub
flutter test --no-pub
```

---

## 12. Troubleshooting

| Error | Solución |
|---|---|
| Pantalla "Falta API_BASE_URL" | Compilar con `--dart-define-from-file=env/prod.json` después de crear `env/prod.json` desde el ejemplo |
| La ruta se ve recta | OSRM está caído o respondió 429 (máx. 1 petición/s). Esperar y refrescar: el reintento ocurre en un refresco posterior (≥ 2 s). La línea recta es el respaldo |
| Mapa gris o con marca de agua | Revisar `MAPS_API_KEY` y que la facturación del proyecto de Google Maps (SDK) esté activa |
| Build release falla por keystore | Crear `android/key.properties` desde `key.properties.example` con los datos del keystore real |
| 429 "Demasiados intentos" en login | Rate limit de 10 intentos/min; esperar un momento |
| 429 al enviar ubicación | Rate limit de 30 envíos/min en `POST /location`; el throttle de la app (8 s mínimos, stream de 10 s) evita llegar al límite |
| Seeder falla en producción con "ADMIN_PASSWORD no está definida" | Definir `ADMIN_PASSWORD` en las variables de entorno (Railway o `.env`) antes de seedear |
| `The model X has been decommissioned` (Groq) | Cambiar `GROQ_MODEL` en `.env` por uno vigente. Ejecutar `php artisan config:clear` |
| Ubicación del vendedor no aparece en mapa del admin | La ubicación es "obsoleta" tras `LOCATION_STALE_MINUTES` (default 5; se recomienda 2 en producción) o `is_active = false`. Verificar rastreo activo |
| App no conecta a API local | Ejecutar con `--dart-define=API_BASE_URL=http://TU_IP_LAN:8000/api/v1` (o editar `env/prod.json`) y usar la misma red WiFi |
| `Credenciales incorrectas` al login | Verificar usuario activo (`status = 'A'`). Usuario inactivo no puede loguearse |
| Dropdowns vacíos (departamentos/ciudades/productos) | Ejecutar seeders: `php artisan db:seed` |
| El dropdown de vendedor no muestra a alguien | Solo aparecen vendedores activos (`type = 'V'`, `status = 'A'`); los inactivos no se listan |
| 409 al aplicar la distribución | El reparto cambió desde la vista previa; recalcular y volver a aplicar |
| Sesión expira y vuelve al login | Comportamiento normal ante 401: el token dejó de ser válido y la app redirige automáticamente |
| Notificación de ubicación desaparece en Android | Android mató el proceso de la app; limitación conocida del servicio en primer plano |

---

## 13. Glosario, Convenciones y Notas Importantes

### Convenciones del Código
- **Typos intencionales en esquema:** `id_produc_type` (no `id_product_type`), `minimun_stock` (no `minimum_stock`). **NO corregir** sin actualizar toda la app
- **Claves compuestas:** `City` usa `Compoships` para clave compuesta
- **IDs autogenerados:** `CLI###` (ClienteController), `P####` (ProductController), `F####` (máx 5, enviado por la app), `RT######`/`Str::random(8)` (rutas), `SG##########`/`Str::random(10)` (sugerencias), `AUD#######`/`Str::random(10)` (auditorías)
- **Sin timestamps:** Casi todos los modelos tienen `public $timestamps = false` (excepción: `EmployeeLocation`)
- **Laravel Boost:** el backend incluye `boost.json` y `AGENTS.md` con directrices para agentes de IA (reglas Pest, Pint, estructura Laravel 12)

### Estados y Roles
- **Roles empleado:** `A` = Administrador, `V` = Vendedor/Domiciliario
- **Estado empleado:** `A` = Activo, `I` = Inactivo
- **Permiso factura:** `S` = Sí puede modificar/anular, `N` = No
- **Estado factura:** `P` = Pendiente, `C` = Confirmada, `A` = Anulada
- **Estado sugerencia ruta:** `P` = Pendiente, `A` = Aprobada, `R` = Rechazada (flujo legado; la app ya no las gestiona)

### Notas Importantes
- **Nombre del producto:** La app se llama **LogiGo**; **Mister Chef** es la empresa. `pubspec.yaml`, el paquete `mister_chef`, los repos y la URL de Railway conservan el nombre técnico.
- **App Flutter consume JSON crudo:** Usa `Map<String, dynamic>`; los archivos en `lib/models/`, la mayoría de `providers/` y `widgets/` son stubs vacíos (0 bytes)
- **Sanctum tokens:** Persistidos en SharedPreferences
- **GPS tracking:** Solo vendedores (`type = 'V'`) envían ubicación; servicio en primer plano en Android con notificación "LogiGo"
- **Distribución rutas:** Solo admin puede distribuir; el flujo actual es vista previa + aplicar (redistribución total por zonas) y no usa los endpoints legado
- **Tabla `routes`:** la API intenta mantener una fila por cliente activo con vendedor activo, pero la tabla no lo impone y pueden quedar filas obsoletas (ver 3.4.2)
- **Tests Flutter:** `test/*.dart` (8 archivos, 68 pruebas) — correr con `flutter test --no-pub`; el análisis estático da 126 issues (0 errores, 5 warnings, 121 infos)
- **Supabase:** `supabase_flutter` está declarado en `pubspec.yaml` pero aún no se usa en el código
- **Producción:** API en Railway con HTTPS; el chatbot ya usa verificación SSL normal (el `verify => false` fue eliminado)
- **Seguridad:** Ninguna clave (Groq, Maps) ni keystore se versiona en Git. OSRM no usa clave
- **Atribución OSRM:** La interfaz muestra `Rutas © OpenStreetMap · OSRM`; es obligatoria al usar el servidor público

---

## 14. Trabajo en Curso y Limitaciones Conocidas

**Estado:** los 9 ítems del ciclo están implementados (código, pruebas automatizadas y `flutter analyze`), pero **falta la prueba manual en dispositivo real** de cada flujo.

### 14.1 Ítems implementados

| # | Ítem | Estado |
|---|---|---|
| 1 | Renombre visible a **LogiGo** (Mister Chef como empresa), conservando identificadores técnicos | Implementado, pendiente de prueba manual |
| 2 | Rutas por carretera con **OSRM/OpenStreetMap** en lugar de Google Routes, con atribución visible | Implementado, pendiente de prueba manual |
| 3 | GPS cada **10 s** con envío mínimo de **8 s** y notificación "LogiGo" | Implementado, pendiente de prueba manual |
| 4 | Polling del mapa del administrador cada 10 s, sin solapar y pausado en segundo plano | Implementado, pendiente de prueba manual |
| 5 | **Vista previa + aplicar** de la distribución, con `fingerprint` y manejo del 409 | Implementado, pendiente de prueba manual |
| 6 | Algoritmo de distribución **por zonas** (cupos exactos, refinamiento y emparejamiento) | Implementado, pendiente de prueba manual |
| 7 | Reglas de **asignación manual** y cambio de estado de clientes con sincronización de `routes` | Implementado, pendiente de prueba manual |
| 8 | Validación de propiedad en `POST /invoices` (el vendedor solo factura a sus clientes) | Implementado, pendiente de prueba manual |
| 9 | Limpieza de `employee_location` | **Cerrado sin cambios**: la tabla guarda una sola fila por empleado (`updateOrCreate`), no hay historial que limpiar |

### 14.2 Limitaciones conocidas vigentes

- **OSRM público:** el servidor demo no ofrece garantías de disponibilidad y limita a ~1 petición por segundo; si falla, la ruta se dibuja en línea recta.
- **Mapa base:** depende del SDK de Google Maps y de `MAPS_API_KEY`; si la llave o la facturación fallan, el mapa se ve gris o con marca de agua.
- **Endpoints legado:** `POST /routes/distribute` y las rutas de `route-suggestions` (listar/aprobar/rechazar) siguen vivos en el servidor aunque la app ya no los use.
- **Android:** el sistema puede espaciar las ubicaciones para ahorrar batería, incluso con el intervalo configurado.
- **iOS:** el intervalo de 10 s no se aplica; `LocationSettings` no expone `intervalDuration` y el sistema decide la frecuencia.
- **Orden de visita:** no se optimiza automáticamente; el vendedor elige el orden y la ruta se traza en el orden de la lista.
- **Alcance del reparto:** los clientes sin coordenadas quedan fuera (se listan como omitidos) y los desactivados no se reasignan.

**Limitaciones resueltas (retiradas de esta sección):** la distribución actual asigna todos los clientes elegibles sin pasos de aprobación manual; `approve`/`reject` validan administrador y vendedor destino activo; la asignación manual sincroniza `routes`; `GET /clients` restringe al vendedor a sus clientes; el algoritmo ya no reparte solo por cantidad sino por zonas geográficas; y `POST /invoices` ya valida que el vendedor solo facture a sus clientes.

---

**Fecha de actualización:** 13 de noviembre de 2026
**Proyecto:** LogiGo (para Mister Chef) - Sistema de Gestión de Distribución a Domicilio
**Repositorios:** `misterChefApi` (Laravel, Railway) + `MisterChefAPP/mister_chef` (Flutter)
