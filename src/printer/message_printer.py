# src/printer/message_printer.py
import os
from datetime import datetime
from typing import Optional

class MessagePrinter:
    """
    Clase principal para imprimir mensajes.
    Ejemplo simple de cómo estructurar código para Cloud Functions.
    """
    
    def __init__(self):
        self.prefix = os.getenv('MESSAGE_PREFIX', '🖨️')
        self.environment = os.getenv('ENVIRONMENT', 'development')
        
    def print_message(self, message: str, user: Optional[str] = None) -> str:
        """
        Imprime un mensaje con formato.
        
        Args:
            message (str): Mensaje a imprimir
            user (str, optional): Usuario que envía el mensaje
            
        Returns:
            str: Mensaje formateado
        """
        if user is None:
            user = os.getenv('DEFAULT_USER', 'Anonymous')
            
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        formatted_message = f"{self.prefix} [{timestamp}] [{self.environment.upper()}] {message} - from {user}"
        
        # Print to console (aparecerá en Cloud Functions logs)
        print(formatted_message)
        
        return formatted_message
    
    def print_multiple_messages(self, messages: list, user: Optional[str] = None) -> list:
        """
        Imprime múltiples mensajes.
        
        Args:
            messages (list): Lista de mensajes
            user (str, optional): Usuario que envía los mensajes
            
        Returns:
            list: Lista de mensajes formateados
        """
        results = []
        for i, message in enumerate(messages, 1):
            numbered_message = f"Message {i}: {message}"
            result = self.print_message(numbered_message, user)
            results.append(result)
        return results
    
    def print_environment_info(self) -> dict:
        """
        Imprime información del entorno.
        
        Returns:
            dict: Información del entorno
        """
        env_vars = {
            'ENVIRONMENT': os.getenv('ENVIRONMENT', 'unknown'),
            'MESSAGE_PREFIX': os.getenv('MESSAGE_PREFIX', '🖨️'),
            'DEFAULT_USER': os.getenv('DEFAULT_USER', 'Anonymous'),
            'FUNCTION_NAME': os.getenv('K_SERVICE', 'local'),
            'FUNCTION_REGION': os.getenv('FUNCTION_REGION', 'local'),
            'DEPLOYED_BY': os.getenv('DEPLOYED_BY', 'manual'),
            'COMMIT_SHA': os.getenv('COMMIT_SHA', 'unknown'),
            'BRANCH': os.getenv('BRANCH', 'unknown')
        }
        
        print("🔍 Environment Information:")
        for key, value in env_vars.items():
            print(f"   {key}: {value}")
            
        return env_vars
    
    def health_check(self) -> dict:
        """
        Verifica que el servicio funciona correctamente.
        
        Returns:
            dict: Estado del servicio
        """
        try:
            test_message = self.print_message("Health check test", "System")
            return {
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'test_message': test_message,
                'environment': self.environment
            }
        except Exception as e:
            return {
                'status': 'unhealthy',
                'timestamp': datetime.now().isoformat(),
                'error': str(e),
                'environment': self.environment
            }