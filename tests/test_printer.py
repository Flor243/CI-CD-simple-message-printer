# tests/test_printer.py
import unittest
import os
import sys
from unittest.mock import patch, MagicMock

# Agregar src al path para imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from printer.message_printer import MessagePrinter
from printer.config import Config
from utils.logger import setup_logger

class TestMessagePrinter(unittest.TestCase):
    """Tests para MessagePrinter"""
    
    def setUp(self):
        """Setup antes de cada test"""
        self.printer = MessagePrinter()
    
    def test_print_message_basic(self):
        """Test básico de print_message"""
        result = self.printer.print_message("Hello Test", "TestUser")
        
        self.assertIsInstance(result, str)
        self.assertIn("Hello Test", result)
        self.assertIn("TestUser", result)
        self.assertIn("🖨️", result)  # Default prefix
    
    def test_print_message_no_user(self):
        """Test print_message sin especificar usuario"""
        result = self.printer.print_message("Hello Test")
        
        self.assertIsInstance(result, str)
        self.assertIn("Hello Test", result)
        # Debería usar DEFAULT_USER del entorno o "Anonymous"
    
    @patch.dict(os.environ, {'MESSAGE_PREFIX': '📝', 'ENVIRONMENT': 'test'})
    def test_print_message_with_env_vars(self):
        """Test con variables de entorno customizadas"""
        printer = MessagePrinter()  # Nuevo instance para cargar env vars
        result = printer.print_message("Test with env", "EnvUser")
        
        self.assertIn("📝", result)  # Custom prefix
        self.assertIn("[TEST]", result)  # Environment en mayúsculas
        self.assertIn("Test with env", result)
        self.assertIn("EnvUser", result)
    
    def test_print_multiple_messages(self):
        """Test de múltiples mensajes"""
        messages = ["Message 1", "Message 2", "Message 3"]
        results = self.printer.print_multiple_messages(messages, "TestUser")
        
        self.assertEqual(len(results), 3)
        for i, result in enumerate(results, 1):
            self.assertIn(f"Message {i}:", result)
            self.assertIn(f"Message {i}", result)
            self.assertIn("TestUser", result)
    
    def test_print_environment_info(self):
        """Test de información del entorno"""
        env_info = self.printer.print_environment_info()
        
        self.assertIsInstance(env_info, dict)
        
        required_keys = [
            'ENVIRONMENT', 'MESSAGE_PREFIX', 'DEFAULT_USER',
            'FUNCTION_NAME', 'FUNCTION_REGION', 'DEPLOYED_BY',
            'COMMIT_SHA', 'BRANCH'
        ]
        
        for key in required_keys:
            self.assertIn(key, env_info)
    
    def test_health_check_success(self):
        """Test de health check exitoso"""
        health = self.printer.health_check()
        
        self.assertIsInstance(health, dict)
        self.assertEqual(health['status'], 'healthy')
        self.assertIn('timestamp', health)
        self.assertIn('test_message', health)
        self.assertIn('environment', health)
    
    @patch('builtins.print', side_effect=Exception("Print failed"))
    def test_health_check_failure(self):
        """Test de health check con falla"""
        health = self.printer.health_check()
        
        self.assertIsInstance(health, dict)
        self.assertEqual(health['status'], 'unhealthy')
        self.assertIn('error', health)
        self.assertIn('timestamp', health)

class TestConfig(unittest.TestCase):
    """Tests para Config"""
    
    def test_config_defaults(self):
        """Test valores por defecto de configuración"""
        self.assertEqual(Config.LOG_LEVEL, os.getenv('LOG_LEVEL', 'INFO'))
        self.assertEqual(Config.ENVIRONMENT, os.getenv('ENVIRONMENT', 'development'))
        self.assertIsInstance(Config.MAX_MESSAGE_LENGTH, int)
        self.assertIsInstance(Config.MAX_MESSAGES_PER_REQUEST, int)
    
    def test_get_all_config(self):
        """Test get_all_config"""
        config = Config.get_all_config()
        
        self.assertIsInstance(config, dict)
        
        required_keys = [
            'LOG_LEVEL', 'ENVIRONMENT', 'DEFAULT_MESSAGE',
            'DEFAULT_USER', 'MESSAGE_PREFIX', 'MAX_MESSAGE_LENGTH'
        ]
        
        for key in required_keys:
            self.assertIn(key, config)
    
    def test_validate_config_success(self):
        """Test validación exitosa de configuración"""
        validation = Config.validate_config()
        
        self.assertIsInstance(validation, dict)
        self.assertIn('valid', validation)
        self.assertIn('errors', validation)
        self.assertIn('warnings', validation)
        self.assertIn('config', validation)
        
        # Con la config por defecto debería ser válida
        self.assertTrue(validation['valid'])
        self.assertEqual(len(validation['errors']), 0)
    
    @patch.dict(os.environ, {'MAX_MESSAGE_LENGTH': '0'})
    def test_validate_config_failure(self):
        """Test validación con configuración inválida"""
        # Necesitamos recargar la clase Config para que tome las nuevas env vars
        # En un caso real, esto se haría reiniciando la aplicación
        
        # Para este test, vamos a mockear directamente
        with patch.object(Config, 'MAX_MESSAGE_LENGTH', 0):
            validation = Config.validate_config()
            
            self.assertFalse(validation['valid'])
            self.assertGreater(len(validation['errors']), 0)

class TestLogger(unittest.TestCase):
    """Tests para Logger"""
    
    def test_setup_logger_basic(self):
        """Test básico de setup_logger"""
        logger = setup_logger()
        
        self.assertIsNotNone(logger)
        self.assertEqual(logger.name, 'simple_printer')
        self.assertTrue(len(logger.handlers) > 0)
    
    def test_setup_logger_custom_name(self):
        """Test setup_logger con nombre personalizado"""
        logger = setup_logger('custom_logger')
        
        self.assertIsNotNone(logger)
        self.assertEqual(logger.name, 'custom_logger')
    
    @patch.dict(os.environ, {'LOG_LEVEL': 'DEBUG'})
    def test_setup_logger_debug_level(self):
        """Test setup_logger con nivel DEBUG"""
        import logging
        logger = setup_logger('debug_logger')
        
        self.assertEqual(logger.level, logging.DEBUG)

if __name__ == '__main__':
    # Configurar entorno de test
    os.environ.setdefault('ENVIRONMENT', 'test')
    os.environ.setdefault('LOG_LEVEL', 'DEBUG')
    
    unittest.main()