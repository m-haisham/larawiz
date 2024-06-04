#!/bin/bash

###############################################################################
# Description:
#   This script automates the setup process for a Laravel application on a
#   Ubuntu server, including installing dependencies, configuring Nginx,
#   setting up SSL certificates, configuring Supervisor for queue processing,
#   and more.
#
#   Before running this script, ensure the following environment variables are
#   set or provided as input during execution:
#
#   - ALERT_EMAIL: Your email address for receiving alerts.
#   - LARAVEL_REPO_URL: The URL of your Laravel application repository on GitHub.
#   - DOMAIN_NAME: The domain name for configuring Nginx.
#
#   Optionally, you can set the following environment variable to skip input
#   prompts and use predefined values:
#
#   - SKIP_INPUT: Set to "true" to skip input prompts.
#   - SSH_KEY_PRIVATE: The private SSH key for accessing GitHub repositories.
#   - SSH_KEY_PUBLIC: The public SSH key for accessing GitHub repositories.
#
# Usage:
#   sudo ./setup_laravel.sh
#
# Note:
#   This script must be run with root privileges.
###############################################################################

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges to install packages and configure system settings."
    echo "Please run the script with sudo."
    exit 1
fi

# Function to prompt for input or use environment variable
prompt() {
    if [[ "${SKIP_INPUT,,}" != "true" ]]; then
        return 0
    fi

    if [ -n "${!2}" ]; then
        echo "$1: ${!2}"
    else
        read -p "$1: " $2
    fi
}

# Validate non-empty input
validate_input() {
    if [ -z "${!2}" ]; then
        echo "Error: $1 cannot be empty"
        exit 1
    fi
}

# Prompt for all inputs or use environment variables
prompt "Enter your email address for alerts" ALERT_EMAIL
validate_input "Alert email" "ALERT_EMAIL"

prompt "Enter your GitHub repository URL (e.g., git@github.com:username/repo.git)" LARAVEL_REPO_URL
validate_input "GitHub repository URL" "LARAVEL_REPO_URL"

prompt "Enter your domain name for Nginx configuration" DOMAIN_NAME
validate_input "Domain name" "DOMAIN_NAME"

PROJECT_FOLDER="/var/www/$DOMAIN_NAME"

echo "Updating and upgrading the system..."
sudo apt update -y
sudo apt upgrade -y

echo "Installing required dependencies..."
sudo apt install -y curl openssl nginx git unzip software-properties-common supervisor python3-certbot-nginx ufw iproute2

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

    # Flag indicating 'it' user has just been created
    JUST_CREATED_IT=true
fi

# Check if the SSH directory exists for the 'it' user
if [ ! -d "/home/it/.ssh" ]; then
    echo "Creating .ssh directory for user 'it'..."
    sudo -u it mkdir -p /home/it/.ssh
fi

# Copy SSH authorized keys from current user to the 'it' user if 'it' user was just created
if [ "$JUST_CREATED_IT" = true ]; then
    echo "Copying SSH authorized keys to user 'it'..."
    sudo cp ~/.ssh/authorized_keys /home/it/.ssh/
    sudo chown it:it /home/it/.ssh/authorized_keys
    sudo chmod 600 /home/it/.ssh/authorized_keys

    # Print information about the password and SSH key
    echo "Password for user 'it' is: $IT_PASSWORD"
    echo "SSH keys copied to user 'it'."
fi

echo "Setting up firewall with UFW..."
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# if command -v php8.3 >/dev/null 2>&1; then
#     installed_version=$(php -v | head -n 1 | awk '{print $2}')
#     echo "PHP version $installed_version is installed."
#     if [[ "$installed_version" != "8.3"* ]]; then
#         echo "Another version of PHP is installed. Please uninstall the current PHP version first:"
#         echo "    sudo apt remove --purge php*"
#         echo "    sudo apt autoremove"
#         echo "    sudo apt autoclean"
#         exit 1
#     fi
# else
#     echo "No PHP installation detected. Proceeding with PHP 8.3 installation..."
# fi

# Install PHP 8.3
if ! command -v php8.3 >/dev/null 2>&1; then
    echo "Adding PHP repository and installing PHP 8.3 and extensions..."
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update -y
    sudo apt install -y php8.3 php8.3-cli php8.3-fpm php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl php8.3-zip php8.3-bcmath php8.3-intl
    sudo update-alternatives --set php /usr/bin/php8.3
else
    echo "PHP 8.3 is already installed."
fi

# Install Certbot if not installed
if ! command -v certbot >/dev/null 2>&1; then
    echo "Installing Certbot..."
    sudo -u it apt install -y certbot
else
    echo "Certbot is already installed."
fi

# Check if Composer is installed
if ! command -v composer >/dev/null 2>&1; then
    echo "Installing Composer..."
    sudo -u it curl -sS https://getcomposer.org/installer | sudo -u it php
    sudo -u it mv composer.phar /usr/local/bin/composer
