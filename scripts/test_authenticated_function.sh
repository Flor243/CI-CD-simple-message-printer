#!/bin/bash
# scripts/test_authenticated_function.sh
# Script para probar Cloud Function con autenticación IAM

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Testing Authenticated Cloud Function${NC}"
echo "=============================================="

# Configuración
PROJECT_ID="as-database-337918"
FUNCTION_NAME="simple-message-printer-development"
REGION="us-central1"

echo "📋 Configuration:"
echo "   Project: $PROJECT_ID"
echo "   Function: $FUNCTION_NAME"
echo "   Region: $REGION"
echo ""

# Verificar autenticación
echo -e "${YELLOW}🔍 1. Verificando autenticación...${NC}"
CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
if [ -z "$CURRENT_USER" ]; then
    echo -e "${RED}❌ No estás autenticado${NC}"
    echo "Ejecuta: gcloud auth login"
    exit 1
fi
echo -e "${GREEN}✅ Autenticado como: $CURRENT_USER${NC}"

# Verificar proyecto
echo -e "${YELLOW}🔍 2. Verificando proyecto...${NC}"
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    echo -e "${YELLOW}⚠️  Proyecto actual: $CURRENT_PROJECT${NC}"
    echo -e "${YELLOW}🔧 Configurando proyecto correcto...${NC}"
    gcloud config set project $PROJECT_ID
fi
echo -e "${GREEN}✅ Proyecto configurado: $PROJECT_ID${NC}"

# Obtener URL de la función
echo -e "${YELLOW}🔍 3. Obteniendo URL de la función...${NC}"
FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME \
    --gen2 \
    --region=$REGION \
    --format="value(serviceConfig.uri)" 2>/dev/null)

if [ -z "$FUNCTION_URL" ]; then
    echo -e "${RED}❌ No se pudo obtener URL de la función${NC}"
    echo "Verifica que la función exista:"
    echo "   gcloud functions list --region=$REGION"
    exit 1
fi
echo -e "${GREEN}✅ Function URL: $FUNCTION_URL${NC}"

# Verificar permisos IAM
echo -e "${YELLOW}🔍 4. Verificando permisos IAM...${NC}"
echo "   Checking Cloud Run service permissions..."
IAM_POLICY=$(gcloud run services get-iam-policy $FUNCTION_NAME \
    --region=$REGION \
    --format="value(bindings[].members)" 2>/dev/null)

if echo "$IAM_POLICY" | grep -q "user:$CURRENT_USER"; then
    echo -e "${GREEN}✅ Usuario tiene permisos de Cloud Run${NC}"
else
    echo -e "${RED}❌ Usuario NO tiene permisos de Cloud Run${NC}"
    echo "Ejecutar:"
    echo "   gcloud run services add-iam-policy-binding $FUNCTION_NAME \\"
    echo "     --region=$REGION \\"
    echo "     --member=\"user:$CURRENT_USER\" \\"
    echo "     --role=\"roles/run.invoker\""
fi

# Generar tokens
echo -e "${YELLOW}🎫 5. Generando tokens de autenticación...${NC}"

# Intentar identity token primero
echo "   Generating identity token..."
ID_TOKEN=$(gcloud auth print-identity-token --audiences="$FUNCTION_URL" 2>/dev/null || echo "")

if [ -n "$ID_TOKEN" ]; then
    echo -e "${GREEN}✅ Identity token generado${NC}"
    AUTH_METHOD="identity"
    TOKEN="$ID_TOKEN"
else
    echo -e "${YELLOW}⚠️  Identity token falló, usando access token...${NC}"
    ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null || echo "")
    if [ -n "$ACCESS_TOKEN" ]; then
        echo -e "${GREEN}✅ Access token generado${NC}"
        AUTH_METHOD="access"
        TOKEN="$ACCESS_TOKEN"
    else
        echo -e "${RED}❌ No se pudo generar ningún token${NC}"
        exit 1
    fi
