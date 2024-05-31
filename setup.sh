#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Function to prompt for input
prompt() {
    read -p "$1: " $2
}

# Validate non-empty input
validate_input() {
    if [ -z "${!2}" ]; then
        echo "Error: $1 cannot be empty"
        exit 1
    fi
}

# Prompt for alert email
prompt "Enter your email address for alerts" ALERT_EMAIL
validate_input "Alert email" "ALERT_EMAIL"

# Prompt for all inputs
prompt "Enter the SSH key for user 'it'" SSH_KEY
validate_input "SSH key" "SSH_KEY"

prompt "Enter your GitHub repository URL (e.g., git@github.com:username/repo.git)" LARAVEL_REPO_URL
validate_input "GitHub repository URL" "LARAVEL_REPO_URL"

prompt "Enter your domain name for Nginx configuration" DOMAIN_NAME
validate_input "Domain name" "DOMAIN_NAME"

PROJECT_FOLDER="/var/www/$DOMAIN_NAME"

echo "Updating and upgrading the system..."
sudo -u it sudo apt update -y
sudo -u it sudo apt upgrade -y

echo "Installing required dependencies..."
sudo -u it sudo apt install -y nginx git unzip curl software-properties-common supervisor python3-certbot-nginx ufw

# Install PHP 8.3
if ! command -v php8.3 >/dev/null 2>&1; then
    echo "Adding PHP repository and installing PHP 8.3 and extensions..."
    sudo -u it sudo add-apt-repository ppa:ondrej/php -y
    sudo -u it sudo apt update -y
    sudo -u it sudo apt install -y php8.3 php8.3-cli php8.3-fpm php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl php8.3-zip php8.3-bcmath php8.3-intl
else
    echo "PHP 8.3 is already installed."
fi

# Install Certbot if not installed
if ! command -v certbot >/dev/null 2>&1; then
    echo "Installing Certbot..."
    sudo -u it sudo apt install -y certbot
else
    echo "Certbot is already installed."
fi

# Check if Composer is installed
if ! command -v composer >/dev/null 2>&1; then
    echo "Installing Composer..."
    sudo -u it sudo curl -sS https://getcomposer.org/installer | sudo -u it sudo php
    sudo -u it sudo mv composer.phar /usr/local/bin/composer
else
    echo "Composer is already installed."
fi

# Install NVM, npm, and Node.js
if ! command -v nvm >/dev/null 2>&1; then
    echo "Installing NVM (Node Version Manager)..."
    sudo -u it curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    echo "Reloading bash to use NVM..."
    source /home/it/.bashrc
else
    echo "NVM (Node Version Manager) is already installed."
fi

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "Installing the latest LTS version of Node.js and npm..."
    sudo -u it nvm install --lts
    sudo -u it nvm use --lts
    sudo -u it nvm alias default node
else
    echo "Node.js and npm are already installed."
fi

# Check if user 'it' exists
if id "it" &>/dev/null; then
    echo "User 'it' already exists."
else
    echo "Creating user 'it' and setting up SSH key..."
    # Generate a random password
    IT_PASSWORD=$(openssl rand -base64 12 | tr -dc '[:alnum:]!@#$%^&*()_+-=' | head -c 12)
    # Create the user with the generated password
    sudo adduser --disabled-password --gecos "" it
    echo "it:$IT_PASSWORD" | sudo chpasswd
    sudo usermod -aG sudo it
    sudo -u it mkdir -p /home/it/.ssh
    sudo -u it echo "$SSH_KEY" >/home/it/.ssh/authorized_keys
    sudo -u it chmod 600 /home/it/.ssh/authorized_keys
    echo "Password for user 'it' is: $IT_PASSWORD"
fi

echo "Setting up firewall with UFW..."
sudo -u it sudo ufw allow OpenSSH
sudo -u it sudo ufw allow 'Nginx Full'
sudo -u it sudo ufw --force enable

SSH_DIR="/home/it/.ssh"
SSH_KEY_FILE="$SSH_DIR/id_ed25519"
# Check if SSH key already exists
if [ -f "$SSH_KEY_FILE" ]; then
    echo "SSH key already exists."
