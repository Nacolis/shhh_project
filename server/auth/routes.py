# server/auth/routes.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, create_refresh_token, jwt_required, get_jwt_identity
from sqlalchemy.exc import OperationalError
from datetime import timedelta, datetime
import logging
from werkzeug.security import generate_password_hash
from ..models import User
from .. import jwt, db
from . import service

bp = Blueprint('auth', __name__)
logger = logging.getLogger(__name__)

@bp.route('/register', methods=['POST'])
def register():
    """Register a new user"""
    try:
        data = request.get_json()
        unique_username = data.get('unique_username')
        username = data.get('username')
        password = data.get('password')
        rsa_public_key = data.get('rsa_public_key')
        dh_public_key = data.get('dh_public_key')

        if not all([username, password, unique_username, rsa_public_key, dh_public_key]):
            return jsonify({"error": "All fields are required"}), 400
        
        new_user = service.register_user(
            unique_username=unique_username,
            username=username,
            password=password,
            rsa_public_key=rsa_public_key,
            dh_public_key=dh_public_key
        )
        
        return jsonify({
            "message": "User registered successfully",
            "user": {
                "id": new_user.id,
                "username": new_user.username,
                "unique_username": new_user.unique_username
            }
        }), 201
    
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        return jsonify({"error": "Registration failed"}), 500
    
