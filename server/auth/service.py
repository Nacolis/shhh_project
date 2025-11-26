from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
from .. import db, jwt
from ..models import User

def register_user(unique_username, username, password, rsa_public_key, dh_public_key):
    """Register a new user with hashed password."""
    existing_user = User.query.filter_by(unique_username=unique_username).first()
    if existing_user:
        raise ValueError("Unique username already exists")

    password_hash = generate_password_hash(password)

    new_user = User(
        unique_username=unique_username,
        username=username,
        password_hash=password_hash,
        rsa_public_key=rsa_public_key,
        dh_public_key=dh_public_key,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )

    db.session.add(new_user)
    db.session.commit()

    return new_user