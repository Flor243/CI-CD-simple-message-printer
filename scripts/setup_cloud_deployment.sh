#!/bin/bash
# scripts/setup_cloud_deployment.sh
#
# 🚀 SCRIPT DE SETUP AUTOMÁTICO PARA CI/CD CON GOOGLE CLOUD
# =========================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🖨️ Simple Message Printer - Setup Automático${NC}"
echo "=================================================="

# Función de ayuda
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
}

# Valores por defecto
PROJECT_ID=""
REGION="us-central1"

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --project-id)
            PROJECT_ID="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Argumento desconocido: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Verificar estructura del proyecto
if [ ! -d "src" ]; then
    echo -e "${RED}❌ Error: No se encuentra directorio src/${NC}"
    echo "Ejecuta este script desde el directorio raíz del proyecto"
    exit 1
fi

# Verificar prerequisitos
echo -e "${YELLOW}🔍 Verificando prerequisitos...${NC}"

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI no está instalado${NC}"
    exit 1
fi

CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 2>/dev/null)
if [ -z "$CURRENT_USER" ]; then
    echo -e "${YELLOW}⚠️  No estás autenticado en gcloud${NC}"
    echo "Ejecuta: gcloud auth login"
    exit 1
fi

echo -e "${GREEN}✅ Autenticado como: $CURRENT_USER${NC}"

# Obtener PROJECT_ID
if [ -z "$PROJECT_ID" ]; then
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
    if [ -n "$CURRENT_PROJECT" ]; then
        echo -e "${YELLOW}📝 Usando proyecto actual: ${CURRENT_PROJECT}${NC}"
        PROJECT_ID="$CURRENT_PROJECT"
    else
        echo -e "${RED}❌ No se especificó PROJECT_ID${NC}"
        echo "Especifica: $0 --project-id TU_PROJECT_ID"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Prerequisitos verificados${NC}"
echo "   - Proyecto: $PROJECT_ID"
echo "   - Región: $REGION"

# Crear directorios necesarios
echo -e "${YELLOW}📁 Creando estructura de directorios...${NC}"
mkdir -p .github/workflows
mkdir -p scripts
mkdir -p tests

# Habilitar APIs
echo -e "${YELLOW}🔧 Habilitando APIs de Google Cloud...${NC}"
APIS=(
    "cloudfunctions.googleapis.com"
    "cloudbuild.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "logging.googleapis.com"
    "iam.googleapis.com"
)

for API in "${APIS[@]}"; do
    echo "   - Habilitando: $API"
    if gcloud services enable "$API" --project="$PROJECT_ID" 2>/dev/null; then
        echo -e "     ${GREEN}✅ $API habilitada${NC}"
    else
        echo -e "     ${YELLOW}⚠️  $API ya estaba habilitada${NC}"
    fi
done

# Crear Service Account
echo -e "${YELLOW}🔐 Configurando Service Account...${NC}"
SA_NAME="github-actions-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &>/dev/null; then
    echo -e "${YELLOW}⚠️  Service Account ya existe: $SA_EMAIL${NC}"
else
    echo "📝 Creando Service Account: $SA_EMAIL"
    gcloud iam service-accounts create $SA_NAME \
        --display-name="GitHub Actions Deployer for Simple Message Printer" \
        --project=$PROJECT_ID
fi

# Asignar roles
echo "🔑 Asignando roles..."
ROLES=(
    "roles/cloudfunctions.admin"
    "roles/cloudbuild.builds.builder"
    "roles/logging.admin"
    "roles/iam.serviceAccountUser"
    "roles/serviceusage.serviceUsageAdmin"
)

for ROLE in "${ROLES[@]}"; do
    echo "   - Asignando: $ROLE"
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$ROLE" \
        --quiet 2>/dev/null || echo "     (ya asignado)"
done

# Generar clave JSON
echo -e "${YELLOW}🔑 Generando clave JSON...${NC}"
KEY_FILE="github-actions-key.json"

if [ -f "$KEY_FILE" ]; then
    rm -f "$KEY_FILE"
