#!/bin/bash
# scripts/use_existing_service_account.sh
# Generar clave JSON para Service Account existente

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID="as-database-337918"

echo -e "${BLUE}🔑 Usar Service Account Existente para CI/CD${NC}"
echo "============================================================"
echo ""

# Función de ayuda
show_help() {
    echo "Uso: $0 --service-account EMAIL"
    echo ""
    echo "Ejemplo:"
    echo "  $0 --service-account admin-sa@as-database-337918.iam.gserviceaccount.com"
    echo ""
    echo "Para ver Service Accounts disponibles:"
    echo "  ./scripts/check_existing_service_account.sh"
}

# Verificar argumentos
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Error: Debes especificar la Service Account${NC}"
    echo ""
    show_help
    exit 1
fi

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --service-account)
            SA_EMAIL="$2"
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

# Verificar que se especificó SA
if [ -z "$SA_EMAIL" ]; then
    echo -e "${RED}❌ Error: Debes especificar --service-account${NC}"
    show_help
    exit 1
fi

echo "🎯 Service Account elegida: $SA_EMAIL"
echo "📁 Proyecto: $PROJECT_ID"
echo ""

# Verificar que la SA existe
echo -e "${YELLOW}🔍 1. Verificando que la Service Account existe...${NC}"
if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &>/dev/null; then
    SA_DISPLAY_NAME=$(gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID --format="value(displayName)")
    echo -e "${GREEN}✅ Service Account existe${NC}"
    echo "   Nombre: $SA_DISPLAY_NAME"
    echo "   Email: $SA_EMAIL"
else
    echo -e "${RED}❌ Service Account no existe: $SA_EMAIL${NC}"
    echo ""
    echo "Service Accounts disponibles:"
    gcloud iam service-accounts list --project=$PROJECT_ID --format="value(email)"
    exit 1
fi
echo ""

# Verificar roles de la SA
echo -e "${YELLOW}🎯 2. Verificando roles de la Service Account...${NC}"
SA_ROLES=$(gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --format="value(bindings.role)" \
    --filter="bindings.members:serviceAccount:$SA_EMAIL" | sort | uniq)

