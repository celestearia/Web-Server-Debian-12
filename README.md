
# Serveur Linux WP- Debian 12

This script installs and configures a web server with Apache2, PHP-FPM, and optionally WordPress on a Debian 12 (Bookworm) system.

## Features
- Checks and modifies IPv4 addressing.
- Sets up cryptographic materials.
- Installs Apache2, PHP-FPM, MariaDB, and WordPress.
- Configures support for HTTPS transport.

## Requirements
- Root privileges to execute the script.

## Usage

1. Ensure you have root access to run the script.
2. Execute the script: 

\`\`\`bash
sudo ./serveur-linux_wp-deb12.sh
\`\`\`

### Functions

#### Network Configuration
- Checks and sets static IP addressing.
- Tests internet connectivity.

#### System Update
- Updates system packages.

#### Apache Installation and Configuration
- Installs Apache2 if not already installed.
- Configures Apache2 modules and PHP-FPM integration.

#### PHP Installation and Configuration
- Installs PHP 8.2-FPM.
- Updates PHP configurations based on user input (timezone, memory limit, max execution time).

#### Virtual Host Setup
- Configures a virtual host based on user input (ServerName).
- Creates a default index.php page.

## TODO
- HTTPS configuration.
- WordPress installation.

## Acknowledgements
- Thanks to my professor, Monsieur Sebastien VINCENT, for his support and guidance. Visit his [website](https://www.vincent-netsys.fr/html/index.html).

## License
This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