else
    echo "Composer is already installed."
fi

# Install NVM, npm, and Node.js
if ! command -v nvm >/dev/null 2>&1; then
    echo "Installing NVM (Node Version Manager)..."
    sudo -u it curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    echo "Copying NVM configuration to 'it' user..."
    sudo cp ~/.nvm /home/it/ -r
    sudo chown it:it /home/it/.nvm -R
    echo "Reloading bash to use NVM..."
    export NVM_DIR="/home/it/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && sudo -u it \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && sudo -u it \. "$NVM_DIR/bash_completion"
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

SSH_DIR="/home/it/.ssh"
SSH_KEY_PRIVATE_FILE="$SSH_DIR/id_ed25519"
SSH_KEY_PUBLIC_FILE="$SSH_KEY_PRIVATE_FILE.pub"

# Check if SSH key already exists or provided via environment variable
if [ -f "$SSH_KEY_PRIVATE_FILE" ]; then
    echo "SSH key already exists."
elif [ -n "${SSH_KEY_PRIVATE}" ] && [ -n "${SSH_KEY_PUBLIC}" ]; then
    echo "Using provided SSH key..."
    echo "${SSH_KEY_PRIVATE}" >"$SSH_KEY_PRIVATE_FILE"
    echo "${SSH_KEY_PUBLIC}" >"$SSH_KEY_PUBLIC_FILE"
    sudo chown it:it "$SSH_KEY_PRIVATE_FILE" "$SSH_KEY_PUBLIC_FILE"
    sudo chmod 600 "$SSH_KEY_PRIVATE_FILE"
    echo "SSH key saved to $SSH_KEY_PRIVATE_FILE and $SSH_KEY_PUBLIC_FILE."
else
    # Generate an SSH key if it doesn't exist
    echo "Generating an ED25519 SSH key for GitHub..."
    sudo -u it ssh-keygen -t ed25519 -f "$SSH_KEY_PRIVATE_FILE" -N ""

    # Display the SSH key for the user to copy
    echo "SSH public key for GitHub:"
    sudo -u it cat "$SSH_KEY_PUBLIC_FILE.pub"
    echo ""

    # Prompt the user to add the SSH key to GitHub
    echo "Add this key to your GitHub account: https://github.com/settings/keys"
    if [[ "${SKIP_INPUT,,}" != "true" ]]; then
        read -p "Press [Enter] after adding the SSH key to GitHub..."
    fi
fi

echo "Cloning the Laravel project from GitHub..."
sudo -u it -u it git clone "$LARAVEL_REPO_URL" "$PROJECT_FOLDER"

echo "Installing Laravel dependencies..."
cd "$PROJECT_FOLDER" && sudo -u it composer install --no-dev -o

echo "Setting permissions for www-data..."
sudo chown -R www-data:www-data "$PROJECT_FOLDER"
sudo chmod -R 775 "$PROJECT_FOLDER/storage" "$PROJECT_FOLDER/bootstrap/cache"

echo "Setting up environment file..."
sudo cp "$PROJECT_FOLDER/.env.example" "$PROJECT_FOLDER/.env"
sudo -u www-data sudo php "$PROJECT_FOLDER/artisan" key:generate

echo "Configuring Nginx..."
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN_NAME"
sudo -u it tee $NGINX_CONF >/dev/null <<EOL
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
sudo -u it certbot --nginx -d $DOMAIN_NAME -n --agree-tos --email $ALERT_EMAIL

echo "Enabling Nginx site and restarting service..."
sudo -u it ln -s $NGINX_CONF /etc/nginx/sites-enabled/
sudo -u it systemctl restart nginx

echo "Configuring Supervisor for Laravel queues..."
sudo -u it tee "/etc/supervisor/conf.d/$DOMAIN_NAME-queue.conf" >/dev/null <<EOL
[program:queue]
process_name=%(program_name)s_%(process_num)02d
command=cd $PROJECT_FOLDER && php artisan queue:work --sleep=3 --tries=3 --timeout=90
autostart=true
autorestart=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=$PROJECT_FOLDER/storage/logs/queue.log
EOL

echo "Reloading Supervisor to apply new configuration..."
sudo -u it supervisorctl reread
sudo -u it supervisorctl update
sudo -u it supervisorctl start queue:*

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
echo "   vim .env"
echo "3. Update the database connection details, mail settings, and any other configuration specific to your application."
echo "4. Save the changes and exit the editor."
echo "5. Run the following command to optimize your configuration:"
echo "   php artisan config:cache"
echo "6. Run any necessary Laravel artisan commands to migrate and seed your database, if applicable."
echo "7. Finally, restart your web server and queue workers as needed."
echo ""
echo "Additional steps for frontend assets (if applicable):"
echo "1. Navigate to your project folder:"
echo "   cd $PROJECT_FOLDER"
echo "2. Install npm dependencies:"
echo "   npm install"
echo "3. Build frontend assets:"
echo "   npm run build"