if [ -n "$SA_ROLES" ]; then
    echo -e "${GREEN}✅ Roles asignados:${NC}"
    while IFS= read -r role; do
        echo "   • $role"
    done <<< "$SA_ROLES"
    
    # Verificar si tiene permisos suficientes
    if echo "$SA_ROLES" | grep -q -E "(roles/owner|roles/editor)"; then
        echo ""
        echo -e "${GREEN}🎉 ¡PERFECTO! Esta SA tiene permisos de administrador${NC}"
        SUFFICIENT_PERMS=true
    else
        echo ""
        echo -e "${YELLOW}🔍 Verificando roles específicos para CI/CD...${NC}"
        
        REQUIRED_ROLES=(
            "roles/cloudfunctions.admin"
            "roles/cloudbuild.builds.builder"
            "roles/logging.admin"
            "roles/iam.serviceAccountUser"
            "roles/serviceusage.serviceUsageAdmin"
        )
        
        MISSING_ROLES=()
        for REQ_ROLE in "${REQUIRED_ROLES[@]}"; do
            if echo "$SA_ROLES" | grep -q "$REQ_ROLE"; then
                echo -e "   ✅ $REQ_ROLE"
            else
                echo -e "   ❌ $REQ_ROLE (faltante)"
                MISSING_ROLES+=("$REQ_ROLE")
            fi
        done
        
        if [ ${#MISSING_ROLES[@]} -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✅ Tiene todos los roles específicos necesarios${NC}"
            SUFFICIENT_PERMS=true
        else
            echo ""
            echo -e "${YELLOW}⚠️  Faltan ${#MISSING_ROLES[@]} roles específicos${NC}"
            echo -e "${YELLOW}💡 Pero puede funcionar si tiene otros permisos equivalentes${NC}"
            SUFFICIENT_PERMS="partial"
        fi
    fi
else
    echo -e "${RED}❌ Esta Service Account no tiene roles asignados${NC}"
    echo "No puede usarse para CI/CD"
    exit 1
fi
echo ""

# Generar clave JSON
echo -e "${YELLOW}🔑 3. Generando clave JSON...${NC}"

# Nombre de archivo con timestamp para evitar conflictos
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
KEY_FILE="github-actions-key-${TIMESTAMP}.json"

# Limpiar claves antiguas si existen
rm -f github-actions-key*.json

if gcloud iam service-accounts keys create $KEY_FILE \
    --iam-account=$SA_EMAIL \
    --project=$PROJECT_ID 2>/dev/null; then
    echo -e "${GREEN}✅ Clave JSON generada: $KEY_FILE${NC}"
    
    # Verificar que el JSON es válido
    if python -m json.tool $KEY_FILE > /dev/null 2>&1; then
        echo -e "${GREEN}✅ JSON válido${NC}"
    else
        echo -e "${RED}❌ JSON inválido${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Error generando clave JSON${NC}"
    echo "Verifica que tienes permisos para crear claves de esta Service Account"
    exit 1
fi
echo ""

# Mostrar instrucciones para GitHub
echo -e "${BLUE}📋 CONFIGURACIÓN DE GITHUB SECRETS${NC}"
echo "============================================================"
echo ""
echo -e "${GREEN}🎯 ¡CLAVE JSON GENERADA EXITOSAMENTE!${NC}"
echo ""
echo -e "${YELLOW}📝 Pasos siguientes:${NC}"
echo ""
echo "1. 🔐 Ve a tu repositorio en GitHub:"
echo "   Settings → Secrets and Variables → Actions"
echo ""
echo "2. 🆕 Crear/Actualizar secret: GCP_SA_KEY"
echo "   Value (copia exactamente esto):"
echo "   ----------------------------------------"
cat $KEY_FILE | jq -c .
echo "   ----------------------------------------"
echo ""
echo "3. 🆕 Crear/Actualizar secret: GCP_PROJECT_ID"
echo "   Value: $PROJECT_ID"
echo ""
echo "4. ✅ Secretes opcionales (para personalizar):"
echo "   LOG_LEVEL: INFO"
echo "   DEFAULT_MESSAGE: Hello from Simple Message Printer!"
echo "   DEFAULT_USER: World"
echo "   MESSAGE_PREFIX: 🖨️"
echo ""

# Actualizar el workflow si es necesario
echo -e "${YELLOW}📝 4. Verificando workflow de GitHub Actions...${NC}"
WORKFLOW_FILE=".github/workflows/deploy-cloud-function.yml"

if [ -f "$WORKFLOW_FILE" ]; then
    echo -e "${GREEN}✅ Workflow existe: $WORKFLOW_FILE${NC}"
    
    # Verificar que usa las variables correctas
    if grep -q "GCP_SA_KEY" "$WORKFLOW_FILE" && grep -q "GCP_PROJECT_ID" "$WORKFLOW_FILE"; then
        echo -e "${GREEN}✅ Workflow configurado correctamente para usar secrets${NC}"
    else
        echo -e "${YELLOW}⚠️  Workflow puede necesitar actualizarse${NC}"
    fi
else
    echo -e "${RED}❌ Workflow no encontrado${NC}"
    echo "Asegúrate de que exists: $WORKFLOW_FILE"
fi
echo ""

# Preguntar sobre eliminar archivo local
echo -e "${YELLOW}🧹 ¿Eliminar archivo JSON local por seguridad? (y/n)${NC}"
read -r RESPONSE
if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    rm -f "$KEY_FILE"
    echo -e "${GREEN}🗑️  Archivo eliminado por seguridad${NC}"
    echo -e "${BLUE}💡 La clave está guardada en Google Cloud, puedes regenerarla si necesitas${NC}"
else
    echo -e "${YELLOW}📁 Archivo conservado: $KEY_FILE${NC}"
    echo -e "${RED}⚠️  IMPORTANTE: NO commitees este archivo a Git${NC}"
    
    # Verificar .gitignore
    if ! grep -q "*.json" .gitignore 2>/dev/null; then
        echo "*.json" >> .gitignore
        echo -e "${GREEN}✅ Agregado *.json a .gitignore${NC}"
    fi
fi
echo ""

# Resumen final
echo -e "${GREEN}🎉 CONFIGURACIÓN COMPLETADA${NC}"
echo "============================================================"
echo ""
echo -e "${BLUE}📊 Resumen:${NC}"
echo "   ✅ Service Account: $SA_EMAIL"
if [ "$SUFFICIENT_PERMS" = true ]; then
    echo "   ✅ Permisos: Suficientes para CI/CD"
else
    echo "   ⚠️  Permisos: Parciales (puede funcionar)"
fi
echo "   ✅ Clave JSON: Generada"
echo "   ✅ Configuración: Lista para GitHub"
echo ""
echo -e "${BLUE}🚀 PRÓXIMOS PASOS:${NC}"
echo "1. 🔐 Configurar GitHub Secrets (instrucciones arriba)"
echo "2. 🧪 Probar el pipeline:"
echo "   git add ."
echo "   git commit -m '🔄 Switch to existing Service Account'"
echo "   git push origin main"
echo "3. 📊 Monitorear deployment en GitHub Actions"
echo ""

if [ "$SUFFICIENT_PERMS" != true ]; then
    echo -e "${YELLOW}⚠️  NOTA: Si el deployment falla por permisos, contacta al administrador${NC}"
    echo "para verificar que la SA tenga todos los permisos necesarios."
    echo ""
fi

echo -e "${GREEN}✅ Simple Message Printer listo para CI/CD con SA existente! 🖨️${NC}"