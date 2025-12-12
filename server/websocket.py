"""
WebSocket support for real-time messaging
"""
from flask_socketio import SocketIO, emit, join_room, leave_room, disconnect
from flask_jwt_extended import decode_token
from flask import request
import logging

logger = logging.getLogger(__name__)


socketio = SocketIO(cors_allowed_origins="*", async_mode='eventlet')


connected_users = {}


def get_user_id_from_token(token):
    """Extract user ID from JWT token"""
    try:
        decoded = decode_token(token)
        return int(decoded['sub'])
    except Exception as e:
        logger.error(f"Failed to decode token: {e}")
        return None


@socketio.on('connect')
def handle_connect():
    """Handle new WebSocket connection"""
    token = request.args.get('token')
    if not token:
        logger.warning("Connection attempt without token")
        disconnect()
        return False
    
    user_id = get_user_id_from_token(token)
    if not user_id:
        logger.warning("Connection attempt with invalid token")
        disconnect()
        return False
    
    
    request.user_id = user_id
    sid = request.sid
    
    
    if user_id not in connected_users:
        connected_users[user_id] = set()
    connected_users[user_id].add(sid)
    
    
    join_room(f"user_{user_id}")
    
    logger.info(f"User {user_id} connected with session {sid}")
    emit('connected', {'status': 'connected', 'user_id': user_id})
    return True


@socketio.on('disconnect')
def handle_disconnect():
    """Handle WebSocket disconnection"""
    user_id = getattr(request, 'user_id', None)
    sid = request.sid
    
    if user_id and user_id in connected_users:
        connected_users[user_id].discard(sid)
        if not connected_users[user_id]:
            del connected_users[user_id]
    
    logger.info(f"User {user_id} disconnected (session {sid})")


@socketio.on('join_group')
def handle_join_group(data):
    """Join a group room for group messages"""
    group_id = data.get('group_id')
    user_id = getattr(request, 'user_id', None)
    
    if not group_id or not user_id:
        return
    
    
    room = f"group_{group_id}"
    join_room(room)
    logger.info(f"User {user_id} joined group room {room}")
    emit('joined_group', {'group_id': group_id})


@socketio.on('leave_group')
def handle_leave_group(data):
    """Leave a group room"""
    group_id = data.get('group_id')
    user_id = getattr(request, 'user_id', None)
    
    if not group_id:
        return
    
    room = f"group_{group_id}"
    leave_room(room)
    logger.info(f"User {user_id} left group room {room}")


def notify_new_private_message(receiver_id, message_data):
    """Notify a user of a new private message"""
    room = f"user_{receiver_id}"
    socketio.emit('new_private_message', message_data, room=room)
    logger.info(f"Notified user {receiver_id} of new private message")


def notify_new_group_message(group_id, sender_id, message_id):
    """Notify group members of a new group message"""
    room = f"group_{group_id}"
    socketio.emit('new_group_message', {
        'group_id': group_id,
        'sender_id': sender_id,
        'message_id': message_id
    }, room=room)
    logger.info(f"Notified group {group_id} of new message from {sender_id}")


def notify_user_message_available(user_id, message_data):
    """Notify a specific user that a new message is available for them"""
    room = f"user_{user_id}"
    socketio.emit('message_available', message_data, room=room)


def is_user_online(user_id):
    """Check if a user is currently connected"""
    return user_id in connected_users and len(connected_users[user_id]) > 0