fi

gcloud iam service-accounts keys create $KEY_FILE \
    --iam-account=$SA_EMAIL \
    --project=$PROJECT_ID

echo -e "${GREEN}✅ Service Account configurado${NC}"

# Crear scripts auxiliares
echo -e "${YELLOW}🧪 Creando scripts auxiliares...${NC}"

# Script de testing local
cat > scripts/test_local.sh << 'EOF'
#!/bin/bash
# scripts/test_local.sh

echo "🧪 Testing Simple Message Printer locally..."

if [ ! -f "cloud_functions/main.py" ]; then
    echo "❌ Error: Ejecuta desde el directorio raíz"
    exit 1
fi

if [[ "$VIRTUAL_ENV" == "" ]]; then
    echo "⚠️  Entorno virtual no detectado"
    echo "💡 Recomendación: source venv/bin/activate"
    echo ""
else
    echo "✅ Entorno virtual activo: $VIRTUAL_ENV"
fi

echo "📁 Preparando archivos..."
cp -r src/printer cloud_functions/ 2>/dev/null || echo "⚠️ No se encontró src/printer/"
cp -r src/utils cloud_functions/ 2>/dev/null || echo "⚠️ No se encontró src/utils/"

echo "# Clean __init__.py" > cloud_functions/printer/__init__.py 2>/dev/null
echo "# Clean __init__.py" > cloud_functions/utils/__init__.py 2>/dev/null

echo "🚀 Iniciando servidor local..."
cd cloud_functions/

export LOG_LEVEL=DEBUG
export DEFAULT_MESSAGE="Hello from local test!"
export DEFAULT_USER="LocalTester"
export ENVIRONMENT="local"
export MESSAGE_PREFIX="🧪"

echo ""
echo "🌐 Servidor disponible en: http://localhost:8080"
echo ""
echo "🧪 Para probar:"
echo "curl -X POST http://localhost:8080 -H 'Content-Type: application/json' -d '{\"mode\": \"simple\"}'"
echo ""
echo "⏹️  Presiona Ctrl+C para detener"
echo ""

python main.py
EOF

# Script de deploy manual
cat > scripts/deploy_manual.sh << EOF
#!/bin/bash
# scripts/deploy_manual.sh

PROJECT_ID="$PROJECT_ID"
REGION="$REGION"
FUNCTION_NAME="simple-message-printer-manual"

echo "🚀 Deploy manual de Simple Message Printer..."

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &>/dev/null; then
    echo "❌ No estás autenticado. Ejecuta: gcloud auth login"
    exit 1
fi

echo "📁 Preparando archivos..."
cp -r src/printer cloud_functions/
cp -r src/utils cloud_functions/

echo "# Clean __init__.py" > cloud_functions/printer/__init__.py
echo "# Clean __init__.py" > cloud_functions/utils/__init__.py

cd cloud_functions/

echo "🚀 Deploying..."
gcloud functions deploy \$FUNCTION_NAME \\
    --gen2 \\
    --runtime=python311 \\
    --source=. \\
    --entry-point=simple_message_printer \\
    --trigger-http \\
    --no-allow-unauthenticated \\
    --set-env-vars="LOG_LEVEL=INFO,ENVIRONMENT=manual,DEFAULT_MESSAGE=Hello from manual deploy!,DEPLOYED_BY=manual" \\
    --memory=512Mi \\
    --timeout=60s \\
    --region=\$REGION \\
    --project=\$PROJECT_ID

echo "✅ Deploy completado"

FUNCTION_URL=\$(gcloud functions describe \$FUNCTION_NAME \\
    --gen2 \\
    --region=\$REGION \\
    --project=\$PROJECT_ID \\
    --format="value(serviceConfig.uri)")

echo "🌐 Function URL: \$FUNCTION_URL"
echo "🔒 Requiere autenticación para acceder"
EOF

# Script de validación
cat > scripts/validate_permissions.sh << EOF
#!/bin/bash
# scripts/validate_permissions.sh

