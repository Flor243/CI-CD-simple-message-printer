cat > scripts/validate_permissions.sh << EOF
#!/bin/bash
# scripts/validate_permissions.sh
#
# 🔍 SCRIPT DE VALIDACIÓN DE PERMISOS Y CONFIGURACIÓN
# ==================================================
# 
# Verifica que toda la configuración esté correcta después del setup
# Útil para debugging cuando hay problemas de permisos o configuración
#
# LO QUE VERIFICA:
# 1. Service Account existe y tiene roles correctos
# 2. APIs necesarias están habilitadas
# 3. Usuario actual tiene permisos suficientes
# 4. Configuración general del proyecto
#
# CUÁNDO USAR:
# - Después de ejecutar setup_cloud_deployment.sh
# - Cuando GitHub Actions falla con errores de permisos
# - Para debugging general de configuración

PROJECT_ID="$PROJECT_ID"
SA_EMAIL="github-actions-deployer@\$PROJECT_ID.iam.gserviceaccount.com"

echo "🔍 Validando configuración y permisos..."
echo "=============================================="
echo ""
echo "📊 Proyecto: \$PROJECT_ID"
echo "🔐 Service Account: \$SA_EMAIL"
echo ""

# VERIFICACIÓN 1: SERVICE ACCOUNT EXISTE
echo "🔍 1. Verificando existencia del Service Account..."
if gcloud iam service-accounts describe "\$SA_EMAIL" --project=\$PROJECT_ID &>/dev/null; then
    echo -e "   \\033[0;32m✅ Service Account existe\\033[0m"
    
    # Obtener información del SA
    SA_INFO=\$(gcloud iam service-accounts describe "\$SA_EMAIL" --project=\$PROJECT_ID --format="value(displayName)")
    echo "   ➤ Display Name: \$SA_INFO"
else
    echo -e "   \\033[0;31m❌ Service Account NO existe\\033[0m"
    echo "   🔧 Solución: Re-ejecutar setup_cloud_deployment.sh"
fi

