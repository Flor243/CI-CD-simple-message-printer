# src/printer/__init__.py
"""
Simple Message Printer - Printer Module
Módulo principal para imprimir mensajes en Cloud Functions.
"""

from .message_printer import MessagePrinter
from .config import Config

__all__ = ['MessagePrinter', 'Config']