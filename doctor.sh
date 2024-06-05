#!/bin/bash

###############################################################################
# Description:
#   This script checks the setup and status of a Laravel application on an
#   Ubuntu server, including verifying dependencies, Nginx configuration,
#   SSL certificates, Supervisor for queue processing, and more.
#
# Usage:
#   sudo ./doctor.sh
#
# Note:
#   This script must be run with root privileges.
###############################################################################

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges to check system settings."
    echo "Please run the script with sudo."
    exit 1
fi

# Function to check if a service is running
check_service_status() {
    local SERVICE=$1
    if systemctl is-active --quiet $SERVICE; then
        echo "$SERVICE is running."
    else
        echo "$SERVICE is not running."
        echo "Attempting to restart $SERVICE..."
        sudo systemctl restart $SERVICE
        if systemctl is-active --quiet $SERVICE; then
            echo "$SERVICE successfully restarted."
        else
            echo "Failed to restart $SERVICE."
        fi
    fi
}

# Determine PROJECT_FOLDER and DOMAIN_NAME
if [ -f "./composer.json" ]; then
    PROJECT_FOLDER=$(pwd)
    DOMAIN_NAME=$(basename $PROJECT_FOLDER)
else
    echo "composer.json not found. Please provide the DOMAIN_NAME and PROJECT_FOLDER."
    read -p "Enter the DOMAIN_NAME: " DOMAIN_NAME
    read -p "Enter the PROJECT_FOLDER: " PROJECT_FOLDER
fi

echo "Using DOMAIN_NAME: $DOMAIN_NAME"
echo "Using PROJECT_FOLDER: $PROJECT_FOLDER"

# Section 1: Check essential commands
echo "Checking essential commands..."
commands=("curl" "openssl" "nginx" "git" "unzip" "supervisor" "certbot" "ufw" "php" "composer" "node" "npm")

for cmd in "${commands[@]}"; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Command $cmd is not installed. Please install it."
    else
        echo "Command $cmd is installed."
    fi
done

echo "------------------------------------------------------------"

# Section 2: Check PHP version and extensions
echo "Checking PHP version and extensions..."
PHP_VERSION=$(php -v | head -n 1 | awk '{print $2}')
if [[ "$PHP_VERSION" == "8.3"* ]]; then
    echo "PHP version 8.3 is installed."
else
    echo "PHP version 8.3 is not installed. Current version: $PHP_VERSION"
fi

php_extensions=("php8.3-cli" "php8.3-fpm" "php8.3-mysql" "php8.3-xml" "php8.3-mbstring" "php8.3-curl" "php8.3-zip" "php8.3-bcmath" "php8.3-intl")

for ext in "${php_extensions[@]}"; do
    if dpkg -l | grep -q $ext; then
        echo "$ext is installed."
    else
        echo "$ext is not installed."
    fi
done

echo "------------------------------------------------------------"

# Section 3: Check Nginx configuration and service
echo "Checking Nginx configuration and service..."
if nginx -t >/dev/null 2>&1; then
    echo "Nginx configuration is valid."
else
    echo "Nginx configuration is invalid."
    echo "Please check the Nginx configuration files."
fi

check_service_status "nginx"

echo "------------------------------------------------------------"

# Section 4: Check PHP-FPM service
echo "Checking PHP-FPM service..."
check_service_status "php8.3-fpm"

echo "------------------------------------------------------------"

# Section 5: Check Supervisor service
echo "Checking Supervisor service..."
check_service_status "supervisor"

echo "------------------------------------------------------------"

# Section 6: Check UFW status and rules
echo "Checking UFW status and rules..."
if sudo ufw status | grep -qw "active"; then
    echo "UFW is active."
else
    echo "UFW is not active."
fi

echo "UFW rules:"
sudo ufw status numbered

echo "------------------------------------------------------------"

# Section 7: Check SSL certificate status
echo "Checking SSL certificate status..."
SSL_CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
if [ -f "$SSL_CERT_PATH" ]; then
    echo "SSL certificate exists for $DOMAIN_NAME."
    sudo openssl x509 -enddate -noout -in "$SSL_CERT_PATH"
else
    echo "SSL certificate does not exist for $DOMAIN_NAME."
    echo "You may need to run: sudo certbot --nginx -d $DOMAIN_NAME -n --agree-tos --email $ALERT_EMAIL"
fi

echo "------------------------------------------------------------"

# Section 8: Check Laravel .env file
echo "Checking Laravel .env file..."
if [ -f "$PROJECT_FOLDER/.env" ]; then
    echo ".env file exists in the project folder."
else
    echo ".env file does not exist in the project folder."
fi

echo "------------------------------------------------------------"

# Section 9: Check Laravel storage and bootstrap/cache permissions
echo "Checking Laravel storage and bootstrap/cache permissions..."
if [ -w "$PROJECT_FOLDER/storage" ] && [ -w "$PROJECT_FOLDER/bootstrap/cache" ]; then
    echo "Permissions for storage and bootstrap/cache are correctly set."
else
    echo "Permissions for storage and/or bootstrap/cache are not correctly set."
fi

echo "------------------------------------------------------------"

# Section 10: Check Laravel queue configuration
echo "Checking Laravel queue configuration..."
SUPERVISOR_CONF="/etc/supervisor/conf.d/$DOMAIN_NAME-queue.conf"
if [ -f "$SUPERVISOR_CONF" ]; then
    echo "Supervisor configuration for Laravel queue exists."
else
    echo "Supervisor configuration for Laravel queue does not exist."
fi

echo "------------------------------------------------------------"

# Section 11: Display Server IP address
echo "Displaying Server IP address..."
SERVER_IP_ADDRESS=$(ip route get 1 | awk '{print $NF;exit}')
echo "Server IP address: $SERVER_IP_ADDRESS"

echo "------------------------------------------------------------"

echo "Doctor script execution complete."
