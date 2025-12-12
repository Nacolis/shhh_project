from datetime import timezone
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from . import service
from ..websocket import notify_new_private_message, notify_user_message_available
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
    
    sender = service.get_user_by_id(current_user_id)
    notify_new_private_message(receiver.id, {
        'sender': sender.unique_username if sender else 'unknown',
        'type': 'private_message'
    })
    
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
    member_usernames = data.get('members', [])
    
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
    """Send a message to a group (pairwise encrypted for each member)
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
            encrypted_copies:
              type: array
              description: Array of encrypted copies for each recipient
              items:
                type: object
                properties:
                  recipient_username:
                    type: string
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
    
    encrypted_copies = data.get('encrypted_copies', [])
    if not encrypted_copies:
        return jsonify({"error": "No encrypted copies provided"}), 400
    
    try:
        message, copies, recipient_ids = service.save_group_message(
            sender_id=current_user_id,
            group_id=group_id,
            encrypted_copies=encrypted_copies
        )
        
        sender = service.get_user_by_id(current_user_id)
        for recipient_id in recipient_ids:
            notify_user_message_available(recipient_id, {
                'type': 'group_message',
                'group_id': group_id,
                'message_id': message.id,
                'sender': sender.unique_username if sender else 'unknown'
            })
        
        return jsonify({
            "message": "Message sent",
            "message_id": message.id,
            "copies_created": len(copies)
        }), 201
    except ValueError as e:
        return jsonify({"error": str(e)}), 403

@bp.route('/groups/<int:group_id>/messages', methods=['GET'])
@jwt_required()
def get_group_messages(group_id):
    """Get messages from a group (returns user's encrypted copies)
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
              message_id:
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
        for msg, copy in messages:
            result.append({
                "id": copy.id,
                "message_id": msg.id,
                "sender": msg.sender.unique_username,
                "group_id": group_id,
                "ciphertext": copy.ciphertext,
                "nonce": copy.nonce,
                "auth_tag": copy.auth_tag,
                "signature": copy.signature,
                "timestamp": msg.created_at.replace(tzinfo=timezone.utc).isoformat().replace('+00:00', 'Z')
            })
        return jsonify(result)
    except ValueError as e:
        return jsonify({"error": str(e)}), 403

@bp.route('/groups/<int:group_id>/members', methods=['GET'])
@jwt_required()
def get_group_members(group_id):
    """Get all members of a group with their public keys
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
        description: List of group members with keys
        schema:
          type: array
          items:
            type: object
            properties:
              id:
                type: integer
              unique_username:
                type: string
              username:
                type: string
              rsa_public_key:
                type: string
              dh_public_key:
                type: string
      403:
        description: Not a member of the group
    """
    current_user_id = int(get_jwt_identity())
    
    from ..models import GroupMember
    member = GroupMember.query.filter_by(group_id=group_id, user_id=current_user_id).first()
    if not member:
        return jsonify({"error": "Not a member of this group"}), 403
    
    members = service.get_group_members(group_id)
    result = []
    for user in members:
        result.append({
            "id": user.id,
            "unique_username": user.unique_username,
            "username": user.username,
            "rsa_public_key": user.rsa_public_key,
            "dh_public_key": user.dh_public_key
        })
    return jsonify(result)

@bp.route('/groups', methods=['GET'])
@jwt_required()
def get_user_groups():
    """Get all groups the user is a member of
    ---
    tags:
      - Groups
    security:
      - Bearer: []
    responses:
      200:
        description: List of groups
        schema:
          type: array
          items:
            type: object
            properties:
              id:
                type: integer
              name:
                type: string
              member_count:
                type: integer
              created_at:
                type: string
                format: date-time
    """
    current_user_id = int(get_jwt_identity())
    groups = service.get_user_groups(current_user_id)
    
    result = []
    for group in groups:
        result.append({
            "id": group.id,
            "name": group.group_name,
            "member_count": len(group.members),
            "created_at": group.created_at.replace(tzinfo=timezone.utc).isoformat().replace('+00:00', 'Z')
        })
    return jsonify(result)

@bp.route('/messages/pending', methods=['GET'])
@jwt_required()
def get_all_pending_messages():
    """Get all pending messages (private + group) for the current user
    ---
    tags:
      - Messages
    security:
      - Bearer: []
    responses:
      200:
        description: All pending messages
        schema:
          type: object
          properties:
            private_messages:
              type: array
            group_messages:
              type: array
    """
    current_user_id = int(get_jwt_identity())
    
    private_msgs = service.get_pending_messages(current_user_id)
    private_result = []
    for msg in private_msgs:
        private_result.append({
            "id": msg.id,
            "type": "private",
            "sender": msg.sender.unique_username,
            "ciphertext": msg.ciphertext,
            "nonce": msg.nonce,
            "auth_tag": msg.auth_tag,
            "signature": msg.signature,
            "timestamp": msg.created_at.replace(tzinfo=timezone.utc).isoformat().replace('+00:00', 'Z')
        })
    
    group_copies = service.get_pending_group_messages(current_user_id)
    group_result = []
    for copy in group_copies:
        msg = copy.message
        group_result.append({
            "id": copy.id,
            "message_id": msg.id,
            "type": "group",
            "group_id": msg.group_id,
            "sender": msg.sender.unique_username,
            "ciphertext": copy.ciphertext,
            "nonce": copy.nonce,
            "auth_tag": copy.auth_tag,
            "signature": copy.signature,
            "timestamp": msg.created_at.replace(tzinfo=timezone.utc).isoformat().replace('+00:00', 'Z')
        })
    
    return jsonify({
        "private_messages": private_result,
        "group_messages": group_result
    })

@bp.route('/messages/group/ack', methods=['POST'])
@jwt_required()
def ack_group_messages():
    """Mark group message copies as read
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
            copy_ids:
              type: array
              items:
                type: integer
              description: List of group message copy IDs to mark as read
    responses:
      200:
        description: Messages marked as read
    """
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    copy_ids = data.get('copy_ids', [])
    
    service.mark_group_messages_as_read(copy_ids, current_user_id)
    return jsonify({"message": "Messages marked as read"}), 200
