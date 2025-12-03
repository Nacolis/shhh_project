from time import timezone
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from . import service
import logging

bp = Blueprint('api', __name__)
logger = logging.getLogger(__name__)

@bp.route('/users/<unique_username>/keys', methods=['GET'])
@jwt_required()
def get_user_keys(unique_username):
    """Get public keys for a user
    ---
    tags:
      - Users
    security:
      - Bearer: []
    parameters:
      - name: unique_username
        in: path
        type: string
        required: true
        description: The unique username of the user
    responses:
      200:
        description: User public keys
        schema:
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
      404:
        description: User not found
    """
    print("Fetching keys for user:", unique_username)
    logger.info(f"Fetching keys for user: {unique_username}")
    user = service.get_user_by_username(unique_username)
    if not user:
        return jsonify({"error": "User not found"}), 404
    
    return jsonify({
        "id": user.id,
        "username": user.username,
        "unique_username": user.unique_username,
        "rsa_public_key": user.rsa_public_key,
        "dh_public_key": user.dh_public_key
    })

@bp.route('/messages', methods=['POST'])
@jwt_required()
def send_message():
    """Send a private message
    ---
    tags:
      - Messages
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - receiver_username
            - ciphertext
            - nonce
            - auth_tag
            - signature
          properties:
            receiver_username:
              type: string
              description: Recipient's unique username
            ciphertext:
              type: string
              description: Encrypted message content
            nonce:
              type: string
              description: Nonce used for encryption
            auth_tag:
              type: string
              description: Authentication tag
            signature:
              type: string
              description: Digital signature
    responses:
      201:
        description: Message sent successfully
      400:
        description: Missing fields
      404:
        description: Receiver not found
    """
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    
    receiver_username = data.get('receiver_username')
    ciphertext = data.get('ciphertext')
    nonce = data.get('nonce')
    auth_tag = data.get('auth_tag')
    signature = data.get('signature')
    
    if not all([receiver_username, ciphertext, nonce, auth_tag, signature]):
        return jsonify({"error": "Missing fields"}), 400
        
    receiver = service.get_user_by_username(receiver_username)
    if not receiver:
        return jsonify({"error": "Receiver not found"}), 404
        
    service.save_private_message(
        sender_id=current_user_id,
        receiver_id=receiver.id,
        ciphertext=ciphertext,
        nonce=nonce,
        auth_tag=auth_tag,
        signature=signature
    )
    
    return jsonify({"message": "Message sent"}), 201

@bp.route('/messages', methods=['GET'])
@jwt_required()
def get_messages():
    """Get pending messages
    ---
    tags:
      - Messages
    security:
      - Bearer: []
    responses:
      200:
        description: List of pending messages
        schema:
          type: array
          items:
            type: object
            properties:
              id:
                type: integer
              sender:
                type: string
              ciphertext:
                type: string
              nonce:
                type: string
              auth_tag:
                type: string
              signature:
                type: string
              timestamp:
                type: string
                format: date-time
    """
    current_user_id = int(get_jwt_identity())
    messages = service.get_pending_messages(current_user_id)
    
    result = []
    for msg in messages:
        result.append({
            "id": msg.id,
            "sender": msg.sender.unique_username,
            "ciphertext": msg.ciphertext,
            "nonce": msg.nonce,
            "auth_tag": msg.auth_tag,
            "signature": msg.signature,
            "timestamp": msg.created_at.replace(tzinfo=timezone.utc).isoformat().replace('+00:00', 'Z')
        })
        
    return jsonify(result)

@bp.route('/messages/ack', methods=['POST'])
@jwt_required()
def ack_messages():
    """Mark messages as read
    ---
    tags:
      - Messages
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            message_ids:
              type: array
              items:
                type: integer
              description: List of message IDs to mark as read
    responses:
      200:
        description: Messages marked as read
    """
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    message_ids = data.get('message_ids', [])
    
    service.mark_messages_as_read(message_ids, current_user_id)
    return jsonify({"message": "Messages marked as read"}), 200

@bp.route('/groups', methods=['POST'])
@jwt_required()
def create_group():
    """Create a new group
    ---
    tags:
      - Groups
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - group_name
          properties:
            group_name:
              type: string
              description: Name of the group
            members:
              type: array
              items:
                type: string
              description: List of unique_usernames to add to the group
    responses:
      201:
        description: Group created successfully
        schema:
          type: object
          properties:
            message:
              type: string
            group_id:
              type: integer
      400:
        description: Group name required
    """
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    group_name = data.get('group_name')
    member_usernames = data.get('members', []) # List of unique_usernames
    
    if not group_name:
        return jsonify({"error": "Group name required"}), 400
        
    member_ids = [current_user_id]
    for username in member_usernames:
        u = service.get_user_by_username(username)
        if u:
            member_ids.append(u.id)
            
    group = service.create_group(current_user_id, group_name, list(set(member_ids)))
    
    return jsonify({"message": "Group created", "group_id": group.id}), 201

@bp.route('/groups/<int:group_id>/messages', methods=['POST'])
@jwt_required()
def send_group_message(group_id):
    """Send a message to a group
    ---
    tags:
      - Groups
    security:
      - Bearer: []
    parameters:
      - name: group_id
        in: path
        type: integer
        required: true
        description: The group ID
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            ciphertext:
              type: string
            nonce:
              type: string
            auth_tag:
              type: string
            signature:
              type: string
    responses:
      201:
        description: Message sent
      403:
        description: Not a member of the group
    """
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    
    try:
        service.save_group_message(
            sender_id=current_user_id,
            group_id=group_id,
            ciphertext=data.get('ciphertext'),
            nonce=data.get('nonce'),
            auth_tag=data.get('auth_tag'),
            signature=data.get('signature')
        )
        return jsonify({"message": "Message sent"}), 201
    except ValueError as e:
        return jsonify({"error": str(e)}), 403

@bp.route('/groups/<int:group_id>/messages', methods=['GET'])
@jwt_required()
def get_group_messages(group_id):
    """Get messages from a group
    ---
    tags:
      - Groups
    security:
      - Bearer: []
    parameters:
      - name: group_id
        in: path
        type: integer
        required: true
        description: The group ID
    responses:
      200:
        description: List of group messages
        schema:
          type: array
          items:
            type: object
            properties:
              id:
                type: integer
              sender:
                type: string
              ciphertext:
                type: string
              nonce:
                type: string
              auth_tag:
                type: string
              signature:
                type: string
              timestamp:
                type: string
                format: date-time
      403:
        description: Not a member of the group
    """
    current_user_id = int(get_jwt_identity())
    try:
        messages = service.get_group_messages(group_id, current_user_id)
        result = []
        for msg in messages:
            result.append({
                "id": msg.id,
                "sender": msg.sender.unique_username,
                "ciphertext": msg.ciphertext,
                "nonce": msg.nonce,
                "auth_tag": msg.auth_tag,
                "signature": msg.signature,
                "timestamp": msg.created_at.isoformat()
            })
        return jsonify(result)
    except ValueError as e:
        return jsonify({"error": str(e)}), 403