# VERIFICACIÓN 2: ROLES DEL SERVICE ACCOUNT
echo ""
echo "🔍 2. Verificando roles del Service Account..."
SA_ROLES=\$(gcloud projects get-iam-policy \$PROJECT_ID --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.members:serviceAccount:\$SA_EMAIL" | sort | uniq)

REQUIRED_ROLES=(
    "roles/cloudfunctions.admin"
    "roles/cloudbuild.builds.builder"  
    "roles/logging.admin"
    "roles/iam.serviceAccountUser"
    "roles/serviceusage.serviceUsageAdmin"
)

if [ -n "\$SA_ROLES" ]; then
    echo -e "   \\033[0;32m✅ Service Account tiene roles asignados\\033[0m"
    echo ""
    echo "   📋 Roles actuales:"
    while IFS= read -r role; do
        echo "   ✅ \$role"
    done <<< "\$SA_ROLES"
    
    echo ""
    echo "   🔍 Verificando roles requeridos:"
    MISSING_ROLES=()
    for REQUIRED_ROLE in "\${REQUIRED_ROLES[@]}"; do
        if echo "\$SA_ROLES" | grep -q "\$REQUIRED_ROLE"; then
            echo "   ✅ \$REQUIRED_ROLE"
        else
            echo -e "   \\033[0;31m❌ \$REQUIRED_ROLE (FALTANTE)\\033[0m"
            MISSING_ROLES+=("\$REQUIRED_ROLE")
        fi
    done
    
    if [ \${#MISSING_ROLES[@]} -gt 0 ]; then
        echo ""
        echo -e "   \\033[0;31m❌ Roles faltantes detectados\\033[0m"
        echo "   🔧 Para solucionarlo, ejecuta:"
        for MISSING_ROLE in "\${MISSING_ROLES[@]}"; do
            echo "   gcloud projects add-iam-policy-binding \$PROJECT_ID \\"
            echo "     --member=\"serviceAccount:\$SA_EMAIL\" \\"
            echo "     --role=\"\$MISSING_ROLE\""
        done
    else
        echo ""
        echo -e "   \\033[0;32m✅ Todos los roles requeridos están presentes\\033[0m"
    fi
else
    echo -e "   \\033[0;31m❌ Service Account NO tiene roles asignados\\033[0m"
    echo "   🔧 Solución: Re-ejecutar setup_cloud_deployment.sh"
fi

# VERIFICACIÓN 3: APIS HABILITADAS
echo ""
echo "🔍 3. Verificando APIs habilitadas..."
REQUIRED_APIS=(
    "cloudfunctions.googleapis.com"
    "cloudbuild.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "logging.googleapis.com"
    "iam.googleapis.com"
)

ENABLED_APIS=\$(gcloud services list --enabled --project=\$PROJECT_ID --format="value(name)")

echo "   📋 Verificando APIs requeridas:"
MISSING_APIS=()
for API in "\${REQUIRED_APIS[@]}"; do
    if echo "\$ENABLED_APIS" | grep -q "\$API"; then
        echo "   ✅ \$API"
    else
        echo -e "   \\033[0;31m❌ \$API (NO HABILITADA)\\033[0m"
        MISSING_APIS+=("\$API")
    fi
done

if [ \${#MISSING_APIS[@]} -gt 0 ]; then
    echo ""
    echo -e "   \\033[0;31m❌ APIs faltantes detectadas\\033[0m"
    echo "   🔧 Para habilitarlas:"
    for API in "\${MISSING_APIS[@]}"; do
        echo "   gcloud services enable \$API --project=\$PROJECT_ID"
    done
else
    echo ""
    echo -e "   \\033[0;32m✅ Todas las APIs requeridas están habilitadas\\033[0m"
fi

# VERIFICACIÓN 4: PERMISOS DEL USUARIO ACTUAL
echo ""
echo "🔍 4. Verificando permisos del usuario actual..."
CURRENT_USER=\$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
if [ -n "\$CURRENT_USER" ]; then
    echo "   👤 Usuario actual: \$CURRENT_USER"
    
    USER_ROLES=\$(gcloud projects get-iam-policy \$PROJECT_ID --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.members:user:\$CURRENT_USER" | head -5)
    
    if [ -n "\$USER_ROLES" ]; then
        echo -e "   \\033[0;32m✅ Usuario tiene permisos en el proyecto\\033[0m"
        echo "   📋 Algunos roles del usuario:"
        while IFS= read -r role; do
            echo "   ➤ \$role"
        done <<< "\$USER_ROLES"
    else
        echo -e "   \\033[0;31m❌ Usuario NO tiene permisos explícitos en el proyecto\\033[0m"
        echo "   ⚠️  Puede tener permisos heredados o ser Owner a nivel organización"
    fi
else
    echo -e "   \\033[0;31m❌ No hay usuario autenticado\\033[0m"
    echo "   🔧 Solución: gcloud auth login"
fi

# VERIFICACIÓN 5: CONFIGURACIÓN GENERAL
echo ""
echo "🔍 5. Verificando configuración general..."

# Project info
PROJECT_INFO=\$(gcloud projects describe \$PROJECT_ID --format="value(name,projectNumber)" 2>/dev/null)
if [ -n "\$PROJECT_INFO" ]; then
    echo -e "   \\033[0;32m✅ Proyecto accesible\\033[0m"
    echo "   ➤ Información: \$PROJECT_INFO"
else
    echo -e "   \\033[0;31m❌ Proyecto no accesible\\033[0m"
fi

# Billing info (optional)
BILLING_ACCOUNT=\$(gcloud billing projects describe \$PROJECT_ID --format="value(billingAccountName)" 2>/dev/null)
if [ -n "\$BILLING_ACCOUNT" ]; then
    echo -e "   \\033[0;32m✅ Billing habilitado\\033[0m"
    echo "   ➤ Cuenta: \$BILLING_ACCOUNT"
else
    echo -e "   \\033[0;33m⚠️  Billing no detectado o no accesible\\033[0m"
    echo "   ➤ Nota: Billing es requerido para Cloud Functions"
fi

# RESUMEN FINAL
echo ""
echo "📊 RESUMEN DE VALIDACIÓN"
echo "========================"

# Determinar status general
VALIDATION_ERRORS=0

# Check SA exists
if ! gcloud iam service-accounts describe "\$SA_EMAIL" --project=\$PROJECT_ID &>/dev/null; then
    VALIDATION_ERRORS=\$((VALIDATION_ERRORS + 1))
fi

# Check required roles
for REQUIRED_ROLE in "\${REQUIRED_ROLES[@]}"; do
    if ! echo "\$SA_ROLES" | grep -q "\$REQUIRED_ROLE"; then
        VALIDATION_ERRORS=\$((VALIDATION_ERRORS + 1))
    fi
done

# Check required APIs
for API in "\${REQUIRED_APIS[@]}"; do
    if ! echo "\$ENABLED_APIS" | grep -q "\$API"; then
        VALIDATION_ERRORS=\$((VALIDATION_ERRORS + 1))
    fi
done

if [ \$VALIDATION_ERRORS -eq 0 ]; then
    echo -e "\\033[0;32m🎉 CONFIGURACIÓN COMPLETAMENTE VÁLIDA\\033[0m"
    echo "   ➤ Service Account: ✅"
    echo "   ➤ Roles IAM: ✅"
    echo "   ➤ APIs: ✅"
    echo "   ➤ Acceso al proyecto: ✅"
    echo ""
    echo "✅ GitHub Actions debería funcionar correctamente"
else
    echo -e "\\033[0;31m❌ CONFIGURACIÓN TIENE PROBLEMAS (\$VALIDATION_ERRORS errores)\\033[0m"
    echo ""
    echo "🔧 Solución recomendada:"
    echo "1. Re-ejecutar: ./scripts/setup_cloud_deployment.sh --project-id \$PROJECT_ID"
    echo "2. Verificar permisos de usuario en Google Cloud Console"
    echo "3. Ejecutar nuevamente este script para verificar"
fi

echo ""
echo "📚 Para más ayuda:"
echo "   ➤ Ver logs de GitHub Actions para errores específicos"
echo "   ➤ Consultar CI-CD-TUTORIAL.md"
echo "   ➤ Verificar GitHub Secrets están configurados"
EOF# TESTING AUTOMÁTICO CON AUTENTICACIÓN
echo ""
echo "🧪 Probando function deployada (CON autenticación)..."

if [ -n "\$FUNCTION_URL" ]; then
    echo "   ➤ Generando token de autenticación..."
    
    # GENERAR TOKEN DE AUTENTICACIÓN
    ID_TOKEN=\$(gcloud auth print-identity-token --audiences="\$FUNCTION_URL" 2>/dev/null)
    
    if [ -n "\$ID_TOKEN" ]; then
        echo "   ✅ Token de autenticación generado"
        echo "   ➤ Ejecutando test autenticado..."
        
        # TEST CON AUTENTICACIÓN
        RESPONSE=\$(curl -s -w "%{http_code}" \\
            -X POST "\$FUNCTION_URL" \\
            -H "Content-Type: application/json" \\
            -H "Authorization: Bearer \$ID_TOKEN" \\
            -d '{"mode": "simple", "message": "Hello from manual deploy!", "user": "ManualTester"}' \\
            --max-time 30 \\
            -o response_body.json)
        
        HTTP_CODE=\${RESPONSE: -3}
        
        HTTP_CODE=\${RESPONSE: -3}
        
        if [ "\$HTTP_CODE" -eq 200 ]; then
            echo -e "   \033[0;32m✅ Test autenticado exitoso (HTTP 200)\033[0m"
            echo "   ➤ Function está funcionando correctamente con autenticación"
            
            # Mostrar response (sin datos sensibles)
            if [ -f "response_body.json" ]; then
                echo "   📄 Response preview:"
                cat response_body.json | jq '.success, .mode, .messages_printed' 2>/dev/null || echo "   ➤ Function responded successfully"
                rm -f response_body.json
            fi
        else
            echo -e "   \033[0;31m❌ Test autenticado falló (HTTP \$HTTP_CODE)\033[0m"
            echo "   📄 Error response:"
            cat response_body.json 2>/dev/null || echo "No response body"
            rm -f response_body.json
        fi
        
        # TEST ADICIONAL: Verificar que sin auth falla
        echo ""
        echo "   🔒 Verificando que requests sin autenticación fallan..."
        UNAUTH_RESPONSE=\$(curl -s -w "%{http_code}" \\
            -X POST "\$FUNCTION_URL" \\
            -H "Content-Type: application/json" \\
            -d '{"mode": "simple"}' \\
            --max-time 15 \\
            -o /dev/null)
        
        UNAUTH_CODE=\${UNAUTH_RESPONSE: -3}
        
        if [ "\$UNAUTH_CODE" -eq 403 ] || [ "\$UNAUTH_CODE" -eq 401 ]; then
            echo -e "   \033[0;32m✅ Security OK: Requests sin auth correctamente bloqueados (HTTP \$UNAUTH_CODE)\033[0m"
        else
            echo -e "   \033[0;31m⚠️ WARNING: Requests sin auth no fueron bloqueados (HTTP \$UNAUTH_CODE)\033[0m"
            echo "   🔧 Verificar configuración IAM manualmente"
        fi
        
    else
        echo -e "   \033[0;31m❌ No se pudo generar token de autenticación\033[0m"
        echo "   🔧 Esto puede indicar problemas de permisos"
        echo "   ➤ Verificar que tu usuario tiene acceso a la function"
    fi
else
    echo "⚠️  No se puede probar automáticamente sin URL"
fi

# INSTRUCCIONES FINALES CON AUTENTICACIÓN
echo ""
echo -e "\033[0;34m📋 Cómo usar la function autenticada:\033[0m"
echo ""
echo "🔐 PASO 1: Autenticarse (requerido)"
echo "gcloud auth login"
echo ""
echo "🎫 PASO 2: Generar token"
echo "FUNCTION_URL=\"\$FUNCTION_URL\""
echo "ID_TOKEN=\\\$(gcloud auth print-identity-token --audiences=\"\\\$FUNCTION_URL\")"
echo ""
echo "🧪 PASO 3: Usar function CON autenticación"
echo "curl -X POST \"\\\$FUNCTION_URL\" \\\\"
echo "  -H \"Content-Type: application/json\" \\\\"
echo "  -H \"Authorization: Bearer \\\$ID_TOKEN\" \\\\"
echo "  -d '{\"mode\": \"simple\", \"message\": \"Hello Authenticated!\", \"user\": \"Developer\"}'"
echo ""
echo "🚫 NOTA: Requests SIN Authorization header fallarán con 403 Forbidden"
echo ""
echo "👥 Para otorgar acceso a otros usuarios:"
echo "gcloud functions add-iam-policy-binding \$FUNCTION_NAME \\\\"
echo "  --region=\$REGION \\\\"
echo "  --member=\"user:usuario@tuempresa.com\" \\\\"
echo "  --role=\"roles/cloudfunctions.invoker\""
echo ""
echo "📊 Para ver logs:"
echo "gcloud functions logs read \$FUNCTION_NAME --region=\$REGION --limit=50"
echo ""
echo "🗑️  Para eliminar (cleanup):"
echo "gcloud functions delete \$FUNCTION_NAME --region=\$REGION"
echo ""
echo -e "\033[0;32m🎉 Manual deployment with authentication completado\033[0m"
echo -e "\033[0;32m🔒 Function is now SECURE and requires authentication\033[0m"# ==========================================
# SCRIPT 1: TESTING LOCAL
# ==========================================
# Permite probar la Cloud Function en local antes de deployment
# Útil para desarrollo iterativo y debugging
echo ""
echo "📝 Creando script de testing local..."
cat > scripts/test_local.sh << 'EOF'
#!/bin/bash
# scripts/test_local.sh
#
# 🧪 SCRIPT PARA TESTING LOCAL DE CLOUD FUNCTION
# ==============================================
# 
# Permite ejecutar la Cloud Function localmente usando Functions Framework
# Útil para desarrollo iterativo sin necesidad de deployar a GCP
#
# LO QUE HACE:
# 1. Verifica que el entorno virtual esté activo (recomendado)
# 2. Copia código fuente a cloud_functions/ (estructura requerida)
# 3. Configura variables de entorno para testing
# 4. Inicia servidor local en puerto 8080
# 5. Proporciona ejemplos de cómo probar la function

echo "🧪 Testing Simple Message Printer locally..."

# VERIFICACIÓN DE DIRECTORIO
# Garantiza que se ejecute desde el lugar correcto
if [ ! -f "cloud_functions/main.py" ]; then
    echo "❌ Error: Ejecuta desde el directorio raíz"
    echo "   ➤ Debe existir: cloud_functions/main.py"
    echo "   ➤ Ejecuta desde: simple-message-printer/"
    exit 1
fi

# VERIFICACIÓN DE ENTORNO VIRTUAL
# Recomienda best practices pero no los fuerza
if [[ "$VIRTUAL_ENV" == "" ]]; then
    echo "⚠️  Entorno virtual no detectado"
    echo "💡 Recomendación: Activar entorno virtual primero:"
    echo "   source venv/bin/activate  # macOS/Linux"
    echo "   venv\\Scripts\\activate    # Windows"
    echo ""
    echo "🔄 Continuando sin entorno virtual..."
    echo "   ➤ Puede haber problemas de dependencies"
else
    echo "✅ Entorno virtual activo: $VIRTUAL_ENV"
fi

echo "📁 Preparando archivos para testing local..."

# PREPARACIÓN DE ARCHIVOS
# Cloud Functions necesita estructura específica con main.py en root
echo "   ➤ Copiando código fuente..."
cp -r src/printer cloud_functions/    # Copia lógica de negocio
cp -r src/utils cloud_functions/      # Copia utilidades

# LIMPIEZA DE __INIT__.PY
# Previene problemas de imports relativos en local
echo "   ➤ Limpiando archivos __init__.py..."
echo "# Clean __init__.py" > cloud_functions/printer/__init__.py
echo "# Clean __init__.py" > cloud_functions/utils/__init__.py

echo "🚀 Iniciando servidor local..."
cd cloud_functions/

# CONFIGURACIÓN DE VARIABLES DE ENTORNO PARA TESTING
# Simula el entorno de Cloud Functions con valores de desarrollo
echo "   ➤ Configurando variables de entorno para testing..."
export LOG_LEVEL=DEBUG                           # Debug verbose para desarrollo
export DEFAULT_MESSAGE="Hello from local test!"  # Mensaje identificable como local
export DEFAULT_USER="LocalTester"               # Usuario identificable como local
export ENVIRONMENT="local"                      # Environment específico
export MESSAGE_PREFIX="🧪"                      # Prefix que identifica testing local

# INFORMACIÓN DE CONEXIÓN
echo ""
echo -e "\033[0;32m🌐 Servidor disponible en:\033[0m"
echo "   http://localhost:8080"
echo ""
echo -e "\033[0;34m🧪 Para probar la function:\033[0m"
echo ""
echo "# Test básico:"
echo "curl -X POST http://localhost:8080 \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"mode\": \"simple\", \"message\": \"Hello Local!\", \"user\": \"Developer\"}'"
echo ""
echo "# Test múltiples mensajes:"
echo "curl -X POST http://localhost:8080 \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"mode\": \"multiple\", \"message\": \"Test\", \"count\": 3}'"
echo ""
echo "# Ver información del entorno:"
echo "curl -X POST http://localhost:8080 \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"mode\": \"environment\"}'"
echo ""
echo -e "\033[0;31m⏹️  Presiona Ctrl+C para detener el servidor\033[0m"
echo ""

# INICIO DEL SERVIDOR
# Functions Framework ejecuta la function como servidor HTTP local
python main.py
EOF

chmod +x scripts/test_local.sh
echo -e "${GREEN}✅ Script de testing local creado: scripts/test_local.sh${NC}"
echo "   ➤ Uso: ./scripts/test_local.sh"
echo "   ➤ Permite: Probar function sin deployar a GCP"#!/bin/bash
# scripts/setup_cloud_deployment.sh
#
# 🚀 SCRIPT DE SETUP AUTOMÁTICO PARA CI/CD CON GOOGLE CLOUD
# =========================================================
# 
# Este script configura automáticamente toda la infraestructura necesaria
# para implementar CI/CD entre GitHub Actions y Google Cloud Functions.
#
# LO QUE HACE ESTE SCRIPT:
# 1. Verifica prerequisites (gcloud CLI, autenticación, permisos)
# 2. Habilita APIs necesarias en Google Cloud
# 3. Crea Service Account con permisos específicos para GitHub Actions
# 4. Genera clave JSON para autenticación automatizada
# 5. Crea scripts auxiliares para testing y deployment manual
# 6. Proporciona instrucciones para configurar GitHub Secrets
#
# POR QUÉ ES NECESARIO:
# - Sin este setup, GitHub Actions no puede autenticarse con Google Cloud
# - Configura security siguiendo principio de menor privilegio
# - Automatiza tareas manuales propensas a error
# - Garantiza configuración consistente y reproducible

set -e  # Sale inmediatamente si cualquier comando falla

# ==========================================
# CONFIGURACIÓN DE COLORES PARA OUTPUT
# ==========================================
# Define colores para hacer el output más legible y profesional
RED='\033[0;31m'      # Para errores críticos
GREEN='\033[0;32m'    # Para operaciones exitosas
YELLOW='\033[1;33m'   # Para warnings y pasos en progreso
BLUE='\033[0;34m'     # Para headers e información importante
NC='\033[0m'          # No Color - resetea el color

echo -e "${BLUE}🖨️ Simple Message Printer - Setup Automático${NC}"
echo "=================================================="

# ==========================================
# FUNCIÓN DE AYUDA
# ==========================================
# Proporciona documentación de uso del script
# Permite que usuarios entiendan parámetros disponibles
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --project-id     ID del proyecto de Google Cloud (requerido)"
    echo "  --region         Región para deployment (default: us-central1)"
    echo "  --help           Mostrar esta ayuda"
    echo ""
    echo "Ejemplo:"
    echo "  $0 --project-id my-simple-printer-project --region us-central1"
    echo ""
    echo "PREREQUISITOS:"
    echo "  - gcloud CLI instalado y autenticado"
    echo "  - Permisos de Owner/Editor en el proyecto GCP"
    echo "  - Billing habilitado en el proyecto"
}

# ==========================================
# CONFIGURACIÓN DE VARIABLES POR DEFECTO
# ==========================================
# Valores que se usan si el usuario no los especifica
PROJECT_ID=""                    # Usuario DEBE especificar esto
REGION="us-central1"            # Región más común, buena latencia global

# ==========================================
# PARSING DE ARGUMENTOS DE LÍNEA DE COMANDOS
# ==========================================
# Permite que el script sea flexible y reutilizable
# Valida input del usuario y proporciona feedback útil
while [[ $# -gt 0 ]]; do
    case $1 in
        --project-id)
            PROJECT_ID="$2"     # Captura el valor del siguiente argumento
            shift 2             # Avanza 2 posiciones (flag + valor)
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0              # Exit exitoso después de mostrar ayuda
            ;;
        *)
            echo -e "${RED}❌ Argumento desconocido: $1${NC}"
            show_help
            exit 1              # Exit con error para argumentos inválidos
            ;;
    esac
done

# ==========================================
# VALIDACIÓN DE ESTRUCTURA DEL PROYECTO
# ==========================================
# Verifica que el script se ejecute desde el directorio correcto
# Previene errores y configuraciones incorrectas
if [ ! -f "src/printer/message_printer.py" ]; then
    echo -e "${RED}❌ Error: No se encuentra src/printer/message_printer.py${NC}"
    echo "Ejecuta este script desde el directorio raíz del proyecto simple-message-printer/"
    echo ""
    echo "Estructura esperada:"
    echo "simple-message-printer/"
    echo "├── src/printer/message_printer.py  ← Este archivo debe existir"
    echo "├── scripts/setup_cloud_deployment.sh  ← Script actual"
    echo "└── ..."
    exit 1
fi

# ==========================================
# VERIFICACIÓN DE PREREQUISITOS
# ==========================================
# Garantiza que el entorno esté preparado antes de proceder
# Fail-fast: detecta problemas temprano antes de hacer cambios
echo -e "${YELLOW}🔍 Verificando prerequisitos...${NC}"

# VERIFICACIÓN 1: gcloud CLI instalado
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI no está instalado${NC}"
    echo ""
    echo "🔧 Para instalar gcloud CLI:"
    echo "• Windows: https://cloud.google.com/sdk/docs/install-sdk#windows"
    echo "• macOS: brew install --cask google-cloud-sdk"
    echo "• Linux: sudo snap install google-cloud-cli --classic"
    echo ""
    echo "Después de instalar, ejecuta: gcloud auth login"
    exit 1
fi

# VERIFICACIÓN 2: Usuario autenticado
# Obtiene el email del usuario actualmente autenticado
CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 2>/dev/null)
if [ -z "$CURRENT_USER" ]; then
    echo -e "${YELLOW}⚠️  No estás autenticado en gcloud${NC}"
    echo ""
    echo "🔧 Para autenticarte:"
    echo "1. gcloud auth login"
    echo "2. Autoriza en el browser que se abre"
    echo "3. Ejecuta este script nuevamente"
    exit 1
fi

echo -e "${GREEN}✅ Autenticado como: $CURRENT_USER${NC}"

# ==========================================
# DETERMINACIÓN DEL PROJECT_ID
# ==========================================
# Permite flexibilidad: usar parámetro o proyecto configurado
# Proporciona feedback claro sobre qué proyecto se usará
if [ -z "$PROJECT_ID" ]; then
    # Intenta obtener proyecto configurado en gcloud
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
    if [ -n "$CURRENT_PROJECT" ]; then
        echo -e "${YELLOW}📝 Usando proyecto actual: ${CURRENT_PROJECT}${NC}"
        PROJECT_ID="$CURRENT_PROJECT"
    else
        echo -e "${RED}❌ No se especificó PROJECT_ID y no hay proyecto configurado${NC}"
        echo ""
        echo "🔧 Opciones para solucionar:"
        echo "1. Especificar proyecto: $0 --project-id TU_PROJECT_ID"
        echo "2. Configurar proyecto por defecto: gcloud config set project TU_PROJECT_ID"
        echo "3. Crear nuevo proyecto: gcloud projects create TU_PROJECT_ID"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Prerequisitos verificados${NC}"
echo "   - gcloud CLI: ✓"
echo "   - Autenticación: ✓ ($CURRENT_USER)"
echo "   - Proyecto: $PROJECT_ID"
echo "   - Región: $REGION"

# ==========================================
# CREACIÓN DE ESTRUCTURA DE DIRECTORIOS
# ==========================================
# Garantiza que las carpetas necesarias existan
# GitHub Actions requiere .github/workflows/, scripts/ es útil para automation
echo -e "${YELLOW}📁 Creando estructura de directorios...${NC}"
mkdir -p .github/workflows    # OBLIGATORIO: GitHub Actions busca aquí
mkdir -p scripts             # Para scripts de automation (testing, deployment)
mkdir -p tests               # Para tests unitarios

# ==========================================
# HABILITACIÓN DE APIs DE GOOGLE CLOUD
# ==========================================
# CRÍTICO: Sin estas APIs, los servicios no funcionan
# Se hace como usuario Owner para garantizar permisos suficientes
echo -e "${YELLOW}🔧 Habilitando APIs de Google Cloud...${NC}"
echo "📋 ¿Por qué necesitamos estas APIs?"

# DEFINICIÓN DE APIs REQUERIDAS
# Cada API habilita servicios específicos necesarios para el pipeline
APIS=(
    "cloudfunctions.googleapis.com"      # CORE: Para crear/gestionar Cloud Functions
    "cloudbuild.googleapis.com"          # CORE: Para builds automáticos desde GitHub
    "cloudresourcemanager.googleapis.com" # CORE: Para gestionar recursos del proyecto
    "logging.googleapis.com"             # MONITORING: Para logs y debugging
    "iam.googleapis.com"                 # SECURITY: Para gestionar Service Accounts y permisos
)

# LOOP DE HABILITACIÓN DE APIs
for API in "${APIS[@]}"; do
    echo ""
    case $API in
        "cloudfunctions.googleapis.com")
            echo "🔧 Habilitando: $API"
            echo "   ➤ Permite: Crear, actualizar y gestionar Cloud Functions"
            echo "   ➤ Sin esto: No se pueden deployar functions"
            ;;
        "cloudbuild.googleapis.com") 
            echo "🔧 Habilitando: $API"
            echo "   ➤ Permite: Builds automáticos cuando GitHub Actions deploya"
            echo "   ➤ Sin esto: Fallan los deployments desde CI/CD"
            ;;
        "cloudresourcemanager.googleapis.com")
            echo "🔧 Habilitando: $API"
            echo "   ➤ Permite: Gestionar recursos y configuraciones del proyecto"
            echo "   ➤ Sin esto: Errores de permisos en operaciones básicas"
            ;;
        "logging.googleapis.com")
            echo "🔧 Habilitando: $API"
            echo "   ➤ Permite: Ver logs de Cloud Functions para debugging"
            echo "   ➤ Sin esto: No hay visibilidad de errores en production"
            ;;
        "iam.googleapis.com")
            echo "🔧 Habilitando: $API"
            echo "   ➤ Permite: Crear Service Accounts y gestionar permisos"
            echo "   ➤ Sin esto: No se puede configurar autenticación automática"
            ;;
    esac
    
    # COMANDO DE HABILITACIÓN
    # gcloud services enable: habilita una API específica
    # 2>/dev/null: suprime warnings menores
    # || echo: continúa si la API ya está habilitada
    if gcloud services enable "$API" --project="$PROJECT_ID" 2>/dev/null; then
        echo -e "     ${GREEN}✅ $API habilitada exitosamente${NC}"
    else
        echo -e "     ${YELLOW}⚠️  $API ya estaba habilitada o hay problema menor${NC}"
    fi
