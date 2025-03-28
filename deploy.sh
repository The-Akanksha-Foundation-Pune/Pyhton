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

# Update apt-get and install dependencies
sudo apt-get update
echo "Installing Python and pip"
sudo apt-get install -y python3 python3-pip

#echo "Installing application dependencies"
#sudo apt-get install python3-venv
#sudo python3 -m venv venv
#source venv/bin/activate
#echo “Acrivated ENV”
#sudo chown -R ubuntu:ubuntu /var/www/my-app
#sudo chown -R ubuntu:ubuntu /home/ubuntu/venv
#pip3 install -r requirements.txt

# Install and configure Nginx if it's not installed
if ! command -v nginx > /dev/null; then
    echo "Installing Nginx"
    sudo apt-get install -y nginx
fi

# Create Nginx configuration if it doesn't exist
if [ ! -f /etc/nginx/sites-available/myapp ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo bash -c 'cat > /etc/nginx/sites-available/myapp <<EOF
server {
    listen 80;
    server_name 54.224.169.32;  # Change to your actual server IP

    location / {
        include proxy_params;
        proxy_pass http://127.0.0.1:5000;  # Forward traffic to Gunicorn on port 5000
    }
}
EOF'
    sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled
    sudo systemctl restart nginx
else
    echo "Nginx configuration already exists."
fi

# Restart Gunicorn
echo "Stopping any existing Gunicorn instances"
sudo pkill gunicorn

# Remove any old socket file
sudo rm -f /var/www/my-app/myapp.sock

echo "Starting Gunicorn"
sudo gunicorn --workers 3 --bind 0.0.0.0:5000 --user www-data --group www-data --daemon app:app
echo "Gunicorn started"


