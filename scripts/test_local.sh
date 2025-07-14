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
