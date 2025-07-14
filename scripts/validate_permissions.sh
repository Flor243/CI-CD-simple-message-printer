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

PROJECT_ID=""
SA_EMAIL="github-actions-deployer@$PROJECT_ID.iam.gserviceaccount.com"

echo "🔍 Validando configuración y permisos..."
echo "=============================================="
echo ""
echo "📊 Proyecto: $PROJECT_ID"
echo "🔐 Service Account: $SA_EMAIL"
echo ""

# VERIFICACIÓN 1: SERVICE ACCOUNT EXISTE
echo "🔍 1. Verificando existencia del Service Account..."
if gcloud iam service-accounts describe "$SA_EMAIL" --project=$PROJECT_ID &>/dev/null; then
    echo -e "   \033[0;32m✅ Service Account existe\033[0m"
    
    # Obtener información del SA
    SA_INFO=$(gcloud iam service-accounts describe "$SA_EMAIL" --project=$PROJECT_ID --format="value(displayName)")
    echo "   ➤ Display Name: $SA_INFO"
else
    echo -e "   \033[0;31m❌ Service Account NO existe\033[0m"
    echo "   🔧 Solución: Re-ejecutar setup_cloud_deployment.sh"
fi

# VERIFICACIÓN 2: ROLES DEL SERVICE ACCOUNT
echo ""
echo "🔍 2. Verificando roles del Service Account..."
SA_ROLES=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.members:serviceAccount:$SA_EMAIL" | sort | uniq)

REQUIRED_ROLES=(
    "roles/cloudfunctions.admin"
    "roles/cloudbuild.builds.builder"  
    "roles/logging.admin"
    "roles/iam.serviceAccountUser"
    "roles/serviceusage.serviceUsageAdmin"
)

