from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from flask_migrate import Migrate
import os
from dotenv import load_dotenv

load_dotenv()

# Initialize extensions
db = SQLAlchemy()
jwt = JWTManager()
migrate = Migrate()

def create_app(config_name=None):
    """Application factory pattern"""
    app = Flask(__name__)
    
    if config_name is None:
        config_name = os.getenv('FLASK_ENV', 'production')
    
    app.config.from_object(f'server.config.{config_name.capitalize()}Config')
    
    # Initialize extensions with app
    db.init_app(app)
    jwt.init_app(app)
    migrate.init_app(app, db)
    CORS(app)
    
    # Register blueprints
    from server.auth.routes import bp as auth_bp
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    
    # Register CLI commands
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
    
    # @app.cli.command('reset-db')
    # def reset_db():
    #     db.drop_all()
    #     db.create_all()
    #     print('Database reset !')