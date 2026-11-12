# DOCUMENTACIÓN COMPLETA - MISTERCHEF

## 1. Visión General

**MisterChef** es un sistema de gestión para distribución de productos alimentarios a domicilio. Está conformado por:

- **Backend:** API REST desarrollada con Laravel 12 (PHP 8.2), desplegada en **Railway** (producción)
- **Frontend:** Aplicación móvil desarrollada con Flutter (Dart)
- **Autenticación:** Laravel Sanctum con tokens Bearer
- **Comunicación:** HTTP/JSON entre Flutter y Laravel API (HTTPS en producción)

El sistema gestiona empleados, clientes, productos, facturas/pedidos, rutas de domicilio, geolocalización en tiempo real, sugerencias de rutas y un chatbot con IA (Groq).

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
│   └── Models/               # Employee, Client, Product, ProductType, Invoice, Detail,
│                             # Department, City, DeliveryRoute, RouteSuggestion,
│                             # EmployeeLocation, AuditInvoice, User
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
├── tests/                    # Pruebas Pest (incluye ProductionReadinessTest)
├── boost.json                # Config de Laravel Boost (guías para agentes)
├── AGENTS.md                 # Directrices del proyecto para agentes de IA
└── .env                      # Variables de entorno (configuración local)
```

### 2.2 Frontend (MisterChefAPP/mister_chef)

```
mister_chef/
├── env/
│   ├── prod.example.json     # Plantilla de variables de compilación (versionada)
│   └── prod.json             # API_BASE_URL y DIRECTIONS_API_KEY reales (NO versionada)
├── lib/
│   ├── config/
│   │   ├── constants.dart    # Endpoints, claves, roles, estados, timeouts
│   │   ├── app_routes.dart   # Rutas de navegación nombradas
│   │   ├── app_colors.dart   # Colores de la app (claro/oscuro)
│   │   └── app_theme.dart    # Temas Material 3 (Inter / Lexend para dislexia)
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
│   │   │                     # map_widget (stub)
│   │   ├── settings/         # accessibility_screen (settings_screen es stub)
│   │   └── chatbot/          # chatbot_screen
│   ├── services/
│   │   ├── api_service.dart           # Cliente HTTP base (singleton, manejo 401/429/5xx)
│   │   ├── auth_service.dart          # Login, logout, sesión local
│   │   ├── employee_service.dart
│   │   ├── product_service.dart
│   │   ├── customer_service.dart
│   │   ├── order_service.dart
│   │   ├── route_service.dart         # Rutas + Google Routes API v2 (Directions)
│   │   ├── location_service.dart       # Enviar/desactivar ubicación GPS
│   │   ├── tracking_service.dart      # Rastreo en primer plano (ChangeNotifier)
│   │   ├── location_send_throttle.dart # Regla de throttling GPS (25 s mín.)
│   │   ├── chatbot_service.dart
│   │   ├── maps_service.dart          # Marcadores, polilíneas, cámara
│   │   └── storage_service.dart       # Stub vacío
│   ├── utils/                # location_helper.dart (los demás son stubs)
│   └── widgets/              # role_bottom_nav.dart (los demás son stubs)
├── test/
│   ├── api_response_test.dart          # Pruebas de parseApiResponse
│   ├── location_send_throttle_test.dart # Pruebas del throttle GPS
│   └── route_service_test.dart          # Pruebas con http.Client falso
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
| `EmployeeLocation` | `employee_location` | `document_employee` (string) | Sí (updated_at) | GPS en tiempo real. `is_active` boolean. Se actualiza con `updateOrCreate`. |
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
| Clientes | `GET /clients`, `POST /clients`, `GET /clients/{id}`, `PUT /clients/{id}`, `PATCH /clients/{id}/status` |
| Facturas | `GET /invoices` (filtros `?status=` y `?date=`), `GET /invoices/stats`, `POST /invoices`, `GET /invoices/{id}`, `GET /invoices/{id}/audit`, `PATCH /invoices/{id}/confirm`, `PATCH /invoices/{id}/cancel` |
| Geolocalización | `POST /location` (`throttle:30,1`), `GET /location`, `PATCH /location/deactivate`, `GET /departments`, `GET /cities` (filtro `?id_departament=`) |
| Rutas | `GET /routes`, `GET /routes/navigate/{clientId}`, `DELETE /routes/{id}`, `POST /routes/distribute` (Admin), `GET /route-suggestions` (Admin), `PATCH /route-suggestions/{id}/approve`, `PATCH /route-suggestions/{id}/reject` |
| Chatbot | `POST /chatbot` (acepta `latitude`/`longitude` opcionales) |

