from ..models import User, PrivateMessage, Group, GroupMember, GroupMessage, GroupMessageRecipient, db
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

def get_group_members(group_id, user_id):
    """
    Get all members of a group.
    
    Args:
        group_id: ID of the group
        user_id: ID of the requesting user (for verification)
    
    Returns:
        List of group members
    """
    # Verify membership
    member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if not member:
        raise ValueError("User is not a member of this group")
    
    members = db.session.query(User, GroupMember)\
        .join(GroupMember, User.id == GroupMember.user_id)\
        .filter(GroupMember.group_id == group_id)\
        .all()
    
    return members

def save_group_message(sender_id, group_id, encrypted_payloads, signature, message_type='text'):
    """
    Save a group message with pairwise encryption.
    
    Args:
        sender_id: ID of the message sender
        group_id: ID of the group
        encrypted_payloads: List of dicts with keys: recipient_id, ciphertext, nonce, auth_tag
        signature: Digital signature of the sender
        message_type: Type of message (text, image, audio)
    """
    # Verify sender is member
    member = GroupMember.query.filter_by(group_id=group_id, user_id=sender_id).first()
    if not member:
        raise ValueError("User is not a member of this group")
    
    # Get all group members to verify all recipients are provided
    group_members = GroupMember.query.filter_by(group_id=group_id).all()
    member_ids = {m.user_id for m in group_members}
    
    # Verify that encrypted payloads are provided for all members
    provided_recipient_ids = {p['recipient_id'] for p in encrypted_payloads}
    if not member_ids.issubset(provided_recipient_ids):
        missing = member_ids - provided_recipient_ids
        raise ValueError(f"Missing encrypted payloads for recipients: {missing}")

    # Create the group message
    message = GroupMessage(
        group_id=group_id,
        sender_id=sender_id,
        signature=signature,
        message_type=message_type
    )
    db.session.add(message)
    db.session.flush()  # Get the message ID
    
    # Create encrypted versions for each recipient
    for payload in encrypted_payloads:
        if payload['recipient_id'] in member_ids:
            recipient = GroupMessageRecipient(
                message_id=message.id,
                recipient_id=payload['recipient_id'],
                ciphertext=payload['ciphertext'],
                nonce=payload['nonce'],
                auth_tag=payload['auth_tag']
            )
            db.session.add(recipient)
    
    db.session.commit()
    return message

def get_group_messages(group_id, user_id, limit=50):
    """
    Get group messages for a specific user with their encrypted payload.
    
    Returns messages with the encrypted version specific to the requesting user.
    """
    # Verify membership
    member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if not member:
        raise ValueError("User is not a member of this group")
    
    # Get messages with the recipient's encrypted payload
    messages = db.session.query(GroupMessage, GroupMessageRecipient)\
        .join(GroupMessageRecipient, GroupMessage.id == GroupMessageRecipient.message_id)\
        .filter(GroupMessage.group_id == group_id)\
        .filter(GroupMessageRecipient.recipient_id == user_id)\
        .order_by(GroupMessage.created_at.desc())\
        .limit(limit)\
        .all()
    
    return messages
