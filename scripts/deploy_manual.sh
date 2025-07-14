#!/bin/bash
# scripts/deploy_manual.sh

PROJECT_ID="as-database-337918"
REGION="us-central1"
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
gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime=python311 \
    --source=. \
    --entry-point=simple_message_printer \
    --trigger-http \
    --no-allow-unauthenticated \
    --set-env-vars="LOG_LEVEL=INFO,ENVIRONMENT=manual,DEFAULT_MESSAGE=Hello from manual deploy!,DEPLOYED_BY=manual" \
    --memory=512Mi \
    --timeout=60s \
    --region=$REGION \
    --project=$PROJECT_ID

echo "✅ Deploy completado"

FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME \
    --gen2 \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="value(serviceConfig.uri)")

echo "🌐 Function URL: $FUNCTION_URL"
echo "🔒 Requiere autenticación para acceder"
