# 🖨️ Simple Message Printer

Un proyecto completo que demuestra cómo implementar CI/CD automático con GitHub Actions y Google Cloud Functions para un servicio simple de impresión de mensajes.

## 📋 Tabla de Contenidos

- [🎯 Objetivo del Proyecto](#-objetivo-del-proyecto)
- [🏗️ Arquitectura](#️-arquitectura)
- [📁 Estructura del Proyecto](#-estructura-del-proyecto)
- [🚀 Quick Start](#-quick-start)
- [🔧 Setup Detallado](#-setup-detallado)
- [💻 Desarrollo Local](#-desarrollo-local)
- [🚀 Deployment](#-deployment)
- [🧪 Testing](#-testing)
- [📊 Monitoreo](#-monitoreo)
- [🔒 Seguridad](#-seguridad)
- [📚 Documentación Técnica](#-documentación-técnica)

## 🎯 Objetivo del Proyecto

Este proyecto fue creado para demostrar cómo implementar un **pipeline completo de CI/CD** usando tecnologías modernas:

### ✅ Lo que hace este proyecto:
- **Funcionalidad Simple**: Imprime mensajes con diferentes formatos
- **CI/CD Automático**: Deployment automático en cada push a GitHub
- **Infraestructura Real**: Usa Google Cloud Functions Gen2
- **Best Practices**: Implementa testing, linting, y documentación completa
- **Template Reutilizable**: Sirve como base para proyectos más complejos

### 🎓 Lo que aprendes implementando esto:
- **GitHub Actions** workflows avanzados
- **Google Cloud Functions** deployment y configuración
- **Service Accounts** y manejo de permisos en GCP
- **Secrets Management** en GitHub
- **Testing automatizado** y quality gates
- **Infraestructura como Código**

## 🏗️ Arquitectura

```mermaid
graph TB
    A[👨‍💻 Developer] -->|git push| B[📤 GitHub Repository]
    B -->|trigger| C[⚙️ GitHub Actions]
    C -->|authenticate| D[🔐 Service Account]
    D -->|deploy| E[☁️ Google Cloud Functions]
    E -->|serves| F[🌐 HTTP Endpoint]
    F -->|responds| G[📱 Client Applications]
    
    H[🔧 Environment Variables] --> C
    I[🧪 Automated Tests] --> C
    J[📊 Monitoring & Logs] --> E
```

### 🔄 Flujo de CI/CD

1. **Push a GitHub** → Trigger automático del workflow
2. **Validación** → Tests, linting, y quality checks
3. **Build** → Preparación de archivos para deployment
4. **Deploy** → Creación/actualización de Cloud Function
5. **Testing** → Verificación automática del deployment
6. **Notificación** → Resumen y resultados

## 📁 Estructura del Proyecto

```
CI-CD-simple-message-printer/
├── 📁 .github/workflows/           # GitHub Actions
│   └── deploy-cloud-function.yml   # Pipeline principal
├── 📁 cloud_functions/             # Código para Cloud Functions
│   ├── main.py                     # Entry point
│   └── requirements.txt            # Dependencies
├── 📁 src/                         # Código fuente
│   ├── 📁 printer/                 # Módulo principal
│   │   ├── __init__.py
│   │   ├── message_printer.py      # Lógica de negocio
│   │   └── config.py               # Configuración
│   └── 📁 utils/                   # Utilidades
│       ├── __init__.py
│       └── logger.py               # Logging
├── 📁 scripts/                     # Scripts de automatización
│   ├── setup_ci_cd.sh             # Setup unificado (NUEVO)
│   ├── test_local.sh              # Testing local
│   ├── test_with_service_account.sh # Testing con autenticación
│   ├── deploy_manual.sh           # Deploy manual
│   └── check_service_accounts_fixed.sh # Análisis de SAs
├── 📁 tests/                       # Tests unitarios
│   ├── __init__.py
│   └── test_printer.py
├── .gitignore
├── README.md
├── requirements.txt               # Dependencies del proyecto
└── env_example.sh                # Variables de ejemplo
```

## 🚀 Quick Start

### 1️⃣ Crear el Proyecto

```bash
# Clonar o crear el repositorio
git clone <your-repo-url>
cd CI-CD-simple-message-printer

# 🐍 CREAR ENTORNO VIRTUAL (CRÍTICO)
python -m venv venv
source venv/bin/activate  # macOS/Linux
# o venv\Scripts\activate  # Windows

# Verificar entorno virtual activo
which python  # Debe apuntar a venv/
pip install --upgrade pip
pip install -r requirements.txt

# Verificar instalación
python -c "import functions_framework; print('✅ Setup OK')"
```

### 2️⃣ Setup de Google Cloud (NUEVO SCRIPT UNIFICADO)

🎯 **Ahora tienes 3 opciones para configurar Google Cloud:**

#### **Opción A: Modo Interactivo (Recomendado)**
```bash
# Dar permisos de ejecución
chmod +x scripts/setup_ci_cd.sh

# Ejecutar en modo interactivo - te guía paso a paso
./scripts/setup_ci_cd.sh

# El script te preguntará:
# 1. ¿Crear nueva Service Account o usar una existente?
# 2. Si eliges existente, te mostrará las disponibles
# 3. Te ayuda a elegir la mejor opción
```

#### **Opción B: Crear nueva Service Account directamente**
```bash
./scripts/setup_ci_cd.sh --create-new
```

#### **Opción C: Usar Service Account existente**
```bash
# Primero ver qué Service Accounts tienes disponibles
./scripts/check_service_accounts_fixed.sh

# Luego usar una específica
./scripts/setup_ci_cd.sh --use-existing admin-sa@your-project.iam.gserviceaccount.com
```

#### **🔑 IMPORTANTE: Conservar la Clave JSON**
Cuando ejecutes el script de setup, **NO elimines** el archivo JSON cuando te pregunte:

```bash
🧹 ¿Eliminar archivo JSON local por seguridad? (y/n)
# Responde: n

📁 Archivo conservado: github-actions-key-YYYYMMDD_HHMMSS.json
⚠️  IMPORTANTE: NO commitees este archivo a Git
```

**¿Por qué conservar la clave?**
- ✅ **Testing Local**: La necesitarás para probar la función localmente
- ✅ **Desarrollo**: Permite autenticación local sin regenerar claves
- ✅ **Debugging**: Facilita troubleshooting de permisos

#### **¿Qué hace el script automáticamente?**
- ✅ **Analiza tu proyecto** → Ve qué Service Accounts ya existen
- ✅ **Evalúa permisos** → Recomienda la mejor Service Account
- ✅ **Habilita APIs** → Configura todas las APIs necesarias
- ✅ **Gestiona permisos** → Asigna roles si crea nueva SA
- ✅ **Genera claves** → Crea JSON para GitHub Secrets Y desarrollo local
- ✅ **Da instrucciones** → Te dice exactamente qué hacer después

### 3️⃣ Configurar GitHub Secrets

El script de setup te dará **exactamente** qué copiar. Ve a GitHub: `Settings > Secrets and Variables > Actions`

**Secrets REQUERIDOS:**
```
GCP_SA_KEY: {"type":"service_account",...}  # JSON que te da el script
GCP_PROJECT_ID: your-gcp-project-id
```

**Secrets OPCIONALES:**
```
LOG_LEVEL: INFO
DEFAULT_MESSAGE: Hello from Simple Message Printer!
DEFAULT_USER: World
MESSAGE_PREFIX: 🖨️
```

### 4️⃣ Activar CI/CD

```bash
# Push para activar el pipeline
git add .
git commit -m "🚀 Initial setup - Simple Message Printer"
git push origin main

# Ver el deployment en GitHub Actions tab
```

### 5️⃣ Usar la Function (Con Autenticación IAM Requerida)

⚠️ **IMPORTANTE: Esta Cloud Function requiere autenticación IAM**

Tu función está configurada con **autenticación requerida**, lo que significa que solo usuarios autorizados pueden acceder a ella.

#### **👥 Usuarios Autorizados Automáticamente:**
- Service Account del proyecto (para automation)
- Usuario configurado en el workflow (tu email)

#### **🔐 Solución: Usar Service Account para Autenticación**

El workflow de GitHub Actions funciona porque usa un **Service Account**, no una cuenta de usuario. Para replicar esto localmente, tienes 2 opciones:

##### **Opción 1: Usar Service Account Localmente (Recomendado)**

```bash
# 1. Usar la clave JSON que conservaste del setup inicial
SA_KEY_FILE="github-actions-key-YYYYMMDD_HHMMSS.json"  # El archivo que conservaste
SA_EMAIL="service_account_email"

# 2. Activar el Service Account localmente
gcloud auth activate-service-account "$SA_EMAIL" \
  --key-file="$SA_KEY_FILE"

# 3. Obtener URL de la función
FUNCTION_URL=$(gcloud functions describe function_name \
  --gen2 --region=us-central1 --format="value(serviceConfig.uri)")

# 4. Generar identity token (ahora SÍ funciona con Service Account)
ID_TOKEN=$(gcloud auth print-identity-token --audiences="$FUNCTION_URL")

# 5. Usar la función
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{"mode": "simple", "message": "Hello from Service Account!", "user": "LocalTest"}'

# 6. IMPORTANTE: Volver a tu cuenta personal después del test
gcloud auth login
```

##### **Opción 3: Hacer la Función Pública Temporalmente**

```bash
# SOLO para desarrollo - hacer función pública temporalmente
gcloud run services add-iam-policy-binding simple-message-printer-development \
  --region=us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"

# Ahora puedes usar sin autenticación
curl -X POST "https://simple-message-printer-development-XXXXXX-uc.a.run.app" \
  -H "Content-Type: application/json" \
  -d '{"mode": "simple", "message": "Hello Public!", "user": "LocalTest"}'

# IMPORTANTE: Revertir cuando termines
gcloud run services remove-iam-policy-binding simple-message-printer-development \
  --region=us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"
```

#### **🔧 Troubleshooting de Autenticación**

**Error: "401 Unauthorized" con Cloud Functions Gen2**
```bash
# Este error indica que estás usando access token en lugar de identity token
# Solución: Usar Service Account para generar identity token

# Verificar que tienes la clave JSON del setup
ls -la github-actions-key*.json

# Si no la tienes, regenerar:
gcloud iam service-accounts keys create sa-key.json \
  --iam-account="github-actions-deployer@your-project.iam.gserviceaccount.com"
```

**Error: "Invalid account type for --audiences"**
```bash
# Este error significa que estás usando una cuenta de usuario, no Service Account
# Solución: Activar Service Account primero

gcloud auth activate-service-account SERVICE_ACCOUNT_EMAIL \
  --key-file=github-actions-key-YYYYMMDD_HHMMSS.json

# Luego generar identity token
ID_TOKEN=$(gcloud auth print-identity-token --audiences="$FUNCTION_URL")
```

**¿Por qué pasa esto?**

**Diferencias entre cuentas de usuario y Service Accounts:**

1. **Cuentas de Usuario** (`tu-email@empresa.com`):
   - ❌ **NO** pueden generar `identity tokens`
   - ✅ Pueden generar `access tokens` 
   - ❌ `Access tokens` NO funcionan para Cloud Functions Gen2 con IAM

2. **Service Accounts** (`github-actions-deployer@...`):
   - ✅ **SÍ** pueden generar `identity tokens`
   - ✅ `Identity tokens` funcionan perfectamente para Cloud Functions Gen2

#### **👥 Gestión de Usuarios Autorizados (Cloud Functions Gen2)**

**Ver usuarios con acceso actual:**
```bash
gcloud functions get-iam-policy simple-message-printer-production \
  --region=us-central1
```

**Agregar nuevo usuario autorizado (Gen2):**
```bash
# Comando específico para Cloud Functions Gen2
gcloud functions add-invoker-policy-binding simple-message-printer-production \
  --region=us-central1 \
  --member="user:nuevo-usuario@empresa.com"

# También para el servicio Cloud Run subyacente
gcloud run services add-iam-policy-binding simple-message-printer-production \
  --region=us-central1 \
  --member="user:nuevo-usuario@empresa.com" \
  --role="roles/run.invoker"
```

**Remover acceso de usuario:**
```bash
gcloud functions remove-invoker-policy-binding simple-message-printer-production \
  --region=us-central1 \
  --member="user:usuario@empresa.com"
```

**Agregar grupo de Google Workspace:**
```bash
gcloud functions add-invoker-policy-binding simple-message-printer-production \
  --region=us-central1 \
  --member="group:data-team@empresa.com"
```

## 🔧 Setup Detallado

### 📋 Prerequisites

- **Google Cloud Account** con billing habilitado
- **GitHub Account** con repositorio
- **gcloud CLI** instalado y autenticado
- **Git** configurado
- **Python 3.11+** instalado

### 🎯 **Opciones de Setup (Nuevo Sistema Unificado)**

El nuevo script `setup_ci_cd.sh` maneja **ambos casos** automáticamente:

#### **📊 Análisis Automático de Service Accounts**

```bash
# Ver análisis detallado de todas las Service Accounts disponibles
./scripts/check_service_accounts_fixed.sh
```

Este script:
- 📋 **Lista todas las SAs** en tu proyecto
- 🔍 **Analiza permisos** de cada una  
- ⭐ **Recomienda** cuáles son mejores para CI/CD
- 📊 **Clasifica** como: PERFECTA, EXCELENTE, BUENA, LIMITADA

#### **🚀 Setup Unificado Inteligente**

```bash
# Modo interactivo - te guía en la decisión
./scripts/setup_ci_cd.sh

# O modos directos:
./scripts/setup_ci_cd.sh --create-new                    # Crear nueva SA
./scripts/setup_ci_cd.sh --use-existing SA_EMAIL        # Usar SA existente
./scripts/setup_ci_cd.sh --help                         # Ver todas las opciones
```

**El script detecta automáticamente:**
- ✅ Si tienes permisos para crear Service Accounts
- ✅ Qué Service Accounts ya existen y sus permisos
- ✅ Cuál es la mejor opción para tu situación
- ✅ Qué APIs están habilitadas/faltan
- ⚠️ Si hay problemas de permisos y cómo solucionarlos

### 🐍 Configuración de Entorno Virtual de Python

**¿Por qué usar un entorno virtual?**
- **Aislamiento**: Evita conflictos entre dependencies de diferentes proyectos
- **Reproducibilidad**: Garantiza que todos usen las mismas versiones
- **Limpieza**: Mantiene tu sistema Python limpio
- **Portabilidad**: Fácil de recrear en otras máquinas

#### 📦 Creación del entorno virtual

**Método 1: venv (recomendado, incluido en Python)**
```bash
# 1. Verificar versión de Python
python --version
# Debe ser 3.11 o superior

# 2. Crear entorno virtual
python -m venv venv
# Esto crea una carpeta 'venv' con el entorno aislado

# 3. Activar entorno virtual
# En Windows:
venv\Scripts\activate

# En macOS/Linux:
source venv/bin/activate

# 4. Verificar activación
# El prompt debe mostrar (venv) al inicio
which python  # macOS/Linux
where python   # Windows
# Debe apuntar a venv/bin/python o venv\Scripts\python.exe

# 5. Actualizar pip en el entorno virtual
python -m pip install --upgrade pip
```

#### 📚 Instalación de dependencies

```bash
# Con entorno virtual activado:

# 1. Instalar dependencies del proyecto
pip install -r requirements.txt

# 2. Verificar instalación
pip list
# Debe mostrar: functions-framework, flask, pytest, flake8

# 3. Para desarrollo local adicional (opcional):
pip install ipython      # REPL mejorado
pip install black        # Code formatter
pip install mypy         # Type checker
```

### 🔧 Instalación de gcloud CLI

Si no tienes gcloud CLI instalado:

**🖥️ Windows:**
```bash
# Descargar desde: https://cloud.google.com/sdk/docs/install-sdk#windows
# O usando winget:
winget install Google.CloudSDK
```

**🍎 macOS:**
```bash
# Usando Homebrew (recomendado):
brew install --cask google-cloud-sdk
```

**🐧 Linux:**
```bash
# Ubuntu/Debian:
sudo snap install google-cloud-cli --classic

# CentOS/RHEL/Fedora:
sudo dnf install google-cloud-cli
```

#### 🔐 Autenticación inicial de gcloud

```bash
# 1. Autenticarse con tu cuenta de Google
gcloud auth login

# 2. Verificar autenticación
gcloud auth list

# 3. Configurar proyecto por defecto
gcloud config set project your-project-id

# 4. Verificar configuración
gcloud config list
```

### 🌍 Configuración de Environments

El proyecto maneja 3 environments automáticamente:

- **`development`**: Feature branches, testing
- **`staging`**: Branch `develop`  
- **`production`**: Branch `main`

Cada environment tiene su propia Cloud Function:
- `simple-message-printer-development`
- `simple-message-printer-staging`
- `simple-message-printer-production`

## 💻 Desarrollo Local

### 🧪 Testing Local

```bash
# ⚠️ IMPORTANTE: Siempre con entorno virtual activado
source venv/bin/activate  # Si no está activado

# Ejecutar tests unitarios
pytest tests/ -v

# Testing de la function localmente (sin autenticación)
./scripts/test_local.sh
# Abre http://localhost:8080

# Testing de la function deployada (con autenticación)
./scripts/test_with_service_account.sh
```

### 🔄 Desarrollo Iterativo

```bash
# Workflow típico de desarrollo:

# 1. Activar entorno virtual (si no está activo)
source venv/bin/activate

# 2. Hacer cambios en src/
code src/printer/message_printer.py  # O tu editor favorito

# 3. Probar cambios localmente
./scripts/test_local.sh

# 4. Ejecutar tests
pytest tests/ -v

# 5. Verificar calidad de código
flake8 src/ --count --select=E9,F63,F7,F82 --show-source --statistics

# 6. Probar con autenticación (opcional)
./scripts/test_with_service_account.sh

# 7. Si todo pasa, commit y push
git add .
git commit -m "✨ Add new functionality"
git push origin feature/new-functionality

# 8. Automáticamente deploya a development environment
```

## 🚀 Deployment

### 🤖 Deployment Automático (Recomendado)

El deployment se hace automáticamente via GitHub Actions:

1. **Push a cualquier branch** → deploya a `development`
2. **Push a `develop`** → deploya a `staging`  
3. **Push a `main`** → deploya a `production`
4. **Manual trigger** → permite elegir environment

### 📊 Monitoring del Deployment

```bash
# Ver logs de GitHub Actions
# GitHub repo → Actions tab

# Ver logs de Cloud Function
gcloud functions logs read simple-message-printer-production \
  --region=us-central1 \
  --limit=50

# Metrics en GCP Console
# Cloud Functions → simple-message-printer-production → Metrics
```

## 🧪 Testing

### 🔬 Tests Unitarios

```bash
# Ejecutar todos los tests
pytest tests/ -v

# Con coverage
pytest tests/ --cov=src --cov-report=html

# Tests específicos
pytest tests/test_printer.py::TestMessagePrinter::test_print_message_basic -v
```

### 🌐 Tests de Integration

#### **Testing Local (Sin Autenticación)**
```bash
# Test del servidor local
./scripts/test_local.sh
# Luego en otra terminal:

FUNCTION_URL="http://localhost:8080"

# Test básico
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{"mode": "test"}'

# Test de múltiples mensajes  
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{"mode": "multiple", "message": "Integration test", "count": 3}'
```

#### **Testing de Función Deployada (Con Autenticación)**
```bash
# Usar el script automatizado (recomendado)
./scripts/test_with_service_account.sh

# O manualmente:
SA_KEY_FILE="github-actions-key-YYYYMMDD_HHMMSS.json"  # Tu archivo conservado
gcloud auth activate-service-account \
  "github-actions-deployer@your-project.iam.gserviceaccount.com" \
  --key-file="$SA_KEY_FILE"

FUNCTION_URL=$(gcloud functions describe simple-message-printer-development \
  --gen2 --region=us-central1 --format="value(serviceConfig.uri)")
ID_TOKEN=$(gcloud auth print-identity-token --audiences="$FUNCTION_URL")

curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{"mode": "environment"}'

# Restaurar tu cuenta
gcloud auth login
```

## 📊 Monitoreo

### 📋 Logs

```bash
# Cloud Function logs
gcloud functions logs read simple-message-printer-production --region=us-central1

# Logs en tiempo real
gcloud functions logs tail simple-message-printer-production --region=us-central1

# Filtrar por severity
gcloud functions logs read simple-message-printer-production \
  --region=us-central1 \
  --filter="severity>=ERROR"
```

### 📈 Metrics

**En GCP Console:**
- Cloud Functions → tu function → Metrics tab
- Monitoring → Dashboards → crear dashboard custom

**Metrics importantes:**
- Invocations per second
- Execution time
- Memory utilization  
- Error rate

## 🔒 Seguridad

### 🔐 Configuración Actual: Function con Autenticación IAM

**Estado actual:** La Cloud Function está configurada con **autenticación requerida** (`--no-allow-unauthenticated`)

**Esto significa:**
- ✅ **Muy seguro** → Solo usuarios autorizados pueden acceder
- ✅ **Auditabilidad** → Todos los accesos son rastreables
- ⚠️ **Requiere tokens** → Necesita autenticación para acceder
- 💡 **Ideal para producción** y ambientes seguros

### 🛡️ Permisos IAM del Service Account

El Service Account tiene **solo** los permisos necesarios:
- `cloudfunctions.admin` - Para deploy de functions
- `cloudbuild.builds.builder` - Para builds
- `logging.admin` - Para logs
- `iam.serviceAccountUser` - Para usar Service Accounts
- `serviceusage.serviceUsageAdmin` - Para gestionar APIs

### 🔑 Gestión de Claves de Service Account

**Buenas prácticas:**
- ✅ **Conservar clave local** para desarrollo (fuera de Git)
- ✅ **Rotar claves** periódicamente
- ✅ **No commitear claves** a repositorios
- ✅ **Usar variables de entorno** para claves en scripts

```bash
# Rotar clave (crear nueva y eliminar anterior)
gcloud iam service-accounts keys create new-key.json \
  --iam-account="github-actions-deployer@your-project.iam.gserviceaccount.com"

# Listar claves existentes
gcloud iam service-accounts keys list \
  --iam-account="github-actions-deployer@your-project.iam.gserviceaccount.com"

# Eliminar clave anterior (después de verificar que la nueva funciona)
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account="github-actions-deployer@your-project.iam.gserviceaccount.com"
```

## 📚 Documentación Técnica

### 🎛️ API Reference

#### POST / (Main endpoint)

**Request Body:**
```json
{
  "mode": "simple|multiple|environment|test",
  "message": "string (optional)",
  "user": "string (optional)",
  "count": "number (optional, max 10)"
}
```

**Modes:**

1. **`simple`** - Un mensaje simple
```json
{"mode": "simple", "message": "Hello!", "user": "Alice"}
```

2. **`multiple`** - Múltiples mensajes numerados
```json
{"mode": "multiple", "message": "Test", "count": 3, "user": "Bob"}
```

3. **`environment`** - Info del entorno de deployment
```json
{"mode": "environment"}
```

4. **`test`** - Health check y validación
```json
{"mode": "test"}
```

**Response:**
```json
{
  "success": true,
  "mode": "simple",
  "results": ["🖨️ [2024-01-15 10:30:00] [PRODUCTION] Hello! - from Alice"],
  "messages_printed": 1,
  "timestamp": "2024-01-15T10:30:00.123Z",
  "environment": "production",
  "function_version": "1.0.0"
}
```

### 🔧 Variables de Entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `LOG_LEVEL` | `INFO` | Nivel de logging |
| `ENVIRONMENT` | `development` | Environment actual |
| `DEFAULT_MESSAGE` | `Hello from Simple Message Printer!` | Mensaje por defecto |
| `DEFAULT_USER` | `World` | Usuario por defecto |
| `MESSAGE_PREFIX` | `🖨️` | Prefijo de mensajes |
| `MAX_MESSAGE_LENGTH` | `1000` | Límite de caracteres |
| `MAX_MESSAGES_PER_REQUEST` | `10` | Límite de mensajes por request |

### 🐛 Troubleshooting

#### ❌ Common Issues

**1. Error 401 "Unauthorized" al probar función**
```bash
# Causa: Usando access token en lugar de identity token
# Solución: Usar Service Account

# Activar Service Account
gcloud auth activate-service-account \
  "github-actions-deployer@your-project.iam.gserviceaccount.com" \
  --key-file="github-actions-key-YYYYMMDD_HHMMSS.json"

# Generar identity token
FUNCTION_URL="your-function-url"
ID_TOKEN=$(gcloud auth print-identity-token --audiences="$FUNCTION_URL")

# Usar con identity token
curl -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"mode": "test"}'
```

**2. Error "Invalid account type for --audiences"**
```bash
# Causa: Intentando generar identity token con cuenta de usuario
# Solución: Usar Service Account primero

# Verificar que tienes la clave JSON
ls -la github-actions-key*.json

# Activar Service Account
gcloud auth activate-service-account SERVICE_ACCOUNT_EMAIL \
  --key-file=github-actions-key-YYYYMMDD_HHMMSS.json
```

**3. Setup script no encuentra Service Accounts**
```bash
# Verificar autenticación y proyecto
gcloud auth list
gcloud config get-value project

# Re-ejecutar análisis
./scripts/check_service_accounts_fixed.sh
```

**4. Deploy falla con "Permission Denied"**
```bash
# Verificar que la Service Account tiene permisos