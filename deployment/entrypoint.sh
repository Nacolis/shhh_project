#!/bin/bash
set -e

echo "Waiting for database to be ready..."

while ! nc -z db 3306; do
    echo "Database is unavailable - sleeping"
    sleep 2
done

echo "Database is up - proceeding with initialization"

if [ -d "migrations" ]; then
    echo "Running database migrations..."
    flask db upgrade
    echo "Migrations applied successfully!"
else
    echo "No migrations folder found, initializing database with db.create_all()..."
    python -c "from server import create_app, db; app = create_app(); app.app_context().push(); db.create_all(); print('Database tables created successfully')"
fi

echo "Database initialization complete!"

exec "$@"