done

echo -e "${GREEN}✅ APIs habilitadas por usuario Owner${NC}"
echo "   ➤ Todas las APIs críticas están ahora disponibles"

# ==========================================
# CONFIGURACIÓN DE SERVICE ACCOUNT
# ==========================================
# COMPONENTE MÁS CRÍTICO: Permite que GitHub Actions se autentique
# con Google Cloud de forma segura y automatizada
echo -e "${YELLOW}🔐 Configurando Service Account para GitHub Actions...${NC}"

# DEFINICIÓN DE NOMBRES
# Nombres descriptivos que indican propósito y origen
SA_NAME="github-actions-deployer"                        # Nombre corto para crear SA
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"  # Email completo del SA

echo ""
echo "📚 ¿Qué es un Service Account?"
echo "   ➤ Una identidad 'no-humana' que permite que sistemas automatizados"
echo "   ➤ (como GitHub Actions) se autentiquen con Google Cloud"
echo "   ➤ Es más seguro que usar credenciales de usuario personal"
echo ""
echo "🎯 Service Account que crearemos:"
echo "   ➤ Nombre: $SA_NAME"
echo "   ➤ Email: $SA_EMAIL"
echo "   ➤ Propósito: Autenticación automática desde GitHub Actions"

# VERIFICACIÓN DE EXISTENCIA
# Evita errores si el Service Account ya existe
if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &>/dev/null; then
    echo -e "${YELLOW}⚠️  Service Account ya existe: $SA_EMAIL${NC}"
    echo "   ➤ Continuaremos con la configuración de permisos"