if [ -n "$SA_ROLES" ]; then
    echo -e "   \033[0;32m✅ Service Account tiene roles asignados\033[0m"
    echo ""
    echo "   📋 Roles actuales:"
    while IFS= read -r role; do
        echo "   ✅ $role"
    done <<< "$SA_ROLES"
    
    echo ""
    echo "   🔍 Verificando roles requeridos:"
    MISSING_ROLES=()
    for REQUIRED_ROLE in "${REQUIRED_ROLES[@]}"; do
        if echo "$SA_ROLES" | grep -q "$REQUIRED_ROLE"; then
            echo "   ✅ $REQUIRED_ROLE"
        else
            echo -e "   \033[0;31m❌ $REQUIRED_ROLE (FALTANTE)\033[0m"
            MISSING_ROLES+=("$REQUIRED_ROLE")
        fi
    done
    
    if [ ${#MISSING_ROLES[@]} -gt 0 ]; then
        echo ""
        echo -e "   \033[0;31m❌ Roles faltantes detectados\033[0m"
        echo "   🔧 Para solucionarlo, ejecuta:"
        for MISSING_ROLE in "${MISSING_ROLES[@]}"; do
            echo "   gcloud projects add-iam-policy-binding $PROJECT_ID \"
            echo "     --member=\"serviceAccount:$SA_EMAIL\" \"
            echo "     --role=\"$MISSING_ROLE\""
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

ENABLED_APIS=$(gcloud services list --enabled --project=$PROJECT_ID --format="value(name)")

echo "   📋 Verificando APIs requeridas:"
MISSING_APIS=()
for API in "${REQUIRED_APIS[@]}"; do
    if echo "$ENABLED_APIS" | grep -q "$API"; then
        echo "   ✅ $API"
    else
        echo -e "   \033[0;31m❌ $API (NO HABILITADA)\033[0m"
        MISSING_APIS+=("$API")
    fi
done

if [ ${#MISSING_APIS[@]} -gt 0 ]; then
    echo ""
    echo -e "   \033[0;31m❌ APIs faltantes detectadas\033[0m"
    echo "   🔧 Para habilitarlas:"
    for API in "${MISSING_APIS[@]}"; do
        echo "   gcloud services enable $API --project=$PROJECT_ID"
    done
else
    echo ""
    echo -e "   \033[0;32m✅ Todas las APIs requeridas están habilitadas\033[0m"
fi

# VERIFICACIÓN 4: PERMISOS DEL USUARIO ACTUAL
echo ""
echo "🔍 4. Verificando permisos del usuario actual..."
CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
if [ -n "$CURRENT_USER" ]; then
    echo "   👤 Usuario actual: $CURRENT_USER"
    
    USER_ROLES=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.members:user:$CURRENT_USER" | head -5)
    
    if [ -n "$USER_ROLES" ]; then
        echo -e "   \033[0;32m✅ Usuario tiene permisos en el proyecto\033[0m"
        echo "   📋 Algunos roles del usuario:"
        while IFS= read -r role; do
            echo "   ➤ $role"
        done <<< "$USER_ROLES"
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
PROJECT_INFO=$(gcloud projects describe $PROJECT_ID --format="value(name,projectNumber)" 2>/dev/null)
if [ -n "$PROJECT_INFO" ]; then
    echo -e "   \033[0;32m✅ Proyecto accesible\033[0m"
    echo "   ➤ Información: $PROJECT_INFO"
else
    echo -e "   \033[0;31m❌ Proyecto no accesible\033[0m"
fi

# Billing info (optional)
BILLING_ACCOUNT=$(gcloud billing projects describe $PROJECT_ID --format="value(billingAccountName)" 2>/dev/null)
if [ -n "$BILLING_ACCOUNT" ]; then
    echo -e "   \033[0;32m✅ Billing habilitado\033[0m"
    echo "   ➤ Cuenta: $BILLING_ACCOUNT"
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
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project=$PROJECT_ID &>/dev/null; then
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check required roles
for REQUIRED_ROLE in "${REQUIRED_ROLES[@]}"; do
    if ! echo "$SA_ROLES" | grep -q "$REQUIRED_ROLE"; then
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi
done

# Check required APIs
for API in "${REQUIRED_APIS[@]}"; do
    if ! echo "$ENABLED_APIS" | grep -q "$API"; then
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi
done

if [ $VALIDATION_ERRORS -eq 0 ]; then
    echo -e "\033[0;32m🎉 CONFIGURACIÓN COMPLETAMENTE VÁLIDA\033[0m"
    echo "   ➤ Service Account: ✅"
    echo "   ➤ Roles IAM: ✅"
    echo "   ➤ APIs: ✅"
    echo "   ➤ Acceso al proyecto: ✅"
    echo ""
    echo "✅ GitHub Actions debería funcionar correctamente"
else
    echo -e "\033[0;31m❌ CONFIGURACIÓN TIENE PROBLEMAS ($VALIDATION_ERRORS errores)\033[0m"
    echo ""
    echo "🔧 Solución recomendada:"
    echo "1. Re-ejecutar: ./scripts/setup_cloud_deployment.sh --project-id $PROJECT_ID"
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

if [ -n "$FUNCTION_URL" ]; then
    echo "   ➤ Generando token de autenticación..."
    
    # GENERAR TOKEN DE AUTENTICACIÓN
    ID_TOKEN=$(gcloud auth print-identity-token --audiences="$FUNCTION_URL" 2>/dev/null)
    
    if [ -n "$ID_TOKEN" ]; then
        echo "   ✅ Token de autenticación generado"
        echo "   ➤ Ejecutando test autenticado..."
        
        # TEST CON AUTENTICACIÓN
        RESPONSE=$(curl -s -w "%{http_code}" \
            -X POST "$FUNCTION_URL" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $ID_TOKEN" \
            -d '{"mode": "simple", "message": "Hello from manual deploy!", "user": "ManualTester"}' \
            --max-time 30 \
            -o response_body.json)
        
        HTTP_CODE=${RESPONSE: -3}
        
        HTTP_CODE=${RESPONSE: -3}
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            echo -e "   \033[0;32m✅ Test autenticado exitoso (HTTP 200)\033[0m"
            echo "   ➤ Function está funcionando correctamente con autenticación"
            
            # Mostrar response (sin datos sensibles)
            if [ -f "response_body.json" ]; then
                echo "   📄 Response preview:"
                cat response_body.json | jq '.success, .mode, .messages_printed' 2>/dev/null || echo "   ➤ Function responded successfully"
                rm -f response_body.json
            fi
        else
            echo -e "   \033[0;31m❌ Test autenticado falló (HTTP $HTTP_CODE)\033[0m"
            echo "   📄 Error response:"
            cat response_body.json 2>/dev/null || echo "No response body"
            rm -f response_body.json
        fi
        
        # TEST ADICIONAL: Verificar que sin auth falla
        echo ""
        echo "   🔒 Verificando que requests sin autenticación fallan..."
        UNAUTH_RESPONSE=$(curl -s -w "%{http_code}" \
            -X POST "$FUNCTION_URL" \
            -H "Content-Type: application/json" \
            -d '{"mode": "simple"}' \
            --max-time 15 \
            -o /dev/null)
        
        UNAUTH_CODE=${UNAUTH_RESPONSE: -3}
        
        if [ "$UNAUTH_CODE" -eq 403 ] || [ "$UNAUTH_CODE" -eq 401 ]; then
            echo -e "   \033[0;32m✅ Security OK: Requests sin auth correctamente bloqueados (HTTP $UNAUTH_CODE)\033[0m"
        else
            echo -e "   \033[0;31m⚠️ WARNING: Requests sin auth no fueron bloqueados (HTTP $UNAUTH_CODE)\033[0m"
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
echo "FUNCTION_URL=\"$FUNCTION_URL\""
echo "ID_TOKEN=\$(gcloud auth print-identity-token --audiences=\"\$FUNCTION_URL\")"
echo ""
echo "🧪 PASO 3: Usar function CON autenticación"
echo "curl -X POST \"\$FUNCTION_URL\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"Authorization: Bearer \$ID_TOKEN\" \\"
echo "  -d '{\"mode\": \"simple\", \"message\": \"Hello Authenticated!\", \"user\": \"Developer\"}'"
echo ""
echo "🚫 NOTA: Requests SIN Authorization header fallarán con 403 Forbidden"
echo ""
echo "👥 Para otorgar acceso a otros usuarios:"
echo "gcloud functions add-iam-policy-binding $FUNCTION_NAME \\"
echo "  --region=$REGION \\"
echo "  --member=\"user:usuario@tuempresa.com\" \\"
echo "  --role=\"roles/cloudfunctions.invoker\""
echo ""
echo "📊 Para ver logs:"
echo "gcloud functions logs read $FUNCTION_NAME --region=$REGION --limit=50"
echo ""
echo "🗑️  Para eliminar (cleanup):"
echo "gcloud functions delete $FUNCTION_NAME --region=$REGION"
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
if [[ "/home/flor/Documents/Howdy/Roster/Python projects/simple_message_printer/CI-CD-simple-message-printer/CICD-smp" == "" ]]; then
    echo "⚠️  Entorno virtual no detectado"
    echo "💡 Recomendación: Activar entorno virtual primero:"
    echo "   source venv/bin/activate  # macOS/Linux"
    echo "   venv\Scripts\activate    # Windows"
    echo ""
    echo "🔄 Continuando sin entorno virtual..."
    echo "   ➤ Puede haber problemas de dependencies"
else
    echo "✅ Entorno virtual activo: /home/flor/Documents/Howdy/Roster/Python projects/simple_message_printer/CI-CD-simple-message-printer/CICD-smp"
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
echo "curl -X POST http://localhost:8080 \"
echo "  -H 'Content-Type: application/json' \"
echo "  -d '{\"mode\": \"simple\", \"message\": \"Hello Local!\", \"user\": \"Developer\"}'"
echo ""
echo "# Test múltiples mensajes:"
echo "curl -X POST http://localhost:8080 \"
echo "  -H 'Content-Type: application/json' \"
echo "  -d '{\"mode\": \"multiple\", \"message\": \"Test\", \"count\": 3}'"
echo ""
echo "# Ver información del entorno:"
echo "curl -X POST http://localhost:8080 \"
echo "  -H 'Content-Type: application/json' \"
echo "  -d '{\"mode\": \"environment\"}'"
echo ""
echo -e "\033[0;31m⏹️  Presiona Ctrl+C para detener el servidor\033[0m"
echo ""

# INICIO DEL SERVIDOR
# Functions Framework ejecuta la function como servidor HTTP local
python main.py
