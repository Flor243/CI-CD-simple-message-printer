#!/bin/bash
# scripts/setup_cloud_deployment.sh
#
# 🚀 SCRIPT DE SETUP AUTOMÁTICO PARA CI/CD CON GOOGLE CLOUD
# =========================================================
set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID="as-database-337918"
SA_EMAIL="github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${BLUE}🔧 Completando configuración del Service Account${NC}"
echo "============================================================"
echo ""
echo "📋 Proyecto: $PROJECT_ID"
echo "🤖 Service Account: $SA_EMAIL"
echo ""

# Verificar autenticación
CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
if [ -z "$CURRENT_USER" ]; then
    echo -e "${RED}❌ No estás autenticado${NC}"
    echo "Ejecuta: gcloud auth login"
    exit 1
fi

echo -e "${GREEN}✅ Autenticado como: $CURRENT_USER${NC}"

# Configurar proyecto
gcloud config set project $PROJECT_ID
echo -e "${GREEN}✅ Proyecto configurado${NC}"
echo ""

# Verificar que Service Account existe
echo -e "${YELLOW}🔍 1. Verificando Service Account...${NC}"
if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✅ Service Account existe${NC}"
    SA_DISPLAY_NAME=$(gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID --format="value(displayName)")
    echo "   Nombre: $SA_DISPLAY_NAME"
else
    echo -e "${RED}❌ Service Account no existe${NC}"
    echo -e "${YELLOW}📝 Creando Service Account...${NC}"
    
    gcloud iam service-accounts create github-actions-deployer \
        --display-name="GitHub Actions Deployer for Simple Message Printer" \
        --project=$PROJECT_ID
    
    echo -e "${GREEN}✅ Service Account creado${NC}"
fi
echo ""

# Habilitar APIs necesarias
echo -e "${YELLOW}🔧 2. Habilitando APIs necesarias...${NC}"
REQUIRED_APIS=(
    "cloudfunctions.googleapis.com"
    "cloudbuild.googleapis.com" 
    "cloudresourcemanager.googleapis.com"
    "logging.googleapis.com"
    "iam.googleapis.com"
)

for API in "${REQUIRED_APIS[@]}"; do
    echo "   - Habilitando: $API"
    if gcloud services enable "$API" --project=$PROJECT_ID 2>/dev/null; then
        echo -e "     ${GREEN}✅ Habilitada${NC}"
    else
        echo -e "     ${YELLOW}⚠️  Ya estaba habilitada o hay un problema menor${NC}"
    fi
done
echo ""

# Asignar roles necesarios
echo -e "${YELLOW}🔑 3. Asignando roles al Service Account...${NC}"
REQUIRED_ROLES=(
    "roles/cloudfunctions.admin"
    "roles/cloudbuild.builds.builder"
    "roles/logging.admin"
    "roles/iam.serviceAccountUser"
    "roles/serviceusage.serviceUsageAdmin"
)

echo "📋 Roles que se van a asignar:"
for ROLE in "${REQUIRED_ROLES[@]}"; do
    echo "   • $ROLE"
done
echo ""

FAILED_ROLES=()
for ROLE in "${REQUIRED_ROLES[@]}"; do
    echo "🔧 Asignando: $ROLE"
    
    if gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$ROLE" \
        --quiet 2>/dev/null; then
        echo -e "   ${GREEN}✅ $ROLE asignado exitosamente${NC}"
    else
        echo -e "   ${YELLOW}⚠️  $ROLE - verificando si ya estaba asignado...${NC}"
        
        # Verificar si ya tiene el rol
        EXISTING_ROLE=$(gcloud projects get-iam-policy $PROJECT_ID \
            --flatten="bindings[].members" \
            --format="value(bindings.role)" \
            --filter="bindings.members:serviceAccount:$SA_EMAIL AND bindings.role:$ROLE" 2>/dev/null)
        
        if [ -n "$EXISTING_ROLE" ]; then
            echo -e "   ${GREEN}✅ $ROLE ya estaba asignado${NC}"
        else
            echo -e "   ${RED}❌ Error asignando $ROLE${NC}"
            FAILED_ROLES+=("$ROLE")
        fi
    fi
    echo ""
done

# Verificar roles finales
echo -e "${YELLOW}🔍 4. Verificación final de roles...${NC}"
ASSIGNED_ROLES=$(gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --format="value(bindings.role)" \
    --filter="bindings.members:serviceAccount:$SA_EMAIL" | sort | uniq)

