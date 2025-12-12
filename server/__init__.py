from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from flask_migrate import Migrate
from flasgger import Swagger
import os
from dotenv import load_dotenv

load_dotenv()


db = SQLAlchemy()
jwt = JWTManager()
migrate = Migrate()


from server.websocket import socketio


swagger_config = {
    "headers": [],
    "specs": [
        {
            "endpoint": "apispec",
            "route": "/apispec.json",
            "rule_filter": lambda rule: True,
            "model_filter": lambda tag: True,
        }
    ],
    "static_url_path": "/flasgger_static",
    "swagger_ui": True,
    "specs_route": "/apidocs/"
}

swagger_template = {
    "info": {
        "title": "Shhh API",
        "description": "Secure messaging API with end-to-end encryption",
        "version": "1.0.0",
        "contact": {
            "name": "API Support"
        }
    },
    "securityDefinitions": {
        "Bearer": {
            "type": "apiKey",
            "name": "Authorization",
            "in": "header",
            "description": "JWT Authorization header using the Bearer scheme. Example: 'Bearer {token}'"
        }
    },
    "security": [{"Bearer": []}]
}

def create_app(config_name=None):
    """Application factory pattern"""
    app = Flask(__name__)
    
    if config_name is None:
        config_name = os.getenv('FLASK_ENV', 'production')
    
    app.config.from_object(f'server.config.{config_name.capitalize()}Config')
    
    
    db.init_app(app)
    jwt.init_app(app)
    migrate.init_app(app, db)
    CORS(app, resources={r"/*": {"origins": "*"}})
    Swagger(app, config=swagger_config, template=swagger_template)
    
    
    socketio.init_app(app)
    
    from server.auth.routes import bp as auth_bp
    app.register_blueprint(auth_bp, url_prefix='/api/auth')

    from server.api.routes import bp as api_bp
    app.register_blueprint(api_bp, url_prefix='/api')
    

    register_commands(app)
    

    @app.route('/')
    def index():
        return {"message": "Shhh API Server", "status": "running"}, 200
    
    return app


def register_commands(app):
    """Register custom Flask CLI commands"""
    @app.cli.command('init-db')
    def init_db():
        """Initialize the database (create all tables)."""
        db.create_all()
        print('Database tables created !')
    
    
    
    
    
    