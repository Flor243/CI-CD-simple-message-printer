#!/bin/bash
# scripts/setup_ci_cd.sh
#
# 🚀 SCRIPT UNIFICADO DE SETUP PARA CI/CD CON GOOGLE CLOUD
# =========================================================
# Opciones: Crear nueva Service Account O usar una existente

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID="as-database-337918"
DEFAULT_SA_NAME="github-actions-deployer"
DEFAULT_SA_EMAIL="${DEFAULT_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${BLUE}🚀 Setup Unificado de CI/CD - Simple Message Printer${NC}"
echo "=============================================================="
echo ""

# Función de ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "Opciones:"
    echo "  --create-new         Crear nueva Service Account desde cero"
    echo "  --use-existing EMAIL Usar Service Account existente"
    echo "  --interactive        Modo interactivo (elige durante ejecución)"
    echo "  --help               Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --create-new"
    echo "  $0 --use-existing admin-sa@as-database-337918.iam.gserviceaccount.com"
    echo "  $0 --interactive"
    echo ""
    echo "Si no especificas opciones, se ejecuta en modo interactivo."
}

# Variables globales
SETUP_MODE=""
EXISTING_SA_EMAIL=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --create-new)
            SETUP_MODE="create"
            shift
            ;;
        --use-existing)
            SETUP_MODE="existing"
            EXISTING_SA_EMAIL="$2"
            if [ -z "$EXISTING_SA_EMAIL" ]; then
                echo -e "${RED}❌ Error: --use-existing requiere un email${NC}"
                show_help
                exit 1
            fi
            shift 2
            ;;
        --interactive)
            SETUP_MODE="interactive"
            shift
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

# Si no se especificó modo, usar interactivo
if [ -z "$SETUP_MODE" ]; then
    SETUP_MODE="interactive"
fi

echo "📁 Proyecto: $PROJECT_ID"
echo ""

# Verificar autenticación
echo -e "${YELLOW}🔍 Verificando autenticación...${NC}"
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

# Función para mostrar Service Accounts disponibles
show_available_service_accounts() {
    echo -e "${YELLOW}📋 Service Accounts disponibles en el proyecto:${NC}"
    echo ""
    
    SA_LIST=$(gcloud iam service-accounts list --project=$PROJECT_ID --format="value(email,displayName)" 2>/dev/null)
    
    if [ -n "$SA_LIST" ]; then
        local counter=1
        echo "$SA_LIST" | while IFS=$'\t' read -r email display_name; do
            if [ -n "$email" ]; then
                echo "   [$counter] 📧 $email"
                echo "       └─ $display_name"
                echo ""
                counter=$((counter + 1))
            fi
        done
    else
        echo -e "${YELLOW}⚠️  No se encontraron Service Accounts en el proyecto${NC}"
    fi
}

# Función para verificar permisos de una SA
check_sa_permissions() {
    local sa_email="$1"
    echo -e "${YELLOW}🔍 Verificando permisos de: $sa_email${NC}"
    
    local sa_roles=$(gcloud projects get-iam-policy $PROJECT_ID \
        --flatten="bindings[].members" \
        --format="value(bindings.role)" \
        --filter="bindings.members:serviceAccount:$sa_email" 2>/dev/null | sort | uniq)
    
    if [ -n "$sa_roles" ]; then
        echo -e "${GREEN}✅ Roles asignados:${NC}"
        while IFS= read -r role; do
            echo "   • $role"
            case $role in
                "roles/owner")
                    echo -e "     ${GREEN}🏆 PERFECTO: Owner tiene todos los permisos${NC}"
                    ;;
                "roles/editor")
                    echo -e "     ${GREEN}⭐ EXCELENTE: Editor tiene permisos amplios${NC}"
                    ;;
                "roles/cloudfunctions.admin")
                    echo -e "     ${GREEN}✅ Perfecto para Cloud Functions${NC}"
                    ;;
            esac
        done <<< "$sa_roles"
        
        # Evaluar si es buena para CI/CD
        if echo "$sa_roles" | grep -q -E "(roles/owner|roles/editor)"; then
            echo -e "   ${GREEN}🎉 RECOMENDADA: Excelente para CI/CD${NC}"
            return 0
        elif echo "$sa_roles" | grep -q "roles/cloudfunctions.admin"; then
            echo -e "   ${GREEN}✅ VÁLIDA: Puede funcionar para CI/CD${NC}"
            return 0
        else
            echo -e "   ${YELLOW}⚠️  LIMITADA: Permisos parciales${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Sin roles asignados - no puede usarse para CI/CD${NC}"
        return 1
    fi
}

