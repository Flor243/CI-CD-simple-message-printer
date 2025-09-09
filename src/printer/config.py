# src/printer/config.py
import os

class Config:
    """
    Configuración centralizada para el Simple Message Printer.
    Todas las variables de entorno y configuraciones en un solo lugar
    """
    
    # Configuración básica
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')
    
    # Configuración de mensajes
    DEFAULT_MESSAGE = os.getenv('DEFAULT_MESSAGE', 'Hello from Simple Message Printer!')
    DEFAULT_USER = os.getenv('DEFAULT_USER', 'World')
    MESSAGE_PREFIX = os.getenv('MESSAGE_PREFIX', '🖨️')
    
    # Configuración de deployment
    DEPLOYED_BY = os.getenv('DEPLOYED_BY', 'manual')
    COMMIT_SHA = os.getenv('COMMIT_SHA', 'unknown')
    BRANCH = os.getenv('BRANCH', 'unknown')
    
    # Configuración de Cloud Function
    FUNCTION_NAME = os.getenv('K_SERVICE', 'simple-message-printer')
    FUNCTION_REGION = os.getenv('FUNCTION_REGION', 'us-central1')
    
    # Límites de seguridad
    MAX_MESSAGE_LENGTH = int(os.getenv('MAX_MESSAGE_LENGTH', '1000'))
    MAX_MESSAGES_PER_REQUEST = int(os.getenv('MAX_MESSAGES_PER_REQUEST', '10'))
    
    @classmethod
    def get_all_config(cls) -> dict:
        """
        Retorna toda la configuración como diccionario.
        
        Returns:
            dict: Toda la configuración
        """
        return {
            'LOG_LEVEL': cls.LOG_LEVEL,
            'ENVIRONMENT': cls.ENVIRONMENT,
            'DEFAULT_MESSAGE': cls.DEFAULT_MESSAGE,
            'DEFAULT_USER': cls.DEFAULT_USER,
            'MESSAGE_PREFIX': cls.MESSAGE_PREFIX,
            'DEPLOYED_BY': cls.DEPLOYED_BY,
            'COMMIT_SHA': cls.COMMIT_SHA,
            'BRANCH': cls.BRANCH,
            'FUNCTION_NAME': cls.FUNCTION_NAME,
            'FUNCTION_REGION': cls.FUNCTION_REGION,
            'MAX_MESSAGE_LENGTH': cls.MAX_MESSAGE_LENGTH,
            'MAX_MESSAGES_PER_REQUEST': cls.MAX_MESSAGES_PER_REQUEST
        }
    
    @classmethod
    def validate_config(cls) -> dict:
        """
        Valida que la configuración sea correcta.
        
        Returns:
            dict: Resultado de la validación
        """
        errors = []
        warnings = []
        
        # Validaciones críticas
        if not cls.DEFAULT_MESSAGE:
            errors.append("DEFAULT_MESSAGE cannot be empty")
            
        if cls.MAX_MESSAGE_LENGTH <= 0:
            errors.append("MAX_MESSAGE_LENGTH must be positive")
            
        if cls.MAX_MESSAGES_PER_REQUEST <= 0:
            errors.append("MAX_MESSAGES_PER_REQUEST must be positive")
        
        # Validaciones de advertencia
        if cls.LOG_LEVEL not in ['DEBUG', 'INFO', 'WARNING', 'ERROR']:
            warnings.append(f"LOG_LEVEL '{cls.LOG_LEVEL}' is not standard")
            
        if cls.ENVIRONMENT not in ['development', 'staging', 'production']:
            warnings.append(f"ENVIRONMENT '{cls.ENVIRONMENT}' is not standard")
        
        return {
            'valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings,
            'config': cls.get_all_config()
        }