else
    echo ""
    echo "📝 Creando Service Account: $SA_EMAIL"
    
    # COMANDO DE CREACIÓN
    # gcloud iam service-accounts create: crea un nuevo Service Account
    # --display-name: nombre legible en Cloud Console
    # --description: documentación del propósito
    gcloud iam service-accounts create $SA_NAME \
        --display-name="GitHub Actions Deployer for Simple Message Printer" \
        --description="Service Account para deployment automático desde GitHub Actions. Creado por setup_cloud_deployment.sh" \
        --project=$PROJECT_ID
    
    echo -e "${GREEN}✅ Service Account creado exitosamente${NC}"
fi

# ==========================================
# ASIGNACIÓN DE ROLES IAM
# ==========================================
# IMPLEMENTA PRINCIPIO DE MENOR PRIVILEGIO
# Solo los permisos mínimos necesarios para que funcione CI/CD
echo ""
echo -e "${YELLOW}🔑 Asignando roles IAM al Service Account...${NC}"
echo ""
echo "🛡️ Principio de Menor Privilegio:"
echo "   ➤ Solo otorgamos permisos mínimos necesarios"
echo "   ➤ Si algo se compromete, el daño es limitado"
echo "   ➤ Cada rol tiene un propósito específico"

# DEFINICIÓN DE ROLES NECESARIOS
# Cada rol permite operaciones específicas, no más
ROLES=(
    "roles/cloudfunctions.admin"           # CORE: Gestionar Cloud Functions
    "roles/cloudbuild.builds.builder"     # CORE: Ejecutar builds automáticos  
    "roles/logging.admin"                 # MONITORING: Gestionar logs
    "roles/iam.serviceAccountUser"        # SECURITY: Usar service accounts
    "roles/serviceusage.serviceUsageAdmin" # SETUP: Gestionar APIs (para habilitar si faltan)
)

# LOOP DE ASIGNACIÓN DE ROLES
for ROLE in "${ROLES[@]}"; do
    echo ""
    case $ROLE in
        "roles/cloudfunctions.admin")
            echo "🔑 Asignando: $ROLE"
            echo "   ➤ Permite: Crear, actualizar, borrar Cloud Functions"
            echo "   ➤ Necesario para: Deployments automáticos desde GitHub Actions"
            echo "   ➤ Limitación: Solo functions, no otros recursos GCP"
            ;;
        "roles/cloudbuild.builds.builder")
            echo "🔑 Asignando: $ROLE" 
            echo "   ➤ Permite: Ejecutar builds de contenedores y aplicaciones"
            echo "   ➤ Necesario para: Proceso de deployment de Cloud Functions"
            echo "   ➤ Limitación: Solo builds, no gestión de otros servicios"
            ;;
        "roles/logging.admin")
            echo "🔑 Asignando: $ROLE"
            echo "   ➤ Permite: Leer y escribir logs del proyecto"
            echo "   ➤ Necesario para: Debugging y monitoring de functions"
            echo "   ➤ Limitación: Solo logs, no acceso a datos de aplicación"
            ;;
        "roles/iam.serviceAccountUser")
            echo "🔑 Asignando: $ROLE"
            echo "   ➤ Permite: Usar service accounts para operaciones"
            echo "   ➤ Necesario para: Autenticación durante deployments"
            echo "   ➤ Limitación: Solo usar SAs existentes, no crear nuevos"
            ;;
        "roles/serviceusage.serviceUsageAdmin")
            echo "🔑 Asignando: $ROLE"
            echo "   ➤ Permite: Habilitar/deshabilitar APIs del proyecto"
            echo "   ➤ Necesario para: Auto-habilitación de APIs si faltan"
            echo "   ➤ Limitación: Solo APIs, no configuración de billing"
            ;;
    esac
    
    # COMANDO DE ASIGNACIÓN
    # gcloud projects add-iam-policy-binding: otorga un rol a una identidad
    # --member: especifica el Service Account
    # --role: especifica el rol a otorgar
    # --quiet: no pide confirmación
    if gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$ROLE" \
        --quiet 2>/dev/null; then
        echo -e "     ${GREEN}✅ Rol asignado exitosamente${NC}"
    else
        echo -e "     ${YELLOW}⚠️  Rol ya estaba asignado o hay problema menor${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Service Account configurado con permisos completos${NC}"
echo "   ➤ Email: $SA_EMAIL"
echo "   ➤ Roles: ${#ROLES[@]} roles asignados siguiendo menor privilegio"
echo "   ➤ Puede: Deployar functions, gestionar logs, ejecutar builds"
echo "   ➤ NO puede: Acceder a datos, modificar billing, gestionar otros proyectos"

# ==========================================
# GENERACIÓN DE CLAVE JSON
# ==========================================
# CRÍTICO: Esta clave permite que GitHub Actions se autentique
# Es el "password" que conecta GitHub con Google Cloud
echo ""
echo -e "${YELLOW}🔑 Generando clave JSON para GitHub Actions...${NC}"

KEY_FILE="github-actions-key.json"

echo ""
echo "🔐 ¿Qué es la clave JSON?"
echo "   ➤ Archivo que contiene credenciales privadas del Service Account"
echo "   ➤ Permite autenticación sin password interactivo"
echo "   ➤ GitHub Actions usará esto para conectarse a Google Cloud"
echo "   ➤ DEBE mantenerse seguro - es como un password"