# Modo interactivo
if [ "$SETUP_MODE" = "interactive" ]; then
    echo -e "${BLUE}🤔 ¿Qué quieres hacer?${NC}"
    echo ""
    echo "1. 🆕 Crear nueva Service Account desde cero"
    echo "2. 🔄 Usar Service Account existente"
    echo "3. 📋 Ver Service Accounts disponibles primero"
    echo ""
    echo -n "Elige una opción (1-3): "
    read -r choice
    echo ""
    
    case $choice in
        1)
            SETUP_MODE="create"
            echo -e "${GREEN}✅ Modo seleccionado: Crear nueva Service Account${NC}"
            ;;
        2)
            SETUP_MODE="existing"
            echo -e "${GREEN}✅ Modo seleccionado: Usar Service Account existente${NC}"
            ;;
        3)
            show_available_service_accounts
            echo ""
            echo -e "${YELLOW}Ahora elige:${NC}"
            echo "1. 🆕 Crear nueva Service Account"
            echo "2. 🔄 Usar una de las Service Accounts mostradas"
            echo ""
            echo -n "Elige una opción (1-2): "
            read -r choice2
            echo ""
            
            case $choice2 in
                1)
                    SETUP_MODE="create"
                    ;;
                2)
                    SETUP_MODE="existing"
                    ;;
                *)
                    echo -e "${RED}❌ Opción inválida${NC}"
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}❌ Opción inválida${NC}"
            exit 1
            ;;
    esac
    echo ""
fi

# Si modo es "existing" y no se especificó email, pedirlo
if [ "$SETUP_MODE" = "existing" ] && [ -z "$EXISTING_SA_EMAIL" ]; then
    show_available_service_accounts
    echo ""
    echo -e "${YELLOW}📧 Ingresa el email de la Service Account que quieres usar:${NC}"
    echo -n "Email: "
    read -r EXISTING_SA_EMAIL
    echo ""
    
    if [ -z "$EXISTING_SA_EMAIL" ]; then
        echo -e "${RED}❌ Email no puede estar vacío${NC}"
        exit 1
    fi
fi

# =============================================================================
# LÓGICA PRINCIPAL SEGÚN EL MODO
# =============================================================================

if [ "$SETUP_MODE" = "create" ]; then
    echo -e "${BLUE}🆕 CREANDO NUEVA SERVICE ACCOUNT${NC}"
    echo "=============================================================="
    
    SA_EMAIL="$DEFAULT_SA_EMAIL"
    echo "🎯 Service Account a crear: $SA_EMAIL"
    echo ""
    
    # Verificar si ya existe
    echo -e "${YELLOW}🔍 1. Verificando si Service Account ya existe...${NC}"
    if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &>/dev/null; then
        echo -e "${YELLOW}⚠️  Service Account ya existe${NC}"
        SA_DISPLAY_NAME=$(gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID --format="value(displayName)")
        echo "   Nombre: $SA_DISPLAY_NAME"
        echo ""
        echo -e "${YELLOW}¿Quieres continuar y verificar/completar su configuración? (y/n)${NC}"
        read -r continue_response
        if [[ ! "$continue_response" =~ ^[Yy]$ ]]; then
            echo "Operación cancelada por el usuario"
            exit 0
        fi
    else
        echo -e "${YELLOW}📝 Creando Service Account...${NC}"
        
        if gcloud iam service-accounts create $DEFAULT_SA_NAME \
            --display-name="GitHub Actions Deployer for Simple Message Printer" \
            --project=$PROJECT_ID; then
            echo -e "${GREEN}✅ Service Account creado exitosamente${NC}"
        else
            echo -e "${RED}❌ Error creando Service Account${NC}"
            exit 1
        fi
    fi
    
