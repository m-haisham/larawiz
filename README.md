# Larawiz

This script automates the setup process for a Laravel application on an Ubuntu server. It installs and configures Nginx, Supervisor, PHP 8.3, Composer, and sets up SSL certificates using Certbot. Additionally, it provides basic Vim configuration for development purposes.

## Requirements

- Ubuntu server with sudo privileges
- SSH key for authentication
- GitHub repository URL of the Laravel project
- Domain name for the application

## Environment Variables

Before running the Larawiz script, ensure the following environment variables are set or provided as input during execution:

- ALERT_EMAIL: Your email address for receiving alerts.
- LARAVEL_REPO_URL: The URL of your Laravel application repository on GitHub.
- DOMAIN_NAME: The domain name for configuring Nginx.

Optionally, you can set the following environment variable to skip input prompts and use predefined values:

- SKIP_INPUT: Set to "true" to skip input prompts.
- SSH_KEY_PRIVATE: The private SSH key for accessing GitHub repositories.
- SSH_KEY_PUBLIC: The public SSH key for accessing GitHub repositories.

## Usage

1. Download and execute the script directly from GitHub:

   ```bash
   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/m-haisham/larawiz/v0.1.3/setup.sh)"
   ```

2. Follow the prompts to provide necessary inputs such as SSH key, GitHub repository URL, and domain name.

## What Does This Script Do?

- Updates and upgrades the system.
- Installs necessary dependencies like Nginx, Git, Composer, PHP 8.3, Supervisor, Certbot, and Npm.
- Creates a new user named 'it' and sets up SSH key authentication for GitHub access.
- Clones the Laravel project from the specified GitHub repository.
- Installs Laravel dependencies using Composer.
- Configures Nginx to serve the Laravel application.
- Obtains and installs SSL certificates using Certbot for secure HTTPS connection.
- Sets up Supervisor to manage Laravel queues, ensuring efficient queue processing.
- Adds Laravel Scheduler to Crontab for running scheduled tasks.
- Sets up basic Vim configuration for development purposes.

## Doctor Script

The `doctor.sh` script helps diagnose and fix common issues with the Laravel application setup. It checks for the presence of required dependencies, verifies configurations, and ensures that services are running correctly.

### Usage

1. Download and replace any existing `doctor.sh` script:

   ```bash
   sudo curl -o doctor.sh https://raw.githubusercontent.com/m-haisham/larawiz/v0.1.3/doctor.sh
   sudo chmod +x doctor.sh
   ```

2. Execute the `doctor.sh` script:

   ```bash
   sudo doctor.sh
   ```

The script will:

- Verify the installation of essential commands.
- Check PHP version and required extensions.
- Validate Nginx configuration and ensure the service is running.
- Ensure the PHP-FPM service is running
- Verify Supervisor service status
- Check UFW status and display rules.
- Validate the presence and validity of SSL certificates.
- Verify the existence of the Laravel `.env` file.
- Check permissions of the `storage` and `bootstrap/cache` directories.
- Ensure the Supervisor configuration for Laravel queues exists.
- Display the server's IP address.

### Notes

- The script assumes the current folder contains the Laravel project if `composer.json` is present. It uses the folder name as `DOMAIN_NAME` and the current folder as `PROJECT_FOLDER`.
- If `composer.json` is not found, the script will prompt you to enter `DOMAIN_NAME` and `PROJECT_FOLDER`.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script is provided as-is, without any warranty or guarantee. Use it at your own risk. Always backup your data before running scripts that make system-level changes.