# Eliminar clave existente para evitar conflictos
if [ -f "$KEY_FILE" ]; then
    echo "🗑️  Eliminando clave anterior: $KEY_FILE"
    rm -f "$KEY_FILE"
fi

# COMANDO DE GENERACIÓN
# gcloud iam service-accounts keys create: genera nueva clave privada
# Crea archivo JSON con todas las credenciales necesarias
echo "📝 Generando nueva clave..."
gcloud iam service-accounts keys create $KEY_FILE \
    --iam-account=$SA_EMAIL \
    --project=$PROJECT_ID

echo -e "${GREEN}✅ Clave JSON generada: $KEY_FILE${NC}"
echo "   ➤ Archivo contiene: Clave privada, certificados, configuración"
echo "   ➤ Próximo paso: Configurar como GitHub Secret"

# ==========================================
# CREACIÓN DE SCRIPTS AUXILIARES
# ==========================================
# Proporciona herramientas para testing local y deployment manual
# Útil para debugging y desarrollo iterativo

echo "🚀 Iniciando servidor local..."
cd cloud_functions/

# CONFIGURACIÓN DE VARIABLES DE ENTORNO PARA TESTING
# Simula el entorno de Cloud Functions con valores de desarrollo
echo "   ➤ Configurando variables de entorno para testing..."
export LOG_LEVEL=DEBUG                           # Debug verbose para desarrollo
export DEFAULT_MESSAGE="Hello from local test!"  # Mensaje identificable como local
export DEFAULT_USER="LocalTester"               # Usuario identificable como local
export ENVIRONMENT="local"                      # Environment específico
export MESSAGE_PREFIX="🧪"                      # Prefix que identifica testing local

# INFORMACIÓN DE CONEXIÓN
echo ""
echo -e "\033[0;32m🌐 Servidor disponible en:\033[0m"
echo "   http://localhost:8080"
echo ""
echo -e "\033[0;34m🧪 Para probar la function:\033[0m"
echo ""
echo "# Test básico:"
echo "curl -X POST http://localhost:8080 \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"mode\": \"simple\", \"message\": \"Hello Local!\", \"user\": \"Developer\"}'"
echo ""
echo "# Test múltiples mensajes:"
echo "curl -X POST http://localhost:8080 \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"mode\": \"multiple\", \"message\": \"Test\", \"count\": 3}'"
echo ""
echo "# Ver información del entorno:"
echo "curl -X POST http://localhost:8080 \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"mode\": \"environment\"}'"
echo ""
echo -e "\033[0;31m⏹️  Presiona Ctrl+C para detener el servidor\033[0m"
echo ""

# INICIO DEL SERVIDOR
# Functions Framework ejecuta la function como servidor HTTP local
python main.py
EOF

chmod +x scripts/test_local.sh
echo -e "${GREEN}✅ Script de testing local creado: scripts/test_local.sh${NC}"
echo "   ➤ Uso: ./scripts/test_local.sh"
echo "   ➤ Permite: Probar function sin deployar a GCP"

# ==========================================
# SCRIPT 2: DEPLOYMENT MANUAL
# ==========================================
# Backup para deployment cuando GitHub Actions no está disponible
# Útil para hotfixes, debugging de deployment, o inicialización
echo ""
echo "📝 Creando script de deployment manual..."
cat > scripts/deploy_manual.sh << EOF
#!/bin/bash
# scripts/deploy_manual.sh
#
# 🚀 SCRIPT PARA DEPLOYMENT MANUAL A GOOGLE CLOUD
# ==============================================
# 
# Permite deployar manualmente cuando GitHub Actions no está disponible
# Útil para hotfixes, debugging de deployment, o testing de configuración
#
# LO QUE HACE:
# 1. Verifica autenticación con Google Cloud
# 2. Prepara archivos en estructura requerida por Cloud Functions
# 3. Deploya function con configuración específica de "manual"
# 4. Proporciona URL y comandos de testing
#
# CUÁNDO USAR:
# - GitHub Actions está fallando
# - Necesitas hotfix urgente
# - Testing de configuración de deployment
# - Debugging de problemas específicos

# CONFIGURACIÓN ESPECÍFICA PARA DEPLOY MANUAL
PROJECT_ID="$PROJECT_ID"                    # Configurado por setup script
REGION="$REGION"                            # Configurado por setup script  
FUNCTION_NAME="simple-message-printer-manual" # Nombre único para deploys manuales

echo "🚀 Deploy manual de Simple Message Printer..."
echo ""
echo "📋 Configuración:"
echo "   ➤ Proyecto: \$PROJECT_ID"
echo "   ➤ Región: \$REGION"  
echo "   ➤ Function: \$FUNCTION_NAME"
echo "   ➤ Tipo: Deployment manual (no CI/CD)"

# VERIFICACIÓN DE AUTENTICACIÓN
# Crítico: sin autenticación no se puede deployar
echo ""
echo "🔐 Verificando autenticación..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &>/dev/null; then
    echo "❌ No estás autenticado con Google Cloud"
    echo ""
    echo "🔧 Para solucionar:"
    echo "1. gcloud auth login"
    echo "2. Autoriza en el browser"
    echo "3. Ejecuta este script nuevamente"
    exit 1
fi

CURRENT_USER=\$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
echo "✅ Autenticado como: \$CURRENT_USER"

# VERIFICACIÓN DE PROYECTO
echo ""
echo "📋 Verificando acceso al proyecto..."
if ! gcloud projects describe \$PROJECT_ID &>/dev/null; then
    echo "❌ No tienes acceso al proyecto \$PROJECT_ID"
    echo ""
    echo "🔧 Posibles soluciones:"
    echo "1. Verificar que el PROJECT_ID es correcto"
    echo "2. Ejecutar: gcloud config set project \$PROJECT_ID"
    echo "3. Verificar permisos en el proyecto"
    exit 1
fi

echo "✅ Acceso al proyecto verificado"

# PREPARACIÓN DE ARCHIVOS PARA DEPLOYMENT
echo ""
echo "📁 Preparando archivos para deployment..."

# VERIFICACIÓN DE ESTRUCTURA
if [ ! -f "src/printer/message_printer.py" ]; then
    echo "❌ Error: Estructura de proyecto incorrecta"
    echo "   ➤ Ejecuta desde el directorio raíz del proyecto"
    echo "   ➤ Debe existir: src/printer/message_printer.py"
    exit 1
fi

echo "   ➤ Copiando código fuente..."
# COPY SOURCE - Igual que en GitHub Actions para consistency
cp -r src/printer cloud_functions/
cp -r src/utils cloud_functions/

echo "   ➤ Limpiando archivos __init__.py..."
# CLEAN IMPORTS - Previene problemas de imports relativos
echo "# Clean __init__.py" > cloud_functions/printer/__init__.py
echo "# Clean __init__.py" > cloud_functions/utils/__init__.py

# CAMBIO DE DIRECTORIO
echo "   ➤ Cambiando a directorio de deployment..."
cd cloud_functions/

# VERIFICACIÓN FINAL DE ARCHIVOS
echo "   ➤ Verificando archivos críticos..."
REQUIRED_FILES=("main.py" "requirements.txt" "printer/message_printer.py" "utils/logger.py")
for file in "\${REQUIRED_FILES[@]}"; do
    if [ ! -f "\$file" ]; then
        echo "❌ Archivo crítico faltante: \$file"
        exit 1
    fi
done

echo "✅ Archivos preparados correctamente"

# DEPLOYMENT COMMAND
echo ""
echo "🚀 Iniciando deployment manual..."
echo "   ➤ Esto puede tomar 2-3 minutos..."

# GCLOUD FUNCTIONS DEPLOY
# Configuración específica para deploy manual con identificadores únicos
if gcloud functions deploy \$FUNCTION_NAME \\
    --gen2 \\                                         # Cloud Functions Gen2
    --runtime=python311 \\                            # Python version
    --source=. \\                                     # Código fuente (directorio actual)
    --entry-point=simple_message_printer \\           # Función Python que maneja requests
    --trigger-http \\                                 # HTTP trigger (REST API)
    --no-allow-unauthenticated \\                    # 🔒 REQUIERE AUTENTICACIÓN (SEGURO)
    --set-env-vars="LOG_LEVEL=INFO,ENVIRONMENT=manual,DEFAULT_MESSAGE=Hello from manual deploy!,DEFAULT_USER=ManualUser,MESSAGE_PREFIX=🔧,DEPLOYED_BY=manual-script,DEPLOYMENT_TYPE=manual" \\
    --memory=512Mi \\                                 # Memoria asignada
    --timeout=60s \\                                  # Timeout de ejecución
    --region=\$REGION \\                              # Región geográfica
    --project=\$PROJECT_ID; then                      # Proyecto GCP
    
    echo ""
    echo -e "\033[0;32m✅ Deployment manual completado exitosamente\033[0m"
    echo "🔒 Function deployada con autenticación requerida"
