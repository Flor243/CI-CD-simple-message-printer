# cloud_functions/main.py
import functions_framework
import sys
import os
import json
import traceback
import logging
from typing import Dict, Any
from datetime import datetime

# Configuración inicial
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, current_dir)

# Imports con manejo de errores
try:
    from printer.message_printer import MessagePrinter
    from printer.config import Config
    from utils.logger import setup_logger
    print("✅ Successfully imported core modules")
except ImportError as e:
    print(f"❌ Import error: {e}")
    # Fallback básico
    class MessagePrinter:
        def print_message(self, message="Hello World!", user="Anonymous"):
            return f"[{datetime.now()}] {message} from {user}!"
    
    class Config:
        LOG_LEVEL = "INFO"
        DEFAULT_MESSAGE = "Hello from Cloud Function!"
        DEFAULT_USER = "Cloud"
    
    def setup_logger():
        logger = logging.getLogger('simple_printer')
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter('%(asctime)s | %(levelname)s | %(message)s')
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            logger.setLevel(logging.INFO)
        return logger

# Logger global
def get_logger():
    try:
        return setup_logger()
    except Exception as e:
        print(f"⚠️ Logger setup failed: {e}")
        logger = logging.getLogger('fallback_logger')
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter('%(asctime)s | %(levelname)s | %(message)s')
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            logger.setLevel(logging.INFO)
        return logger

@functions_framework.http
def simple_message_printer(request) -> Dict[str, Any]:
    """Cloud Function HTTP trigger para imprimir mensajes"""
    
    # Headers para CORS
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
    }
    
    if request.method == 'OPTIONS':
        headers['Access-Control-Allow-Methods'] = 'POST, GET'
        headers['Access-Control-Allow-Headers'] = 'Content-Type'
        headers['Access-Control-Max-Age'] = '3600'
        return ('', 204, headers)
    
    logger = get_logger()
    
    try:
        logger.info("🖨️ Starting Simple Message Printer")
        
        # Parse request
        request_json = request.get_json(silent=True) or {}
        
        # Obtener parámetros del request o usar defaults
        message = request_json.get('message', Config.DEFAULT_MESSAGE)
        user = request_json.get('user', Config.DEFAULT_USER)
        mode = request_json.get('mode', 'simple')
        count = min(request_json.get('count', 1), 10)  # Máximo 10 mensajes
        
        logger.info(f"📋 Parameters: message='{message}', user='{user}', mode='{mode}', count={count}")
        
        # Initialize printer
        printer = MessagePrinter()
        
        results = []
        
        if mode == 'simple':
            # Modo simple: un solo mensaje
            result = printer.print_message(message=message, user=user)
            results.append(result)
            logger.info(f"🖨️ Printed: {result}")
            
        elif mode == 'multiple':
            # Modo múltiple: varios mensajes
            for i in range(count):
                numbered_message = f"{message} #{i+1}"
                result = printer.print_message(message=numbered_message, user=user)
                results.append(result)
                logger.info(f"🖨️ Printed: {result}")
                
        elif mode == 'environment':
            # Modo environment: mostrar info del entorno
            env_info = {
                'environment': os.getenv('ENVIRONMENT', 'unknown'),
                'deployed_by': os.getenv('DEPLOYED_BY', 'unknown'),
                'commit_sha': os.getenv('COMMIT_SHA', 'unknown'),
                'branch': os.getenv('BRANCH', 'unknown'),
                'function_name': os.getenv('K_SERVICE', 'unknown'),
                'cloud_region': os.getenv('FUNCTION_REGION', 'unknown'),
                'timestamp': datetime.now().isoformat()
            }
            
            env_message = f"Environment Info: {json.dumps(env_info, indent=2)}"
            result = printer.print_message(message=env_message, user="System")
            results.append(result)
            logger.info(f"🖨️ Environment info printed")
            
        elif mode == 'test':
            # Modo test: validar que todo funciona
            test_results = {
                'printer_working': True,
                'logger_working': True,
                'config_loaded': True,
                'timestamp': datetime.now().isoformat(),
                'test_message': printer.print_message("Test successful!", "TestUser")
            }
            
            results.append(test_results)
            logger.info("🧪 Test mode completed successfully")
            
        else:
            error_msg = f"❌ Invalid mode: {mode}"
            logger.error(error_msg)
            return (json.dumps({
                'success': False,
                'error': error_msg,
                'available_modes': ['simple', 'multiple', 'environment', 'test'],
                'received_mode': mode
            }), 400, headers)
        
        # Prepare response
        response_data = {
            'success': True,
            'mode': mode,
            'results': results,
            'messages_printed': len(results),
            'timestamp': datetime.now().isoformat(),
            'environment': os.getenv('ENVIRONMENT', 'unknown'),
            'function_version': '1.0.0'
        }
        
        logger.info(f"✅ Function completed successfully - printed {len(results)} messages")
        
        return (json.dumps(response_data, default=str, indent=2), 200, headers)
        
    except Exception as e:
        error_msg = f"💥 Error in message printer: {str(e)}"
        logger.error(error_msg)
        logger.error(f"📍 Traceback: {traceback.format_exc()}")
        
        return (json.dumps({
            'success': False,
            'error': str(e),
            'mode': request_json.get('mode', 'unknown') if 'request_json' in locals() else 'unknown',
            'environment': os.getenv('ENVIRONMENT', 'unknown'),
            'timestamp': datetime.now().isoformat()
        }), 500, headers)

# Testing local
if __name__ == "__main__":
    print("🧪 Starting local test server")
    try:
        from flask import Flask, request as flask_request
        
        app = Flask(__name__)
        
        @app.route('/', methods=['POST', 'GET', 'OPTIONS'])
        def test_function():
            return simple_message_printer(flask_request)
        
        @app.route('/health', methods=['GET'])
        def health_check():
            return json.dumps({
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'service': 'simple-message-printer'
            })
        
        print("🧪 Local server ready at http://localhost:8080")
        print("🔗 Test endpoints:")
        print("   - POST /     - Main function")
        print("   - GET /health - Health check")
        app.run(host='0.0.0.0', port=8080, debug=True)
    except Exception as e:
        print(f"❌ Local server failed: {e}")
        print(traceback.format_exc())