**Notas de comportamiento:**
- **Facturas por vendedor:** Un vendedor (`type = V`) solo ve las facturas de sus clientes (`GET /invoices`, `GET /invoices/{id}` con 403 si no es suyo, `GET /invoices/stats`).
- **Anular factura:** Pueden anular tanto Admin como Vendedor (`PATCH /invoices/{id}/cancel`).
- **Auditoría:** `GET /invoices/{id}/audit` ordena por `action_date` descendente e incluye `employee` embebido.
- **Ubicaciones obsoletas:** `GET /location` solo devuelve ubicaciones activas actualizadas en los últimos `LOCATION_STALE_MINUTES` (default 5). Respuesta: `document_employee`, `name`, `latitude`, `longitude`, `last_update`.
- **Rechazar sugerencia:** `PATCH /route-suggestions/{id}/reject` requiere `document_employee` en el body para reasignar manualmente.

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

| Archivo | Cubre |
|---|---|
| `SeedDatabaseTest` | Seeders básicos |
| `ProductionReadinessTest` | Ubicaciones obsoletas ocultas del mapa, modelo de Groq desde config, rate limit de `/location` (429 tras 30/min), `ADMIN_PASSWORD` obligatoria en producción |
| `ExampleTest` | Página de bienvenida de Laravel |

Los tests usan SQLite in-memory (`phpunit.xml`).

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
  "API_BASE_URL": "https://misterchefapi-production.up.railway.app/api/v1",
  "DIRECTIONS_API_KEY": "TU_KEY_AQUI"
}
```

- Si falta `API_BASE_URL`, la app muestra una pantalla de ayuda en vez de arrancar rota.
- `API_BASE_URL` se normaliza quitando la barra final si la tiene.
- `DIRECTIONS_API_KEY` se usa desde Dart para la Google Routes API (cálculo de rutas en carretera).
- `MAPS_API_KEY` (distinta) la lee Gradle para el SDK de Google Maps en Android desde `android/local.properties` o variable de entorno.

**Claves SharedPreferences:** `auth_token`, `employee_doc`, `user_name`, `user_role`, `first_login`, `dark_mode`, `font_scale`

**Roles:** `roleAdministrador = 'A'`, `roleVendedor = 'V'`

**Estados factura:** `P` (Pendiente), `C` (Confirmada), `A` (Anulada)

**GPS:** Stream de posiciones cada 30 segundos, envío mínimo cada 25 segundos (`LocationSendThrottle`), timeout HTTP de 15 segundos

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
| `route_service.dart` | Rutas, navegación, distribución, sugerencias + **Google Routes API v2** (`routes.googleapis.com/directions/v2:computeRoutes`) con `DirectionsApiKeyMissingException` |
| `location_service.dart` | Enviar/desactivar ubicación GPS |
| `tracking_service.dart` | Rastreo continuo del domiciliario: stream único con `AndroidSettings` (servicio en primer plano con notificación persistente y wake lock), estados observables (`detenido`, `activo`, `sinPermiso`, `errorRed`), tolerante a fallos de red |
| `location_send_throttle.dart` | Regla pura de throttling (mín. 25 s entre envíos exitosos), testeable sin red |
| `chatbot_service.dart` | Chat con IA (Groq) |
| `maps_service.dart` | Permisos GPS, marcadores (clientes/vendedores), polilíneas, cámara |

### 4.5 Funcionalidades Clave

- **Splash y sesión persistente:** `SplashScreen` verifica el token guardado; si la sesión es de un vendedor **reanuda automáticamente el rastreo GPS** al abrir la app.
- **Tracking GPS en primer plano:** El vendedor comparte ubicación mientras la app viva; en Android corre como servicio en primer plano con notificación ("Compartiendo tu ubicación con la central"). Si la app muere, la notificación también desaparece (limitación conocida).
- **Sesión expirada (401):** Cualquier petición autenticada que reciba 401 limpia la sesión, detiene el rastreo y lleva al login con un SnackBar. El aviso se dispara una sola vez por sesión (`resetUnauthorizedGuard` al iniciar sesión).
- **Logout ordenado:** Detiene el stream local → avisa al servidor (`/location/deactivate`, timeout 5 s) → invalida el token → limpia SharedPreferences.
- **Accesibilidad:** Modo oscuro, escala de fuente (0.7–1.4), fuente Lexend para dislexia y niveles de saturación de color (normal / alta / baja / escala de grises) aplicados a TODA la app mediante `ColorFilter` y `TextScaler`. Persistidas en SharedPreferences.
- **Mapas:** Google Maps para visualizar rutas y mapa de admin en tiempo real; navegación turn-by-turn con Google Maps externo; polilíneas de carretera con Google Routes API v2.
- **First Login:** Al primer inicio de sesión con `first_login=true`, fuerza cambio de contraseña.
- **Validaciones:** Control de stock al confirmar factura, cliente inactivo bloqueado, permisos por rol.

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
- **Rutas vendedor:** Retorna array agrupado por vendedor con `clients[]` (id_ruta, id_client, name, business_name, address, latitude, longitude, phone_number, status)
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
| Google Maps API Key (Android) | `MAPS_API_KEY` en `android/local.properties` o variable de entorno |
| Google Directions API Key | `DIRECTIONS_API_KEY` en `env/prod.json` |
| Keystore de firma | `android/key.properties` (para APK release) |

### 6.3 Externos

| Servicio | Uso |
|---|---|
| Railway | Hosting de la API en producción (HTTPS) |
| Groq API | Chatbot con IA (requiere `GROQ_API_KEY`) |
| Google Maps / Routes API | Mapas, navegación y cálculo de rutas en carretera |

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
# Editar env/prod.json con API_BASE_URL y DIRECTIONS_API_KEY reales

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
APP_NAME=MisterChef
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
LOCATION_STALE_MINUTES=5

# Contraseña inicial del admin que crea el seeder (obligatoria en producción)
ADMIN_PASSWORD=
```

