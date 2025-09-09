# src/utils/logger.py
import logging
import os
from datetime import datetime

def setup_logger(name: str = 'simple_printer') -> logging.Logger:
    """
    Configura un logger simple para el proyecto.
    
    Args:
        name (str): Nombre del logger
        
    Returns:
        logging.Logger: Logger configurado
    """
    
    # Obtener nivel de log desde variable de entorno
    log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
    
    # Crear logger
    logger = logging.getLogger(name)
    
    # Evitar duplicar handlers
    if logger.handlers:
        return logger
    
    # Configurar nivel
    numeric_level = getattr(logging, log_level, logging.INFO)
    logger.setLevel(numeric_level)
    
    # Crear handler para console
    console_handler = logging.StreamHandler()
    console_handler.setLevel(numeric_level)
    
    # Crear formatter
    formatter = logging.Formatter(
        '%(asctime)s | %(name)s | %(levelname)s | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    console_handler.setFormatter(formatter)
    
    # Agregar handler al logger
    logger.addHandler(console_handler)
    
    # Log inicial
    logger.info(f"Logger initialized - Level: {log_level}")
    
    return logger

def log_function_start(logger: logging.Logger, function_name: str, **kwargs):
    """
    Log del inicio de una función.
    
    Args:
        logger: Logger instance
        function_name: Nombre de la función
        **kwargs: Argumentos de la función
    """
    logger.info(f"🚀 Starting {function_name}")
    if kwargs:
        logger.debug(f"📋 Arguments: {kwargs}")

def log_function_end(logger: logging.Logger, function_name: str, result=None):
    """
    Log del final de una función.
    
    Args:
        logger: Logger instance
        function_name: Nombre de la función
        result: Resultado de la función (opcional)
    """
    logger.info(f"✅ Completed {function_name}")
    if result is not None:
        logger.debug(f"📤 Result: {result}")

def log_error(logger: logging.Logger, error: Exception, context: str = ""):
    """
    Log de errores con contexto.
    
    Args:
        logger: Logger instance
        error: Excepción capturada
        context: Contexto adicional
    """
    logger.error(f"❌ Error {context}: {str(error)}")
    logger.debug(f"📍 Error details: {type(error).__name__}: {str(error)}")

class StructuredLogger:
    """
    Logger estructurado para mejor tracking en Cloud Functions.
    """
    
    def __init__(self, name: str = 'simple_printer'):
        self.logger = setup_logger(name)
        self.context = {
            'environment': os.getenv('ENVIRONMENT', 'unknown'),
            'function_name': os.getenv('K_SERVICE', 'local'),
            'region': os.getenv('FUNCTION_REGION', 'local')
        }
    
    def info(self, message: str, **extra):
        """Log info con contexto estructurado."""
        full_context = {**self.context, **extra}
        self.logger.info(f"{message} | Context: {full_context}")
    
    def error(self, message: str, error: Exception = None, **extra):
        """Log error con contexto estructurado."""
        full_context = {**self.context, **extra}
        if error:
            full_context['error_type'] = type(error).__name__
            full_context['error_message'] = str(error)
        self.logger.error(f"{message} | Context: {full_context}")
    
    def debug(self, message: str, **extra):
        """Log debug con contexto estructurado."""
        full_context = {**self.context, **extra}
        self.logger.debug(f"{message} | Context: {full_context}")
    
    def warning(self, message: str, **extra):
        """Log warning con contexto estructurado."""
        full_context = {**self.context, **extra}
        self.logger.warning(f"{message} | Context: {full_context}")