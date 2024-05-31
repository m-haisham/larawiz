# Larawiz

This script automates the setup process for a Laravel application on an Ubuntu server. It installs and configures Nginx, Supervisor, PHP 8.3, Composer, and sets up SSL certificates using Certbot. Additionally, it provides basic Vim configuration for development purposes.

## Requirements

- Ubuntu server with sudo privileges
- SSH key for authentication
- GitHub repository URL of the Laravel project
- Domain name for the application

## Usage

1. Download and execute the script directly from GitHub:

   ```bash
   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/m-haisham/larawiz/v0.1.0/setup.sh)"
   ```

2. Follow the prompts to provide necessary inputs such as SSH key, GitHub repository URL, and domain name.

## What Does This Script Do?

- Updates and upgrades the system
- Installs required dependencies (Nginx, Git, Composer, PHP 8.3, Supervisor, Certbot)
- Creates a new user and sets up SSH key authentication
- Clones the Laravel project from the specified GitHub repository
- Installs Laravel dependencies using Composer
- Configures Nginx to serve the Laravel application
- Sets up Supervisor to manage Laravel queues
- Adds Laravel Scheduler to Crontab for scheduled tasks
- Obtains and installs SSL certificates using Certbot
- Sets up basic Vim configuration for development

## Notes

- Ensure that your server meets the specified requirements before running the script.
- The script assumes a fresh Ubuntu server setup. Running it on an existing server may overwrite existing configurations.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script is provided as-is, without any warranty or guarantee. Use it at your own risk. Always backup your data before running scripts that make system-level changes.