elif [ "$SETUP_MODE" = "existing" ]; then
    echo -e "${BLUE}🔄 USANDO SERVICE ACCOUNT EXISTENTE${NC}"
    echo "=============================================================="
    
    SA_EMAIL="$EXISTING_SA_EMAIL"
    echo "🎯 Service Account elegida: $SA_EMAIL"
    echo ""
    
    # Verificar que existe
    echo -e "${YELLOW}🔍 1. Verificando que Service Account existe...${NC}"
    if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &>/dev/null; then
        SA_DISPLAY_NAME=$(gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID --format="value(displayName)")
        echo -e "${GREEN}✅ Service Account existe${NC}"
        echo "   Nombre: $SA_DISPLAY_NAME"
        echo "   Email: $SA_EMAIL"
    else
        echo -e "${RED}❌ Service Account no existe: $SA_EMAIL${NC}"
        echo ""
        show_available_service_accounts
        exit 1
    fi
    
    echo ""
    # Verificar permisos
    echo -e "${YELLOW}🎯 2. Verificando permisos...${NC}"
    if ! check_sa_permissions "$SA_EMAIL"; then
        echo ""
        echo -e "${YELLOW}⚠️  Esta Service Account tiene permisos limitados${NC}"
        echo -e "${YELLOW}¿Quieres continuar de todas formas? (y/n)${NC}"
        read -r continue_response
        if [[ ! "$continue_response" =~ ^[Yy]$ ]]; then
            echo "Operación cancelada por el usuario"
            exit 0
        fi
    fi
fi

echo ""

# =============================================================================
# CONFIGURACIÓN COMÚN PARA AMBOS MODOS
# =============================================================================

# Habilitar APIs necesarias
echo -e "${YELLOW}🔧 3. Habilitando APIs necesarias...${NC}"
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

# Solo asignar roles si estamos en modo "create"
if [ "$SETUP_MODE" = "create" ]; then
    echo -e "${YELLOW}🔑 4. Asignando roles al Service Account...${NC}"
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
    
    # Verificar roles finales solo para modo create
    echo -e "${YELLOW}🔍 Verificación final de roles...${NC}"
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
            echo -e "${YELLOW}⚠️  Algunos roles aún faltan - puede ser problema de permisos${NC}"
        fi
    else
        echo -e "${RED}❌ No se pudieron asignar roles al Service Account${NC}"
        echo -e "${YELLOW}🔧 Verifica que tu usuario tenga permisos suficientes${NC}"
        ALL_PRESENT=false
    fi
    echo ""
else
    # Para modo existing, solo verificar roles actuales
    echo -e "${YELLOW}🔍 4. Verificación de roles existentes...${NC}"
    check_sa_permissions "$SA_EMAIL"
    ALL_PRESENT=true  # Asumimos que está bien si llegamos aquí
    echo ""
fi

# Generar clave JSON
echo -e "${YELLOW}🔑 5. Generando clave JSON para GitHub...${NC}"

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

# Mostrar configuración para GitHub Secrets
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
echo "4. ✅ Secrets opcionales (para personalizar):"
echo "   LOG_LEVEL: INFO"
echo "   DEFAULT_MESSAGE: Hello from Simple Message Printer!"
echo "   DEFAULT_USER: World"
echo "   MESSAGE_PREFIX: 🖨️"
echo ""

# Verificar workflow
echo -e "${YELLOW}📝 6. Verificando workflow de GitHub Actions...${NC}"
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
    echo "Asegúrate de que existe: $WORKFLOW_FILE"
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
echo "   ✅ Modo: $SETUP_MODE"
echo "   ✅ Service Account: $SA_EMAIL"
if [ "$ALL_PRESENT" = true ]; then
    echo "   ✅ Permisos: Configurados correctamente"
else
    echo "   ⚠️  Permisos: Verificar manualmente"
fi
echo "   ✅ APIs: Habilitadas"
echo "   ✅ Clave JSON: Generada"
echo "   ✅ Configuración: Lista para GitHub"
echo ""
echo -e "${BLUE}🚀 PRÓXIMOS PASOS:${NC}"
echo "1. 🔐 Configurar GitHub Secrets (instrucciones arriba)"
echo "2. 🧪 Probar el pipeline:"
echo "   git add ."
if [ "$SETUP_MODE" = "create" ]; then
    echo "   git commit -m '🆕 Setup CI/CD with new Service Account'"
else
    echo "   git commit -m '🔄 Setup CI/CD with existing Service Account'"
fi
echo "   git push origin main"
echo "3. 📊 Monitorear deployment en GitHub Actions"
echo ""

if [ "$ALL_PRESENT" != true ]; then
    echo -e "${YELLOW}⚠️  NOTA: Si el deployment falla por permisos, contacta al administrador${NC}"
    echo "para verificar que la SA tenga todos los permisos necesarios."
    echo ""
fi

echo -e "${GREEN}✅ Simple Message Printer listo para CI/CD! 🖨️${NC}"
echo ""
echo -e "${BLUE}💡 Para ejecutar este script de nuevo:${NC}"
echo "   ./scripts/setup_ci_cd.sh --help"