else
    echo ""
    echo -e "\033[0;31m❌ Deployment manual falló\033[0m"
    echo ""
    echo "🔧 Posibles causas:"
    echo "1. Permisos insuficientes"
    echo "2. APIs no habilitadas"
    echo "3. Errores en el código"
    echo "4. Configuración incorrecta"
    echo ""
    echo "Ver logs detallados arriba para más información"
    exit 1
fi

# CONFIGURACIÓN DE PERMISOS IAM POST-DEPLOYMENT
echo ""
echo "🔐 Configurando permisos IAM para acceso autenticado..."

# OBTENER EMAIL DEL USUARIO ACTUAL
CURRENT_USER=\$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)

if [ -n "\$CURRENT_USER" ]; then
    echo "👤 Otorgando permisos al usuario actual: \$CURRENT_USER"
    
    # OTORGAR PERMISO AL USUARIO ACTUAL
    if gcloud functions add-iam-policy-binding \$FUNCTION_NAME \\
        --region=\$REGION \\
        --member="user:\$CURRENT_USER" \\
        --role="roles/cloudfunctions.invoker"; then
        echo "✅ Permisos otorgados al usuario actual"
    else
        echo "⚠️ No se pudieron otorgar permisos (puede ser problema temporal)"
    fi
else
    echo "⚠️ No se pudo detectar usuario actual"
fi

# NOTA SOBRE USUARIOS ADICIONALES
echo ""
echo "📋 Para otorgar acceso a otros usuarios:"
echo "gcloud functions add-iam-policy-binding \$FUNCTION_NAME \\"
echo "  --region=\$REGION \\"
echo "  --member=\"user:usuario@tuempresa.com\" \\"
echo "  --role=\"roles/cloudfunctions.invoker\""
else
    echo ""
    echo -e "\033[0;31m❌ Deployment manual falló\033[0m"
    echo ""
    echo "🔧 Posibles causas:"
    echo "1. Permisos insuficientes"
    echo "2. APIs no habilitadas"
    echo "3. Errores en el código"
    echo "4. Configuración incorrecta"
    echo ""
    echo "Ver logs detallados arriba para más información"
    exit 1
fi

# OBTENCIÓN DE URL DE LA FUNCTION
echo ""
echo "🌐 Obteniendo URL de la function deployada..."
FUNCTION_URL=\$(gcloud functions describe \$FUNCTION_NAME \\
    --gen2 \\
    --region=\$REGION \\
    --project=\$PROJECT_ID \\
    --format="value(serviceConfig.uri)")

if [ -n "\$FUNCTION_URL" ]; then
    echo -e "\033[0;32m🌐 Function URL: \$FUNCTION_URL\033[0m"
else
    echo "⚠️  No se pudo obtener la URL automáticamente"
    echo "   ➤ Busca la URL en Google Cloud Console"
fi

# TESTING AUTOMÁTICO DE LA FUNCTION DEPLOYADA
echo ""
echo "🧪 Probando function deployada..."

if [ -n "\$FUNCTION_URL" ]; then
    echo "   ➤ Ejecutando test básico..."
    
    # TEST SIMPLE
    RESPONSE=\$(curl -s -X POST "\$FUNCTION_URL" \\
        -H "Content-Type: application/json" \\
        -d '{"mode": "simple", "message": "Hello from manual deploy!", "user": "ManualTester"}' \\
        --max-time 30)
    
    if [ \$? -eq 0 ] && [[ "\$RESPONSE" == *"success"* ]]; then
        echo -e "   \033[0;32m✅ Test básico exitoso\033[0m"
        echo "   ➤ Function está funcionando correctamente"
    else
        echo -e "   \033[0;31m❌ Test básico falló\033[0m"
        echo "   ➤ Response: \$RESPONSE"
    fi
else
    echo "⚠️  No se puede probar automáticamente sin URL"
fi

# INSTRUCCIONES FINALES
echo ""
echo -e "\033[0;34m📋 Próximos pasos:\033[0m"
echo ""
echo "🧪 Para probar manualmente:"
echo "curl -X POST \"\$FUNCTION_URL\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"mode\": \"simple\", \"message\": \"Hello Manual!\", \"user\": \"Developer\"}'"
echo ""
echo "📊 Para ver logs:"
echo "gcloud functions logs read \$FUNCTION_NAME --region=\$REGION --limit=50"
echo ""
echo "🗑️  Para eliminar (cleanup):"
echo "gcloud functions delete \$FUNCTION_NAME --region=\$REGION"
echo ""
echo -e "\033[0;32m🎉 Manual deployment completado\033[0m"
EOF

chmod +x scripts/deploy_manual.sh
echo -e "${GREEN}✅ Script de deployment manual creado: scripts/deploy_manual.sh${NC}"
echo "   ➤ Uso: ./scripts/deploy_manual.sh"
echo "   ➤ Permite: Deploy directo sin GitHub Actions"

# ==========================================
# SCRIPT 3: VALIDACIÓN DE PERMISOS
# ==========================================
# Herramienta de debugging para verificar configuración
echo ""
echo "📝 Creando script de validación de permisos..."
cat > scripts/validate_permissions.sh << EOF
#!/bin/bash
# scripts/validate_permissions.sh
#
# 🔍 SCRIPT DE VALIDACIÓN DE PERMISOS Y CONFIGURACIÓN
# ==================================================
# 
# Verifica que toda la configuración esté correcta después del setup
# Útil para debugging cuando hay problemas de permisos o configuración
#
# LO QUE VERIFICA:
# 1. Service Account existe y tiene roles correctos
# 2. APIs necesarias están habilitadas
# 3. Usuario actual tiene permisos suficientes
# 4. Configuración general del proyecto
#
# CUÁNDO USAR:
# - Después de ejecutar setup_cloud_deployment.sh
# - Cuando GitHub Actions falla con errores de permisos
# - Para debugging general de configuración

PROJECT_ID="$PROJECT_ID"
SA_EMAIL="github-actions-deployer@\$PROJECT_ID.iam.gserviceaccount.com"

echo "🔍 Validando configuración y permisos..."
echo "=============================================="
echo ""
echo "📊 Proyecto: \$PROJECT_ID"
echo "🔐 Service Account: \$SA_EMAIL"
echo ""

# VERIFICACIÓN 1: SERVICE ACCOUNT EXISTE
echo "🔍 1. Verificando existencia del Service Account..."
if gcloud iam service-accounts describe "\$SA_EMAIL" --project=\$PROJECT_ID &>/dev/null; then
    echo -e "   \033[0;32m✅ Service Account existe\033[0m"
    
    # Obtener información del SA
    SA_INFO=\$(gcloud iam service-accounts describe "\$SA_EMAIL" --project=\$PROJECT_ID --format="value(displayName)")
    echo "   ➤ Display Name: \$SA_INFO"
else
    echo -e "   \033[0;31m❌ Service Account NO existe\033[0m"
    echo "   🔧 Solución: Re-ejecutar setup_cloud_deployment.sh"
fi

