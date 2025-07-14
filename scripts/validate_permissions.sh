#!/bin/bash
# scripts/validate_permissions.sh

PROJECT_ID="as-database-337918"
SA_EMAIL="github-actions-deployer@$PROJECT_ID.iam.gserviceaccount.com"

echo "🔍 Validando configuración..."
echo ""

# Verificar Service Account
if gcloud iam service-accounts describe "$SA_EMAIL" --project=$PROJECT_ID &>/dev/null; then
    echo "✅ Service Account existe"
else
    echo "❌ Service Account NO existe"
    exit 1
fi

# Verificar roles
SA_ROLES=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.members:serviceAccount:$SA_EMAIL")

REQUIRED_ROLES=(
    "roles/cloudfunctions.admin"
    "roles/cloudbuild.builds.builder"
    "roles/logging.admin"
    "roles/iam.serviceAccountUser"
    "roles/serviceusage.serviceUsageAdmin"
)

echo "🔍 Verificando roles..."
for ROLE in "${REQUIRED_ROLES[@]}"; do
    if echo "$SA_ROLES" | grep -q "$ROLE"; then
        echo "✅ $ROLE"
    else
        echo "❌ $ROLE (FALTANTE)"
    fi
done

echo ""
echo "✅ Validación completada"
