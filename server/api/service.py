from ..models import User, PrivateMessage, Group, GroupMember, GroupMessage, GroupMessageCopy, db
from sqlalchemy import or_
from datetime import datetime

def get_user_by_username(unique_username):
    return User.query.filter_by(unique_username=unique_username).first()

def get_user_by_id(user_id):
    return User.query.get(user_id)

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
    db.session.flush()

    admin_member = GroupMember(group_id=group.id, user_id=creator_id, role='admin')
    db.session.add(admin_member)

    for uid in member_ids:
        if uid != creator_id:
            member = GroupMember(group_id=group.id, user_id=uid, role='member')
            db.session.add(member)
    
    db.session.commit()
    return group

def save_group_message(sender_id, group_id, encrypted_copies, message_type='text'):
    """
    Save a group message with pairwise encrypted copies for each recipient.
    
    Args:
        sender_id: ID of the sender
        group_id: ID of the group
        encrypted_copies: List of dicts with keys: recipient_username, ciphertext, nonce, auth_tag, signature
        message_type: Type of message (text, image, audio)
    
    Returns:
        The created GroupMessage and list of GroupMessageCopy objects
    """
    
    member = GroupMember.query.filter_by(group_id=group_id, user_id=sender_id).first()
    if not member:
        raise ValueError("User is not a member of this group")

    
    message = GroupMessage(
        group_id=group_id,
        sender_id=sender_id,
        message_type=message_type
    )
    db.session.add(message)
    db.session.flush()  

    
    copies = []
    recipient_ids = []
    for copy_data in encrypted_copies:
        recipient = get_user_by_username(copy_data['recipient_username'])
        if not recipient:
            continue
        
        
        recipient_member = GroupMember.query.filter_by(group_id=group_id, user_id=recipient.id).first()
        if not recipient_member:
            continue
            
        copy = GroupMessageCopy(
            message_id=message.id,
            recipient_id=recipient.id,
            ciphertext=copy_data['ciphertext'],
            nonce=copy_data['nonce'],
            auth_tag=copy_data['auth_tag'],
            signature=copy_data['signature']
        )
        db.session.add(copy)
        copies.append(copy)
        recipient_ids.append(recipient.id)
    
    db.session.commit()
    return message, copies, recipient_ids

def get_group_messages(group_id, user_id, limit=50):
    """Get group messages for a specific user (returns their encrypted copies)"""
    
    member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if not member:
        raise ValueError("User is not a member of this group")
    
    
    messages = db.session.query(GroupMessage, GroupMessageCopy)\
        .join(GroupMessageCopy, GroupMessage.id == GroupMessageCopy.message_id)\
        .filter(GroupMessage.group_id == group_id)\
        .filter(GroupMessageCopy.recipient_id == user_id)\
        .order_by(GroupMessage.created_at.desc())\
        .limit(limit)\
        .all()
    
    return messages

def get_pending_group_messages(user_id):
    """Get unread group message copies for a user"""
    copies = GroupMessageCopy.query\
        .filter_by(recipient_id=user_id, is_read=False)\
        .join(GroupMessage, GroupMessageCopy.message_id == GroupMessage.id)\
        .order_by(GroupMessage.created_at.asc())\
        .all()
    return copies

def mark_group_messages_as_read(copy_ids, user_id):
    """Mark group message copies as read"""
    GroupMessageCopy.query.filter(
        GroupMessageCopy.id.in_(copy_ids),
        GroupMessageCopy.recipient_id == user_id
    ).update({GroupMessageCopy.is_read: True}, synchronize_session=False)
    db.session.commit()

def get_group_members(group_id):
    """Get all members of a group"""
    members = GroupMember.query.filter_by(group_id=group_id).all()
    return [m.user for m in members]

def get_user_groups(user_id):
    """Get all groups a user is a member of"""
    memberships = GroupMember.query.filter_by(user_id=user_id).all()
    return [m.group for m in memberships]

def is_group_admin(group_id, user_id):
    member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    return member is not None and member.role == 'admin'

def is_group_member(group_id, user_id):
    member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    return member is not None

def delete_group(group_id, user_id):
    if not is_group_admin(group_id, user_id):
        raise ValueError("Only group admin can delete the group")
    
    group = Group.query.get(group_id)
    if not group:
        raise ValueError("Group not found")
    
    db.session.delete(group)
    db.session.commit()
    return True

def add_member_to_group(group_id, user_id, added_by_user_id):
    if not is_group_admin(group_id, added_by_user_id):
        raise ValueError("Only group admin can add members")
    existing = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if existing:
        raise ValueError("User is already a member of this group")
    
    member = GroupMember(group_id=group_id, user_id=user_id, role='member')
    db.session.add(member)
    db.session.commit()
    return member

def remove_member_from_group(group_id, user_id, removed_by_user_id):
    is_admin = is_group_admin(group_id, removed_by_user_id)
    is_self = user_id == removed_by_user_id
    
    if not is_admin and not is_self:
        raise ValueError("Only group admin can remove members or you can remove yourself")
    
    member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if not member:
        raise ValueError("User is not a member of this group")
    
    if member.role == 'admin':
        admin_count = GroupMember.query.filter_by(group_id=group_id, role='admin').count()
        if admin_count <= 1:
            raise ValueError("Cannot remove the last admin. Transfer admin role first or delete the group.")
    
    db.session.delete(member)
    db.session.commit()
    return True

def leave_group(group_id, user_id):
    return remove_member_from_group(group_id, user_id, user_id)

def delete_private_conversation(user_id, other_user_id):
    """Delete all private messages between two users"""
    PrivateMessage.query.filter(
        or_(
            (PrivateMessage.sender_id == user_id) & (PrivateMessage.receiver_id == other_user_id),
            (PrivateMessage.sender_id == other_user_id) & (PrivateMessage.receiver_id == user_id)
        )
    ).delete(synchronize_session=False)
    db.session.commit()
    return True