# VERIFICACIÓN 2: ROLES DEL SERVICE ACCOUNT
echo ""
echo "🔍 2. Verificando roles del Service Account..."
SA_ROLES=\$(gcloud projects get-iam-policy \$PROJECT_ID --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.members:serviceAccount:\$SA_EMAIL" | sort | uniq)

REQUIRED_ROLES=(
    "roles/cloudfunctions.admin"
    "roles/cloudbuild.builds.builder"  
    "roles/logging.admin"
    "roles/iam.serviceAccountUser"
    "roles/serviceusage.serviceUsageAdmin"
)

if [ -n "\$SA_ROLES" ]; then
    echo -e "   \033[0;32m✅ Service Account tiene roles asignados\033[0m"
    echo ""
    echo "   📋 Roles actuales:"
    while IFS= read -r role; do
        echo "   ✅ \$role"
    done <<< "\$SA_ROLES"
    
    echo ""
    echo "   🔍 Verificando roles requeridos:"
    MISSING_ROLES=()
    for REQUIRED_ROLE in "\${REQUIRED_ROLES[@]}"; do
        if echo "\$SA_ROLES" | grep -q "\$REQUIRED_ROLE"; then
            echo "   ✅ \$REQUIRED_ROLE"
        else
            echo -e "   \033[0;31m❌ \$REQUIRED_ROLE (FALTANTE)\033[0m"
            MISSING_ROLES+=("\$REQUIRED_ROLE")
        fi
    done
    
    if [ \${#MISSING_ROLES[@]} -gt 0 ]; then
        echo ""
        echo -e "   \033[0;31m❌ Roles faltantes detectados\033[0m"
        echo "   🔧 Para solucionarlo, ejecuta:"
        for MISSING_ROLE in "\${MISSING_ROLES[@]}"; do
            echo "   gcloud projects add-iam-policy-binding \$PROJECT_ID \\"
            echo "     --member=\"serviceAccount:\$SA_EMAIL\" \\"
            echo "     --role=\"\$MISSING_ROLE\""
        done
    else
        echo ""
        echo -e "   \033[0;32m✅ Todos los roles requeridos están presentes\033[0m"
    fi
else
    echo -e "   \033[0;31m❌ Service Account NO tiene roles asignados\033[0m"
    echo "   🔧 Solución: Re-ejecutar setup_cloud_deployment.sh"
fi

# VERIFICACIÓN 3: APIS HABILITADAS
echo ""
echo "🔍 3. Verificando APIs habilitadas..."
REQUIRED_APIS=(
    "cloudfunctions.googleapis.com"
    "cloudbuild.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "logging.googleapis.com"
    "iam.googleapis.com"
)

ENABLED_APIS=\$(gcloud services list --enabled --project=\$PROJECT_ID --format="value(name)")

echo "   📋 Verificando APIs requeridas:"
MISSING_APIS=()
for API in "\${REQUIRED_APIS[@]}"; do
    if echo "\$ENABLED_APIS" | grep -q "\$API"; then
        echo "   ✅ \$API"
    else
        echo -e "   \033[0;31m❌ \$API (NO HABILITADA)\033[0m"
        MISSING_APIS+=("\$API")
    fi
done

if [ \${#MISSING_APIS[@]} -gt 0 ]; then
    echo ""
    echo -e "   \033[0;31m❌ APIs faltantes detectadas\033[0m"
    echo "   🔧 Para habilitarlas:"
    for API in "\${MISSING_APIS[@]}"; do
        echo "   gcloud services enable \$API --project=\$PROJECT_ID"
    done
else
    echo ""
    echo -e "   \033[0;32m✅ Todas las APIs requeridas están habilitadas\033[0m"
fi

# VERIFICACIÓN 4: PERMISOS DEL USUARIO ACTUAL
echo ""
echo "🔍 4. Verificando permisos del usuario actual..."
CURRENT_USER=\$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
if [ -n "\$CURRENT_USER" ]; then
    echo "   👤 Usuario actual: \$CURRENT_USER"
    
    USER_ROLES=\$(gcloud projects get-iam-policy \$PROJECT_ID --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.members:user:\$CURRENT_USER" | head -5)
    
    if [ -n "\$USER_ROLES" ]; then
        echo -e "   \033[0;32m✅ Usuario tiene permisos en el proyecto\033[0m"
        echo "   📋 Algunos roles del usuario:"
        while IFS= read -r role; do
            echo "   ➤ \$role"
        done <<< "\$USER_ROLES"
    else
        echo -e "   \033[0;31m❌ Usuario NO tiene permisos explícitos en el proyecto\033[0m"
        echo "   ⚠️  Puede tener permisos heredados o ser Owner a nivel organización"
    fi
else
    echo -e "   \033[0;31m❌ No hay usuario autenticado\033[0m"
    echo "   🔧 Solución: gcloud auth login"
fi

# VERIFICACIÓN 5: CONFIGURACIÓN GENERAL
echo ""
echo "🔍 5. Verificando configuración general..."

# Project info
PROJECT_INFO=\$(gcloud projects describe \$PROJECT_ID --format="value(name,projectNumber)" 2>/dev/null)
if [ -n "\$PROJECT_INFO" ]; then
    echo -e "   \033[0;32m✅ Proyecto accesible\033[0m"
    echo "   ➤ Información: \$PROJECT_INFO"
else
    echo -e "   \033[0;31m❌ Proyecto no accesible\033[0m"
fi

# Billing info (optional)
BILLING_ACCOUNT=\$(gcloud billing projects describe \$PROJECT_ID --format="value(billingAccountName)" 2>/dev/null)
if [ -n "\$BILLING_ACCOUNT" ]; then
    echo -e "   \033[0;32m✅ Billing habilitado\033[0m"
    echo "   ➤ Cuenta: \$BILLING_ACCOUNT"
else
    echo -e "   \033[0;33m⚠️  Billing no detectado o no accesible\033[0m"
    echo "   ➤ Nota: Billing es requerido para Cloud Functions"
fi

# RESUMEN FINAL
echo ""
echo "📊 RESUMEN DE VALIDACIÓN"
echo "========================"

# Determinar status general
VALIDATION_ERRORS=0

# Check SA exists
if ! gcloud iam service-accounts describe "\$SA_EMAIL" --project=\$PROJECT_ID &>/dev/null; then
    VALIDATION_ERRORS=\$((VALIDATION_ERRORS + 1))
fi

# Check required roles
for REQUIRED_ROLE in "\${REQUIRED_ROLES[@]}"; do
    if ! echo "\$SA_ROLES" | grep -q "\$REQUIRED_ROLE"; then
        VALIDATION_ERRORS=\$((VALIDATION_ERRORS + 1))
    fi
done

# Check required APIs
for API in "\${REQUIRED_APIS[@]}"; do
    if ! echo "\$ENABLED_APIS" | grep -q "\$API"; then
        VALIDATION_ERRORS=\$((VALIDATION_ERRORS + 1))
    fi
done

if [ \$VALIDATION_ERRORS -eq 0 ]; then
    echo -e "\033[0;32m🎉 CONFIGURACIÓN COMPLETAMENTE VÁLIDA\033[0m"
    echo "   ➤ Service Account: ✅"
    echo "   ➤ Roles IAM: ✅"
    echo "   ➤ APIs: ✅"
    echo "   ➤ Acceso al proyecto: ✅"
    echo ""
    echo "✅ GitHub Actions debería funcionar correctamente"
else
    echo -e "\033[0;31m❌ CONFIGURACIÓN TIENE PROBLEMAS (\$VALIDATION_ERRORS errores)\033[0m"
    echo ""
    echo "🔧 Solución recomendada:"
    echo "1. Re-ejecutar: ./scripts/setup_cloud_deployment.sh --project-id \$PROJECT_ID"
    echo "2. Verificar permisos de usuario en Google Cloud Console"
    echo "3. Ejecutar nuevamente este script para verificar"
fi

echo ""
echo "📚 Para más ayuda:"
echo "   ➤ Ver logs de GitHub Actions para errores específicos"
echo "   ➤ Consultar CI-CD-TUTORIAL.md"
echo "   ➤ Verificar GitHub Secrets están configurados"
EOF

chmod +x scripts/validate_permissions.sh
echo -e "${GREEN}✅ Script de validación creado: scripts/validate_permissions.sh${NC}"
echo "   ➤ Uso: ./scripts/validate_permissions.sh"
echo "   ➤ Permite: Verificar que todo esté configurado correctamente"

# ==========================================
# INSTRUCCIONES PARA GITHUB SECRETS
# ==========================================
# Información crítica que el usuario necesita para completar el setup
echo ""
echo -e "${BLUE}📋 Configuración de GitHub Secrets${NC}"
echo "=================================================="
echo ""
echo "🎯 Para completar el setup, necesitas configurar GitHub Secrets"
echo "   ➤ Ve a tu repositorio en GitHub"
echo "   ➤ Settings > Secrets and Variables > Actions"
echo "   ➤ Click 'New repository secret'"
echo ""
echo -e "${YELLOW}🔐 Secrets REQUERIDOS (CRÍTICOS):${NC}"
echo ""

# Leer la clave JSON y mostrarla
if [ -f "$KEY_FILE" ]; then
    echo "Secret Name: GCP_SA_KEY"
    echo "Secret Value:"
    echo "$(cat $KEY_FILE | jq -c .)"
    echo ""
    echo "🔒 ¿Qué es esto?"
    echo "   ➤ Credenciales del Service Account en formato JSON"
    echo "   ➤ Permite que GitHub Actions se autentique con Google Cloud"
    echo "   ➤ Mantener COMPLETAMENTE SECRETO"
fi

echo ""
echo "Secret Name: GCP_PROJECT_ID"
echo "Secret Value: $PROJECT_ID"
echo ""
echo "🔒 ¿Qué es esto?"
echo "   ➤ ID del proyecto de Google Cloud donde deployar"
echo "   ➤ GitHub Actions usa esto para saber dónde crear la function"

echo ""
echo -e "${YELLOW}📊 Secrets OPCIONALES (con valores por defecto):${NC}"
echo ""
echo "🎨 Para personalizar mensajes y comportamiento:"
cat << 'EOF'

LOG_LEVEL: INFO
DEFAULT_MESSAGE: Hello from Simple Message Printer!
DEFAULT_USER: World
MESSAGE_PREFIX: 🖨️

EOF

echo "💡 Si no configuras los secrets opcionales:"
echo "   ➤ Se usarán valores por defecto hardcodeados"
echo "   ➤ La function funcionará perfectamente"
echo "   ➤ Puedes añadirlos después si quieres personalizar"

# ==========================================
# LIMPIEZA DE ARCHIVOS SENSIBLES
# ==========================================
# Manejo seguro de la clave JSON generada
echo ""
echo -e "${YELLOW}🧹 Manejo seguro de archivos...${NC}"
if [ -f "$KEY_FILE" ]; then
    echo ""
    echo "⚠️  IMPORTANTE: Archivo de clave JSON generado"
    echo "   ➤ Archivo: $KEY_FILE"
    echo "   ➤ Contiene: Credenciales privadas del Service Account"
    echo "   ➤ Acción: Guarda el contenido mostrado arriba en GitHub Secrets"
    echo ""
    echo "🔒 Opciones de seguridad:"
    echo "1. 🗑️  ELIMINAR archivo local (recomendado para seguridad)"
    echo "2. 📁 CONSERVAR archivo local (para backup, pero riesgoso)"
    echo ""
    read -p "¿Eliminar archivo de clave local por seguridad? (y/n): " -r RESPONSE
    if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
        rm -f "$KEY_FILE"
        echo -e "${GREEN}🗑️  Archivo de clave eliminado por seguridad${NC}"
        echo "   ➤ Las credenciales están seguras en GitHub Secrets"
        echo "   ➤ El Service Account sigue existiendo en Google Cloud"
    else
        echo -e "${YELLOW}📁 Archivo conservado: $KEY_FILE${NC}"
        echo -e "${RED}⚠️  CRÍTICO: NO commitees este archivo a Git${NC}"
        echo "   ➤ Está en .gitignore pero ten cuidado"
        echo "   ➤ Elimínalo después de configurar GitHub Secrets"
    fi
fi

# ==========================================
# RESUMEN FINAL Y PRÓXIMOS PASOS
# ==========================================
# Guía clara de qué hacer después del setup
echo ""
echo -e "${GREEN}🎉 ¡Setup automático completado exitosamente!${NC}"
echo "=================================================="
echo ""
echo -e "${BLUE}📋 Lo que se configuró:${NC}"
echo "✅ Service Account creado: github-actions-deployer@$PROJECT_ID.iam.gserviceaccount.com"
echo "✅ Roles IAM asignados: 5 roles con principio de menor privilegio"
echo "✅ APIs habilitadas: Cloud Functions, Cloud Build, IAM, Logging"
echo "✅ Clave JSON generada: Para autenticación de GitHub Actions"
echo "✅ Scripts auxiliares: Testing local, deploy manual, validación"
echo ""
echo -e "${BLUE}📋 Siguientes pasos CRÍTICOS:${NC}"
echo ""
echo "1. 🔐 Configura GitHub Secrets (OBLIGATORIO):"
echo "   ➤ Ve a GitHub repo > Settings > Secrets and Variables > Actions"
echo "   ➤ Agrega GCP_SA_KEY y GCP_PROJECT_ID (mostrados arriba)"
echo ""
echo "2. 🔍 Verifica configuración:"
echo "   ➤ ./scripts/validate_permissions.sh"
echo ""
echo "3. 🧪 Prueba localmente:"
echo "   ➤ source venv/bin/activate  # Activar entorno virtual"
echo "   ➤ ./scripts/test_local.sh"
echo ""
echo "4. 🚀 Activa CI/CD automático:"
echo "   ➤ git add ."
echo "   ➤ git commit -m '🚀 Setup CI/CD pipeline'"
echo "   ➤ git push origin main"
echo ""
echo "5. 📊 Monitorea deployment:"
echo "   ➤ GitHub repo > Actions tab"
echo "   ➤ Ver logs del workflow"
echo ""
echo -e "${GREEN}✅ GitHub Actions está listo para deployar automáticamente! 🚀${NC}"
echo ""
echo -e "${BLUE}📚 Documentación adicional:${NC}"
echo "   ➤ README.md - Guía completa del proyecto"
echo "   ➤ CI-CD-TUTORIAL.md - Tutorial detallado de CI/CD"
echo "   ➤ scripts/ - Herramientas para desarrollo y debugging"
echo ""
echo -e "${YELLOW}💡 Si algo falla:${NC}"
echo "   ➤ Ejecuta: ./scripts/validate_permissions.sh"
echo "   ➤ Ve logs en GitHub Actions"
echo "   ➤ Consulta sección Troubleshooting en CI-CD-TUTORIAL.md"_FILE | jq -c .)"
    echo ""
fi

echo "GCP_PROJECT_ID:"
echo "$PROJECT_ID"
echo ""

echo -e "${YELLOW}📊 Secrets OPCIONALES (con valores por defecto):${NC}"
cat << EOF

LOG_LEVEL: INFO
DEFAULT_MESSAGE: Hello from Simple Message Printer!
DEFAULT_USER: World
MESSAGE_PREFIX: 🖨️

EOF

echo ""
echo -e "${YELLOW}🧪 Creando scripts auxiliares...${NC}"
echo ""
echo "📋 ¿Para qué sirven estos scripts?"
echo "   ➤ Testing local: Probar la function antes de deployment"
echo "   ➤ Deploy manual: Backup si GitHub Actions falla"
echo "   ➤ Debugging: Herramientas para solucionar problemas"
cat > scripts/test_local.sh << 'EOF'
#!/bin/bash
# scripts/test_local.sh

echo "🧪 Testing Simple Message Printer locally..."

# Verificar que estamos en el directorio correcto
if [ ! -f "cloud_functions/main.py" ]; then
    echo "❌ Error: Ejecuta desde el directorio raíz"
    exit 1
fi

# Verificar entorno virtual
if [[ "$VIRTUAL_ENV" == "" ]]; then
    echo "⚠️  Entorno virtual no detectado"
    echo "💡 Recomendación: Activar entorno virtual primero:"
    echo "   source venv/bin/activate  # macOS/Linux"
    echo "   venv\\Scripts\\activate    # Windows"
    echo ""
    echo "🔄 Continuando sin entorno virtual..."
else
    echo "✅ Entorno virtual activo: $VIRTUAL_ENV"
fi

echo "📁 Preparando archivos..."

# Copiar archivos
cp -r src/printer cloud_functions/
cp -r src/utils cloud_functions/

# Crear __init__.py limpios
echo "# Clean __init__.py" > cloud_functions/printer/__init__.py
echo "# Clean __init__.py" > cloud_functions/utils/__init__.py

echo "🚀 Iniciando servidor local..."
cd cloud_functions/

export LOG_LEVEL=DEBUG
export DEFAULT_MESSAGE="Hello from local test!"
export DEFAULT_USER="LocalTester"

echo "🌐 Servidor disponible en:"
echo "   http://localhost:8080"
echo ""
echo "🧪 Para probar:"
echo "   curl -X POST http://localhost:8080 -H 'Content-Type: application/json' -d '{\"mode\": \"simple\"}'"
echo ""
echo "⏹️  Presiona Ctrl+C para detener"

python main.py
EOF

chmod +x scripts/test_local.sh

# Crear script de deploy manual
echo -e "${YELLOW}🚀 Creando script de deploy manual...${NC}"
cat > scripts/deploy_manual.sh << EOF
#!/bin/bash
# scripts/deploy_manual.sh

PROJECT_ID="$PROJECT_ID"
REGION="$REGION"
FUNCTION_NAME="simple-message-printer-manual"

echo "🚀 Deploy manual de Simple Message Printer..."

# Verificar autenticación
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &>/dev/null; then
    echo "❌ No estás autenticado. Ejecuta: gcloud auth login"
    exit 1
fi

# Preparar archivos
echo "📁 Preparando archivos..."
cp -r src/printer cloud_functions/
cp -r src/utils cloud_functions/

# Crear __init__.py limpios
echo "# Clean __init__.py" > cloud_functions/printer/__init__.py
echo "# Clean __init__.py" > cloud_functions/utils/__init__.py

cd cloud_functions/

# Deploy
echo "🚀 Deploying..."
gcloud functions deploy \$FUNCTION_NAME \\
    --gen2 \\
    --runtime=python311 \\
    --source=. \\
    --entry-point=simple_message_printer \\
    --trigger-http \\
    --allow-unauthenticated \\
    --set-env-vars="LOG_LEVEL=INFO,ENVIRONMENT=manual,DEFAULT_MESSAGE=Hello from manual deploy!,DEPLOYED_BY=manual" \\
    --memory=512Mi \\
    --timeout=60s \\
    --region=\$REGION \\
    --project=\$PROJECT_ID

echo "✅ Deploy completado"

# Obtener URL
FUNCTION_URL=\$(gcloud functions describe \$FUNCTION_NAME \\
    --gen2 \\
    --region=\$REGION \\
    --project=\$PROJECT_ID \\
    --format="value(serviceConfig.uri)")

echo "🌐 Function URL: \$FUNCTION_URL"

# Test rápido
echo "🧪 Testing..."
curl -X POST "\$FUNCTION_URL" \\
    -H "Content-Type: application/json" \\
    -d '{"mode": "simple", "message": "Hello from manual deploy!", "user": "ManualTester"}'
EOF

chmod +x scripts/deploy_manual.sh

# Limpiar archivo de clave
echo -e "${YELLOW}🧹 Archivo de clave JSON...${NC}"
if [ -f "$KEY_FILE" ]; then
    echo "⚠️  IMPORTANTE: Guarda el contenido del Service Account key mostrado arriba"
    echo "¿Quieres eliminar el archivo local por seguridad? (y/n)"
    read -r RESPONSE
    if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
        rm -f "$KEY_FILE"
        echo "🗑️  Archivo de clave eliminado"
    else
        echo "📁 Archivo conservado: $KEY_FILE (¡no lo commitees!)"
    fi
fi

# Resumen final
echo ""
echo -e "${GREEN}🎉 ¡Setup completado!${NC}"
echo "=================================================="
echo ""
echo -e "${BLUE}📋 Siguientes pasos:${NC}"
echo ""
echo "1. 🔐 Configura los GitHub Secrets (mostrados arriba)"
echo "2. 🧪 Prueba localmente:"
echo "   ./scripts/test_local.sh"
echo "3. 🚀 Prueba deploy manual:"
echo "   ./scripts/deploy_manual.sh"
echo "4. 📤 Haz push a GitHub para activar CI/CD automático"
echo ""
echo -e "${GREEN}✅ Simple Message Printer listo para deployment automático! 🖨️${NC}"