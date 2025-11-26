"""
Application entry point for Flask CLI and Gunicorn
"""
from server import create_app

# Create app instance for Flask CLI commands and Gunicorn
app = create_app()