PROJECT_ID="$PROJECT_ID"
SA_EMAIL="github-actions-deployer@\$PROJECT_ID.iam.gserviceaccount.com"

echo "🔍 Validando configuración..."
echo ""

# Verificar Service Account
if gcloud iam service-accounts describe "\$SA_EMAIL" --project=\$PROJECT_ID &>/dev/null; then
    echo "✅ Service Account existe"
else
    echo "❌ Service Account NO existe"
    exit 1
fi

# Verificar roles
SA_ROLES=\$(gcloud projects get-iam-policy \$PROJECT_ID --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.members:serviceAccount:\$SA_EMAIL")

REQUIRED_ROLES=(
    "roles/cloudfunctions.admin"
    "roles/cloudbuild.builds.builder"
    "roles/logging.admin"
    "roles/iam.serviceAccountUser"
    "roles/serviceusage.serviceUsageAdmin"
)

echo "🔍 Verificando roles..."
for ROLE in "\${REQUIRED_ROLES[@]}"; do
    if echo "\$SA_ROLES" | grep -q "\$ROLE"; then
        echo "✅ \$ROLE"
    else
        echo "❌ \$ROLE (FALTANTE)"
    fi
done

echo ""
echo "✅ Validación completada"
EOF

# Hacer scripts ejecutables
chmod +x scripts/test_local.sh
chmod +x scripts/deploy_manual.sh
chmod +x scripts/validate_permissions.sh

# Mostrar instrucciones para GitHub Secrets
echo ""
echo -e "${BLUE}📋 Configuración de GitHub Secrets${NC}"
echo "=================================================="
echo ""
echo "🎯 Configura estos secrets en GitHub:"
echo "   Settings > Secrets and Variables > Actions"
echo ""
echo -e "${YELLOW}🔐 Secrets REQUERIDOS:${NC}"
echo ""

if [ -f "$KEY_FILE" ]; then
    echo "Secret Name: GCP_SA_KEY"
    echo "Secret Value:"
    echo "$(cat $KEY_FILE | jq -c .)"
    echo ""
fi

echo "Secret Name: GCP_PROJECT_ID"
echo "Secret Value: $PROJECT_ID"
echo ""

echo -e "${YELLOW}📊 Secrets OPCIONALES:${NC}"
echo ""
echo "LOG_LEVEL: INFO"
echo "DEFAULT_MESSAGE: Hello from Simple Message Printer!"
echo "DEFAULT_USER: World"
echo "MESSAGE_PREFIX: 🖨️"
echo ""

# Manejo seguro de clave
echo -e "${YELLOW}🧹 Manejo de archivo de clave...${NC}"
if [ -f "$KEY_FILE" ]; then
    echo ""
    echo "⚠️  IMPORTANTE: Guarda el JSON mostrado arriba en GitHub Secrets"
    echo ""
    echo "¿Eliminar archivo local por seguridad? (y/n)"
    read -r RESPONSE
    if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
        rm -f "$KEY_FILE"
        echo "🗑️  Archivo eliminado por seguridad"
    else
        echo "📁 Archivo conservado: $KEY_FILE"
        echo "⚠️  NO lo commitees a Git"
    fi
fi

# Resumen final
echo ""
echo -e "${GREEN}🎉 ¡Setup completado exitosamente!${NC}"
echo "=================================================="
echo ""
echo -e "${BLUE}📋 Siguientes pasos:${NC}"
echo ""
echo "1. 🔐 Configura GitHub Secrets (mostrados arriba)"
echo "2. 🔍 Verifica configuración:"
echo "   ./scripts/validate_permissions.sh"
echo "3. 🧪 Prueba localmente:"
echo "   source venv/bin/activate"
echo "   ./scripts/test_local.sh"
echo "4. 🚀 Activa CI/CD:"
echo "   git add ."
echo "   git commit -m '🚀 Setup CI/CD pipeline'"
echo "   git push origin main"
echo ""
echo -e "${GREEN}✅ Simple Message Printer listo para CI/CD! 🖨️${NC}"