else
    echo "Generating an ED25519 SSH key for GitHub..."
    sudo -u it sudo -u it ssh-keygen -t ed25519 -f "$SSH_KEY_FILE" -N ""
fi

echo "SSH public key for GitHub:"
sudo -u it cat "$SSH_KEY_FILE.pub"

echo "Add this key to your GitHub account: https://github.com/settings/keys"
read -p "Press [Enter] after adding the SSH key to GitHub..."

echo "Cloning the Laravel project from GitHub..."
sudo -u it sudo -u it git clone "$LARAVEL_REPO_URL" "$PROJECT_FOLDER"

echo "Installing Laravel dependencies..."
sudo -u it cd "$PROJECT_FOLDER" && sudo -u it composer install

echo "Setting permissions for www-data..."
sudo chown -R www-data:www-data "$PROJECT_FOLDER"
sudo chmod -R 775 "$PROJECT_FOLDER/storage" "$PROJECT_FOLDER/bootstrap/cache"

echo "Setting up environment file..."
sudo cp "$PROJECT_FOLDER/.env.example" "$PROJECT_FOLDER/.env"
sudo -u www-data sudo php "$PROJECT_FOLDER/artisan" key:generate

echo "Configuring Nginx..."
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN_NAME"
sudo -u it sudo tee $NGINX_CONF >/dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $PROJECT_FOLDER/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_intercept_errors on;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOL

# Configuring Certbot for HTTPS...
sudo -u it sudo certbot --nginx -d $DOMAIN_NAME -n --agree-tos --email $ALERT_EMAIL

echo "Enabling Nginx site and restarting service..."
sudo -u it sudo ln -s $NGINX_CONF /etc/nginx/sites-enabled/
sudo -u it sudo systemctl restart nginx

echo "Configuring Supervisor for Laravel queues..."
sudo -u it sudo tee "/etc/supervisor/conf.d/$DOMAIN_NAME-queue.conf" >/dev/null <<EOL
[program:queue]
process_name=%(program_name)s_%(process_num)02d
command=php $PROJECT_FOLDER/artisan queue:work --sleep=3 --tries=3 --timeout=90
autostart=true
autorestart=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=$PROJECT_FOLDER/storage/logs/worker.log
EOL

echo "Reloading Supervisor to apply new configuration..."
sudo -u it sudo supervisorctl reread
sudo -u it sudo supervisorctl update
sudo -u it sudo supervisorctl start queue:*

echo "Adding Laravel Scheduler to Crontab..."
(
    crontab -l -u www-data 2>/dev/null
    echo "* * * * * cd $PROJECT_FOLDER && php artisan schedule:run >> /dev/null 2>&1"
) | sudo -u it crontab -u www-data -

echo "Setting up basic Vim configuration..."
sudo -u it mkdir -p /home/it/.vim/autoload /home/it/.vim/bundle
sudo -u it curl -LSso /home/it/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
sudo -u it curl -LSso /home/it/.vimrc https://raw.githubusercontent.com/amix/vimrc/master/vimrcs/basic.vim

# Detect and set the server IP address
SERVER_IP_ADDRESS=$(ip route get 1 | awk '{print $NF;exit}')

# Instructions for the user
echo "Setup complete. Your Laravel application is ready."
echo "Make sure to update DNS settings to point your domain to this server's IP address."
echo "You can now access your application at https://$DOMAIN_NAME."
echo ""
echo "Configuration details:"
echo "Password for 'it': $IT_PASSWORD"
echo ""
echo "To SSH into this server as the 'it' user, use the following command:"
echo "ssh it@$SERVER_IP_ADDRESS"
echo "Enter your ssh key password if prompted."
echo ""
echo "Before using your Laravel application, make sure to configure your .env file:"
echo "1. Navigate to your project folder:"
echo "   cd $PROJECT_FOLDER"
echo "2. Open the .env file for editing:"
echo "   nano .env"
echo "3. Update the database connection details, mail settings, and any other configuration specific to your application."
echo "4. Save the changes and exit the editor."
echo "5. Run the following command to optimize your configuration:"
echo "   php artisan config:cache"
echo "6. Run any necessary Laravel artisan commands to migrate and seed your database, if applicable."
echo "7. Finally, restart your web server and queue workers as needed."
