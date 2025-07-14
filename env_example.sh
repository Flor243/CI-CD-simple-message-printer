#!/bin/bash
# env_example.sh - Variables de entorno de ejemplo

# Configuración básica
export LOG_LEVEL="INFO"                    # DEBUG, INFO, WARNING, ERROR
export ENVIRONMENT="development"            # development, staging, production

# Configuración de mensajes
export DEFAULT_MESSAGE="Hello from Simple Message Printer!"
export DEFAULT_USER="World"
export MESSAGE_PREFIX="🖨️"

# Límites de seguridad
export MAX_MESSAGE_LENGTH="1000"
export MAX_MESSAGES_PER_REQUEST="10"

# Configuración de deployment (se setean automáticamente en CI/CD)
export DEPLOYED_BY="manual"
export COMMIT_SHA="unknown"
export BRANCH="local"

# Google Cloud (para testing local - NO USAR EN PRODUCCIÓN)
# export GCP_PROJECT_ID="your-project-id"

echo "🔧 Variables de entorno configuradas para Simple Message Printer"
echo "   - LOG_LEVEL: $LOG_LEVEL"
echo "   - ENVIRONMENT: $ENVIRONMENT"
echo "   - DEFAULT_MESSAGE: $DEFAULT_MESSAGE"
echo "   - DEFAULT_USER: $DEFAULT_USER"