#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

APP_DIR="/var/www/my-app"
GUNICORN_SOCK="${APP_DIR}/myapp.sock"
NGINX_CONFIG="/etc/nginx/sites-available/myapp"

# Clean up old app
echo "Deleting old app"
sudo rm -rf "$APP_DIR"

# Create app folder
echo "Creating app folder"
sudo mkdir -p "$APP_DIR"

# Move files to app folder, specify what should be moved
echo "Moving app files to app folder"
sudo mv deploy.sh server.py requirements.txt "$APP_DIR"
sudo mv env "$APP_DIR/.env"

# Navigate to the app directory
cd "$APP_DIR"

# Install Python and pip if not installed
echo "Installing Python and pip"
sudo apt-get update
sudo apt-get install -y python3 python3-pip

# Install application dependencies
if [[ -f "requirements.txt" ]]; then
    echo "Installing application dependencies from requirements.txt"
    sudo pip3 install -r requirements.txt
else
    echo "requirements.txt not found, skipping dependency installation"
fi

# Install and configure Nginx if not installed
if ! command -v nginx > /dev/null; then
    echo "Nginx not found, installing it"
    sudo apt-get install -y nginx
fi

# Set up Nginx reverse proxy if not configured
if [[ ! -f "$NGINX_CONFIG" ]]; then
    echo "Setting up Nginx configuration"
    sudo bash -c "cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name _;

    location / {
        include proxy_params;
        proxy_pass http://unix:$GUNICORN_SOCK;
    }
}
EOF"
    sudo ln -s "$NGINX_CONFIG" /etc/nginx/sites-enabled/
    sudo systemctl restart nginx
else
    echo "Nginx reverse proxy configuration already exists."
fi

# Stop any existing Gunicorn processes
echo "Stopping existing Gunicorn process (if any)"
sudo pkill -f gunicorn || echo "No Gunicorn process running."

# Remove old Gunicorn socket
sudo rm -f "$GUNICORN_SOCK"

# Start Gunicorn with the Flask application
echo "Starting Gunicorn"
sudo gunicorn --workers 3 --bind unix:"$GUNICORN_SOCK" server:app --user www-data --group www-data --daemon

# Check if Gunicorn started successfully
if pgrep -f gunicorn > /dev/null; then
    echo "Gunicorn started successfully 🚀"
else
    echo "Failed to start Gunicorn ❌"
    exit 1
fi