if [ -n "$ASSIGNED_ROLES" ]; then
    echo -e "${GREEN}✅ Service Account tiene estos roles asignados:${NC}"
    while IFS= read -r role; do
        echo "   ✅ $role"
    done <<< "$ASSIGNED_ROLES"
    
    # Verificar que todos los requeridos están presentes
    echo ""
    echo -e "${YELLOW}🎯 Verificando roles requeridos:${NC}"
    ALL_PRESENT=true
    for REQUIRED_ROLE in "${REQUIRED_ROLES[@]}"; do
        if echo "$ASSIGNED_ROLES" | grep -q "$REQUIRED_ROLE"; then
            echo -e "   ✅ $REQUIRED_ROLE"
        else
            echo -e "   ❌ $REQUIRED_ROLE ${RED}(FALTANTE)${NC}"
            ALL_PRESENT=false
        fi
    done
    
    if [ "$ALL_PRESENT" = true ]; then
        echo ""
        echo -e "${GREEN}🎉 ¡Todos los roles requeridos están correctamente asignados!${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠️  Algunos roles aún faltan${NC}"
    fi
else
    echo -e "${RED}❌ No se pudieron asignar roles al Service Account${NC}"
    echo -e "${YELLOW}🔧 Verifica que tu usuario tenga permisos suficientes${NC}"
fi
echo ""

# Generar o verificar clave JSON
echo -e "${YELLOW}🔑 5. Generando clave JSON para GitHub...${NC}"
KEY_FILE="github-actions-key.json"

# Remover clave existente si existe
if [ -f "$KEY_FILE" ]; then
    rm -f "$KEY_FILE"
fi

# Generar nueva clave
if gcloud iam service-accounts keys create $KEY_FILE \
    --iam-account=$SA_EMAIL \
    --project=$PROJECT_ID 2>/dev/null; then
    echo -e "${GREEN}✅ Clave JSON generada exitosamente${NC}"
    
    # Verificar que el JSON es válido
    if python -m json.tool $KEY_FILE > /dev/null 2>&1; then
        echo -e "${GREEN}✅ JSON válido${NC}"
    else
        echo -e "${RED}❌ JSON inválido${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Error generando clave JSON${NC}"
    echo "Verifica permisos para crear claves de Service Account"
    exit 1
fi
echo ""

# Mostrar configuración para GitHub Secrets
echo -e "${BLUE}📋 CONFIGURACIÓN DE GITHUB SECRETS${NC}"
echo "============================================================"
echo ""
echo -e "${YELLOW}🎯 Ve a tu repositorio en GitHub:${NC}"
echo "   Settings > Secrets and Variables > Actions > New repository secret"
echo ""
echo -e "${YELLOW}🔐 Secret #1: GCP_SA_KEY${NC}"
echo "Value (copia exactamente esto):"
echo "----------------------------------------"
cat $KEY_FILE | jq -c .
echo "----------------------------------------"
echo ""
echo -e "${YELLOW}🔐 Secret #2: GCP_PROJECT_ID${NC}"
echo "Value: $PROJECT_ID"
echo ""
echo -e "${YELLOW}📊 Secrets OPCIONALES (para personalizar):${NC}"
echo "LOG_LEVEL: INFO"
echo "DEFAULT_MESSAGE: Hello from Simple Message Printer!"
echo "DEFAULT_USER: World"
echo "MESSAGE_PREFIX: 🖨️"
echo ""

# Preguntar si eliminar archivo JSON local
echo -e "${YELLOW}🧹 ¿Eliminar archivo JSON local por seguridad? (y/n)${NC}"
read -r RESPONSE
if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    rm -f "$KEY_FILE"
    echo -e "${GREEN}🗑️  Archivo JSON eliminado por seguridad${NC}"
else
    echo -e "${YELLOW}📁 Archivo conservado: $KEY_FILE${NC}"
    echo -e "${RED}⚠️  IMPORTANTE: NO commitees este archivo a Git${NC}"
    echo "   Agrégalo a .gitignore si no está ya"
fi
echo ""

# Resumen final
echo -e "${GREEN}🎉 CONFIGURACIÓN COMPLETADA${NC}"
echo "============================================================"
echo ""
echo -e "${BLUE}📋 Estado final:${NC}"
echo "   ✅ Service Account: $SA_EMAIL"
echo "   ✅ APIs habilitadas"
if [ "$ALL_PRESENT" = true ]; then
    echo "   ✅ Todos los roles asignados"
else
    echo "   ⚠️  Algunos roles pueden faltar"
fi
echo "   ✅ Clave JSON generada"
echo ""
echo -e "${BLUE}🚀 PRÓXIMOS PASOS:${NC}"
echo "1. 🔐 Configura los GitHub Secrets mostrados arriba"
echo "2. 🧪 Prueba el pipeline:"
echo "   git add ."
echo "   git commit -m '🚀 Test CI/CD pipeline'"
echo "   git push origin main"
echo "3. 📊 Monitorea el deployment en GitHub Actions"
echo "4. 🌐 Usa la Cloud Function una vez deployada"
echo ""
echo -e "${GREEN}✅ ¡Simple Message Printer listo para CI/CD automático! 🖨️${NC}"