fi

echo "   Method: $AUTH_METHOD token"
echo "   Token preview: ${TOKEN:0:50}..."
echo ""

# Test 1: Request autenticado
echo -e "${YELLOW}🧪 6. TEST 1: Request autenticado${NC}"
RESPONSE=$(curl -s -w "%{http_code}" -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"mode": "simple", "message": "Hello from local test!", "user": "LocalUser"}' \
    -o test_response.json)

HTTP_CODE=${RESPONSE: -3}
echo "   📊 HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✅ Request autenticado exitoso${NC}"
    echo "   📄 Response:"
    cat test_response.json | jq . 2>/dev/null || cat test_response.json
else
    echo -e "${RED}❌ Request autenticado falló${NC}"
    echo "   📄 Response:"
    cat test_response.json 2>/dev/null || echo "No response body"
fi
echo ""

# Test 2: Request sin autenticación
echo -e "${YELLOW}🧪 7. TEST 2: Request sin autenticación (debe fallar)${NC}"
RESPONSE_UNAUTH=$(curl -s -w "%{http_code}" -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d '{"mode": "simple", "message": "Unauthorized test"}' \
    -o test_unauth_response.json)

HTTP_CODE_UNAUTH=${RESPONSE_UNAUTH: -3}
echo "   📊 HTTP Status: $HTTP_CODE_UNAUTH"

if [ "$HTTP_CODE_UNAUTH" -eq 403 ] || [ "$HTTP_CODE_UNAUTH" -eq 401 ]; then
    echo -e "${GREEN}✅ Request no autenticado correctamente bloqueado${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING: Request no autenticado no fue bloqueado${NC}"
    echo "   📄 Response:"
    cat test_unauth_response.json 2>/dev/null || echo "No response body"
fi
echo ""

# Limpiar archivos temporales
rm -f test_response.json test_unauth_response.json

# Resumen
echo -e "${BLUE}📊 RESUMEN${NC}"
echo "=============================================="
if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✅ Función autenticada funciona correctamente${NC}"
    echo ""
    echo -e "${BLUE}💡 Para usar la función:${NC}"
    echo ""
    echo "# Generar token:"
    if [ "$AUTH_METHOD" = "identity" ]; then
        echo "ID_TOKEN=\$(gcloud auth print-identity-token --audiences=\"$FUNCTION_URL\")"
        echo ""
        echo "# Usar función:"
        echo "curl -X POST \"$FUNCTION_URL\" \\"
        echo "  -H \"Content-Type: application/json\" \\"
        echo "  -H \"Authorization: Bearer \$ID_TOKEN\" \\"
        echo "  -d '{\"mode\": \"simple\", \"message\": \"Hello!\", \"user\": \"YourName\"}'"
    else
        echo "ACCESS_TOKEN=\$(gcloud auth print-access-token)"
        echo ""
        echo "# Usar función:"
        echo "curl -X POST \"$FUNCTION_URL\" \\"
        echo "  -H \"Content-Type: application/json\" \\"
        echo "  -H \"Authorization: Bearer \$ACCESS_TOKEN\" \\"
        echo "  -d '{\"mode\": \"simple\", \"message\": \"Hello!\", \"user\": \"YourName\"}'"
    fi
else
    echo -e "${RED}❌ Hay problemas con la autenticación${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Posibles soluciones:${NC}"
    echo "1. Verificar permisos IAM:"
    echo "   gcloud run services get-iam-policy $FUNCTION_NAME --region=$REGION"
    echo ""
    echo "2. Agregar permisos si faltan:"
    echo "   gcloud run services add-iam-policy-binding $FUNCTION_NAME \\"
    echo "     --region=$REGION \\"
    echo "     --member=\"user:$CURRENT_USER\" \\"
    echo "     --role=\"roles/run.invoker\""
    echo ""
    echo "3. Re-autenticarse:"
    echo "   gcloud auth login"
fi
echo ""