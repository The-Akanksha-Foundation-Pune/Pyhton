#!/bin/bash

echo "Deleting old app"
sudo rm -rf /var/www/

echo "Creating app folder"
sudo mkdir -p /var/www/my-app

echo "Moving app files to app folder"
sudo mv * /var/www/my-app

# Check if the environment file exists before moving it
if [ -f /var/www/my-app/env ]; then
    sudo mv /var/www/my-app/env /var/www/my-app/.env
else
    echo "Warning: env file not found, skipping..."
fi

sudo apt-get update
echo "Installing Python and pip"
sudo apt-get install -y python3 python3-pip

echo "Installing application dependencies"
sudo pip install -r /var/www/my-app/requirements.txt

# Install and configure Nginx
if ! command -v nginx > /dev/null; then
    echo "Installing Nginx"
    sudo apt-get install -y nginx
fi

if [ ! -f /etc/nginx/sites-available/myapp ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo bash -c 'cat > /etc/nginx/sites-available/myapp <<EOF
server {
    listen 80;
    server_name _;

    location / {
        include proxy_params;
        proxy_pass http://unix:/var/www/my-app/myapp.sock;
    }
}
EOF'
    sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled
    sudo systemctl restart nginx
else
    echo "Nginx configuration already exists."
fi

# Restart Gunicorn
sudo pkill gunicorn
sudo rm -f /var/www/my-app/myapp.sock

echo "Starting Gunicorn"
sudo gunicorn --workers 3 --bind unix:/var/www/my-app/myapp.sock server:app --user www-data --group www-data --daemon
echo "Gunicorn started"