### 9.2 Frontend (`env/prod.json`)

```json
{
  "API_BASE_URL": "https://misterchefapi-production.up.railway.app/api/v1",
  "DIRECTIONS_API_KEY": "TU_DIRECTIONS_API_KEY"
}
```

---

## 10. Flujo de Negocio

### 10.1 Pedidos/Facturas
1. Vendedor crea pedido desde app (`POST /invoices`) → Estado `P` (Pendiente). La fecha la pone el servidor (`now()`).
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
1. Admin distribuye clientes sin ruta (`POST /routes/distribute`) → Algoritmo de proximidad geográfica (Haversine) con balance de carga (penalización de 10 km por cliente extra) → Genera sugerencias
2. Admin aprueba (`approve`) o rechaza (`reject`, reasignando manualmente con `document_employee`) las sugerencias
3. Vendedor ve su ruta en mapa con paradas asignadas
4. El rastreo GPS se activa automáticamente: al abrir la app (splash) o al entrar a la pantalla de ruta, para vendedores
5. Admin ve ubicación en tiempo real de los vendedores activos con ubicación fresca (< `LOCATION_STALE_MINUTES`)

### 10.4 Chatbot IA
- Usa Groq API con modelo configurable vía `GROQ_MODEL` (default `llama-3.1-70b-versatile`), leído desde `config/services.php`
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
| `DirectionsApiKeyMissingException` al trazar ruta | Definir `DIRECTIONS_API_KEY` en `env/prod.json` |
| Build release falla por keystore | Crear `android/key.properties` desde `key.properties.example` con los datos del keystore real |
| 429 "Demasiados intentos" en login | Rate limit de 10 intentos/min; esperar un momento |
| 429 al enviar ubicación | Rate limit de 30 envíos/min en `POST /location`; el throttle de la app (25 s) evita llegar al límite |
| Seeder falla en producción con "ADMIN_PASSWORD no está definida" | Definir `ADMIN_PASSWORD` en las variables de entorno (Railway o `.env`) antes de seedear |
| `The model X has been decommissioned` (Groq) | Cambiar `GROQ_MODEL` en `.env` por uno vigente. Ejecutar `php artisan config:clear` |
| Ubicación del vendedor no aparece en mapa del admin | La ubicación es "obsoleta" tras `LOCATION_STALE_MINUTES` (default 5) o `is_active = false`. Verificar rastreo activo |
| App no conecta a API local | Ejecutar con `--dart-define=API_BASE_URL=http://TU_IP_LAN:8000/api/v1` (o editar `env/prod.json`) y usar la misma red WiFi |
| `Credenciales incorrectas` al login | Verificar usuario activo (`status = 'A'`). Usuario inactivo no puede loguearse |
| Dropdowns vacíos (departamentos/ciudades/productos) | Ejecutar seeders: `php artisan db:seed` |
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
- **Estado sugerencia ruta:** `P` = Pendiente, `A` = Aprobada, `R` = Rechazada

### Notas Importantes
- **App Flutter consume JSON crudo:** Usa `Map<String, dynamic>`; los archivos en `lib/models/`, la mayoría de `providers/` y `widgets/` son stubs vacíos (0 bytes)
- **Sanctum tokens:** Persistidos en SharedPreferences
- **GPS tracking:** Solo vendedores (`type = 'V'`) envían ubicación; servicio en primer plano en Android con notificación persistente
- **Distribución rutas:** Solo admin puede distribuir, requiere vendedores activos con clientes sin ruta (y con coordenadas)
- **Tests Flutter:** `test/api_response_test.dart`, `test/location_send_throttle_test.dart`, `test/route_service_test.dart` — correr con `flutter test --no-pub`
- **Supabase:** `supabase_flutter` está declarado en `pubspec.yaml` pero aún no se usa en el código
- **Producción:** API en Railway con HTTPS; el chatbot ya usa verificación SSL normal (el `verify => false` fue eliminado)
- **Seguridad:** Ninguna clave (Groq, Maps, Directions) ni keystore se versiona en Git

---

**Fecha de actualización:** Noviembre 2026
**Proyecto:** MisterChef - Sistema de Gestión de Distribución a Domicilio
**Repositorios:** `misterChefApi` (Laravel, Railway) + `MisterChefAPP/mister_chef` (Flutter)
