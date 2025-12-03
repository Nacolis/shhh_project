from ..models import User, PrivateMessage, Group, GroupMember, GroupMessage, db
from sqlalchemy import or_
from datetime import datetime

def get_user_by_username(unique_username):
    return User.query.filter_by(unique_username=unique_username).first()

def search_users(query):
    return User.query.filter(User.username.ilike(f'%{query}%')).all()

def save_private_message(sender_id, receiver_id, ciphertext, nonce, auth_tag, signature, message_type='text'):
    message = PrivateMessage(
        sender_id=sender_id,
        receiver_id=receiver_id,
        ciphertext=ciphertext,
        nonce=nonce,
        auth_tag=auth_tag,
        signature=signature,
        message_type=message_type
    )
    db.session.add(message)
    db.session.commit()
    return message

def get_pending_messages(user_id):
    # Get unread messages
    messages = PrivateMessage.query.filter_by(receiver_id=user_id, is_read=False).all()
    return messages

def mark_messages_as_read(message_ids, user_id):
    PrivateMessage.query.filter(
        PrivateMessage.id.in_(message_ids), 
        PrivateMessage.receiver_id == user_id
    ).update({PrivateMessage.is_read: True}, synchronize_session=False)
    db.session.commit()

def create_group(creator_id, group_name, member_ids):
    group = Group(
        group_name=group_name,
        creator_id=creator_id
    )
    db.session.add(group)
    db.session.flush() # Get ID

    # Add creator as admin
    admin_member = GroupMember(group_id=group.id, user_id=creator_id, role='admin')
    db.session.add(admin_member)

    # Add other members
    for uid in member_ids:
        if uid != creator_id:
            member = GroupMember(group_id=group.id, user_id=uid, role='member')
            db.session.add(member)
    
    db.session.commit()
    return group

def save_group_message(sender_id, group_id, ciphertext, nonce, auth_tag, signature, message_type='text'):
    # Verify sender is member
    member = GroupMember.query.filter_by(group_id=group_id, user_id=sender_id).first()
    if not member:
        raise ValueError("User is not a member of this group")

    message = GroupMessage(
        group_id=group_id,
        sender_id=sender_id,
        ciphertext=ciphertext,
        nonce=nonce,
        auth_tag=auth_tag,
        signature=signature,
        message_type=message_type
    )
    db.session.add(message)
    db.session.commit()
    return message

def get_group_messages(group_id, user_id, limit=50):
    # Verify membership
    member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if not member:
        raise ValueError("User is not a member of this group")
        
    return GroupMessage.query.filter_by(group_id=group_id)\
        .order_by(GroupMessage.created_at.desc())\
        .limit(limit)\
        .all()
