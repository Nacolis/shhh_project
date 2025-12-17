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
    """Register a new user
    ---
    tags:
      - Authentication
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - unique_username
            - username
            - password
            - rsa_public_key
            - dh_public_key
          properties:
            unique_username:
              type: string
              description: Unique identifier for the user
            username:
              type: string
              description: Display name
            password:
              type: string
              description: User password
            rsa_public_key:
              type: string
              description: RSA public key for encryption
            dh_public_key:
              type: string
              description: Diffie-Hellman public key
    responses:
      201:
        description: User registered successfully
        schema:
          type: object
          properties:
            message:
              type: string
            user:
              type: object
              properties:
                id:
                  type: integer
                username:
                  type: string
                unique_username:
                  type: string
      400:
        description: Missing fields or validation error
      500:
        description: Server error
    """
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

@bp.route('/login', methods=['POST'])
def login():
    """Login a user and return JWT token
    ---
    tags:
      - Authentication
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - unique_username
            - password
          properties:
            unique_username:
              type: string
              description: Unique identifier for the user
            password:
              type: string
              description: User password
    responses:
      200:
        description: Login successful
        schema:
          type: object
          properties:
            message:
              type: string
            access_token:
              type: string
              description: JWT token for authentication
            user:
              type: object
              properties:
                id:
                  type: integer
                username:
                  type: string
                unique_username:
                  type: string
                rsa_public_key:
                  type: string
                dh_public_key:
                  type: string
      400:
        description: Missing credentials
      401:
        description: Invalid credentials
      500:
        description: Server error
    """
    try:
        data = request.get_json()
        unique_username = data.get('unique_username')
        password = data.get('password')

        if not all([unique_username, password]):
            return jsonify({"error": "Username and password are required"}), 400

        user = service.authenticate_user(unique_username, password)

        if not user:
            return jsonify({"error": "Invalid credentials"}), 401

        # Create JWT token (use string subject to satisfy JWT subject type) 1hour
        access_token = create_access_token(identity=str(user.id),expires_delta=timedelta(hours=1))
        
        return jsonify({
            "message": "Login successful",
            "access_token": access_token,
            "user": {
                "id": user.id,
                "username": user.username,
                "unique_username": user.unique_username,
                "rsa_public_key": user.rsa_public_key,
                "dh_public_key": user.dh_public_key
            }
        }), 200

    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({"error": "Login failed"}), 500

