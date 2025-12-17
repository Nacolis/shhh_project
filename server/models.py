import uuid
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy import Column, Integer, String, Text, TIMESTAMP, Boolean, Enum, ForeignKey, Index, CheckConstraint, LargeBinary
from sqlalchemy.orm import relationship
from datetime import datetime
from server import db


class User(db.Model):
    __tablename__ = 'users'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    unique_username = Column(String(255), unique=True, nullable=False, comment='Identifiant unique non modifiable')
    username = Column(String(100), unique=True, nullable=False, comment='Nom d\'utilisateur modifiable')
    password_hash = Column(String(255), nullable=False, comment='Hash du mot de passe (bcrypt/argon2)')
    rsa_public_key = Column(Text, nullable=False, comment='Clé publique RSA de l\'utilisateur')
    dh_public_key = Column(Text, nullable=False, comment='Clé publique Diffie-Hellman')
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index('idx_username', 'username'),
        Index('idx_user_id', 'id'),
    )

    sent_messages = relationship('PrivateMessage', foreign_keys='PrivateMessage.sender_id', back_populates='sender', cascade='all, delete-orphan')
    received_messages = relationship('PrivateMessage', foreign_keys='PrivateMessage.receiver_id', back_populates='receiver', cascade='all, delete-orphan')
    created_groups = relationship('Group', back_populates='creator', cascade='all, delete-orphan')
    group_memberships = relationship('GroupMember', back_populates='user', cascade='all, delete-orphan')
    group_messages = relationship('GroupMessage', back_populates='sender', cascade='all, delete-orphan')
    qr_codes = relationship('QRCode', back_populates='user', cascade='all, delete-orphan')




class Group(db.Model):
    __tablename__ = 'groups'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    group_name = Column(String(255), nullable=False)
    creator_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, comment='Créateur du groupe')
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_creator', 'creator_id'),
    )
    
    # Relations
    creator = relationship('User', back_populates='created_groups')
    members = relationship('GroupMember', back_populates='group', cascade='all, delete-orphan')
    messages = relationship('GroupMessage', back_populates='group', cascade='all, delete-orphan')


class GroupMember(db.Model):
    __tablename__ = 'group_members'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    group_id = Column(Integer, ForeignKey('groups.id', ondelete='CASCADE'), nullable=False)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    joined_at = Column(TIMESTAMP, default=datetime.utcnow, comment='Date d\'arrivée dans le groupe')
    role = Column(Enum('admin', 'member', name='group_role'), default='member')
    
    __table_args__ = (
        db.UniqueConstraint('group_id', 'user_id', name='unique_group_member'),
        Index('idx_group', 'group_id'),
        Index('idx_user', 'user_id'),
    )
    
    group = relationship('Group', back_populates='members')
    user = relationship('User', back_populates='group_memberships')


class PrivateMessage(db.Model):
    __tablename__ = 'private_messages'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    sender_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    receiver_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    ciphertext = Column(Text, nullable=False, comment='Message chiffré avec AES')
    nonce = Column(String(255), nullable=False, comment='Nonce/IV pour AES-GCM')
    auth_tag = Column(String(255), nullable=False, comment='Tag d\'authentification GCM')
    signature = Column(Text, nullable=False, comment='Signature RSA du message')
    message_type = Column(Enum('text', 'image', 'audio', name='message_type'), default='text')
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    is_read = Column(Boolean, default=False)
    
    __table_args__ = (
        Index('idx_conversation', 'sender_id', 'receiver_id', 'created_at'),
        Index('idx_receiver_unread', 'receiver_id', 'is_read'),
    )
    
    sender = relationship('User', foreign_keys=[sender_id], back_populates='sent_messages')
    receiver = relationship('User', foreign_keys=[receiver_id], back_populates='received_messages')


class GroupMessage(db.Model):
    """Group message header - stores metadata and links to encrypted copies"""
    __tablename__ = 'group_messages'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    group_id = Column(Integer, ForeignKey('groups.id', ondelete='CASCADE'), nullable=False)
    sender_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    message_type = Column(Enum('text', 'image', 'audio', name='group_message_type'), default='text')
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_group_messages', 'group_id', 'created_at'),
        Index('idx_sender', 'sender_id'),
    )
    
    group = relationship('Group', back_populates='messages')
    sender = relationship('User', back_populates='group_messages')
    encrypted_copies = relationship('GroupMessageCopy', back_populates='message', cascade='all, delete-orphan')


class GroupMessageCopy(db.Model):
    """Encrypted copy of a group message for each recipient (pairwise encryption)"""
    __tablename__ = 'group_message_copies'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    message_id = Column(Integer, ForeignKey('group_messages.id', ondelete='CASCADE'), nullable=False)
    recipient_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    ciphertext = Column(Text, nullable=False, comment='Message chiffré avec la clé partagée avec ce destinataire')
    nonce = Column(String(255), nullable=False)
    auth_tag = Column(String(255), nullable=False)
    signature = Column(Text, nullable=False, comment='Signature RSA de l\'expéditeur')
    is_read = Column(Boolean, default=False)
    
    __table_args__ = (
        Index('idx_message_recipient', 'message_id', 'recipient_id'),
        Index('idx_recipient_unread', 'recipient_id', 'is_read'),
        db.UniqueConstraint('message_id', 'recipient_id', name='unique_message_recipient'),
    )
    
    message = relationship('GroupMessage', back_populates='encrypted_copies')
    recipient = relationship('User')





class MediaFile(db.Model):
    __tablename__ = 'media_files'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    file_hash = Column(String(255), unique=True, nullable=False, comment='Hash du fichier pour déduplication')
    encrypted_data = Column(LargeBinary(length=2**32-1), nullable=False, comment='Données chiffrées du fichier')
    file_type = Column(Enum('image', 'audio', name='file_type'), nullable=False)
    mime_type = Column(String(100))
    file_size = Column(Integer, nullable=False)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_hash', 'file_hash'),
    )
    
    message_links = relationship('MessageMedia', back_populates='media', cascade='all, delete-orphan')


class MessageMedia(db.Model):
    __tablename__ = 'message_media'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    message_id = Column(Integer, nullable=False)
    message_table = Column(Enum('private_messages', 'group_messages', name='message_table_type'), nullable=False)
    media_id = Column(Integer, ForeignKey('media_files.id', ondelete='CASCADE'), nullable=False)
    
    __table_args__ = (
        Index('idx_message', 'message_table', 'message_id'),
    )
    
    media = relationship('MediaFile', back_populates='message_links')


class QRCode(db.Model):
    __tablename__ = 'qr_codes'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    qr_token = Column(String(255), unique=True, nullable=False, comment='Token unique pour le QR code')
    expires_at = Column(TIMESTAMP, nullable=False)
    is_used = Column(Boolean, default=False)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_token', 'qr_token'),
        Index('idx_expires', 'expires_at'),
    )
    
    user = relationship('User', back_populates='qr_codes')
