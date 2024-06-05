# Larawiz

This script automates the setup process for a Laravel application on an Ubuntu server. It installs and configures Nginx, Supervisor, PHP 8.3, Composer, and sets up SSL certificates using Certbot. Additionally, it provides basic Vim configuration for development purposes.

## Requirements

- Ubuntu server with sudo privileges
- SSH key for authentication
- GitHub repository URL of the Laravel project
- Domain name for the application

## Environment Variables

Before running the Larawiz script, ensure the following environment variables are set or provided as input during execution:

- `ALERT_EMAIL`: Your email address for receiving alerts.
- `LARAVEL_REPO_URL`: The URL of your Laravel application repository on GitHub.
- `DOMAIN_NAME`: The domain name for configuring Nginx.

Optionally, you can set the following environment variable to skip input prompts and use predefined values:

- `SKIP_INPUT`: Set to "true" to skip input prompts.
- `SSH_KEY_PRIVATE`: The private SSH key for accessing GitHub repositories.
- `SSH_KEY_PUBLIC`: The public SSH key for accessing GitHub repositories.

## Usage

1. Download and execute the script directly from GitHub:

   ```bash
   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/m-haisham/larawiz/v0.1.2/setup.sh)"
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

## Notes

- Ensure that your server meets the specified requirements before running the script.
- The script assumes a fresh Ubuntu server setup. Running it on an existing server may overwrite existing configurations.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script is provided as-is, without any warranty or guarantee. Use it at your own risk. Always backup your data before running scripts that make system-level changes.
