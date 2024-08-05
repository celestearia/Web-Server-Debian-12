#!/bin/bash

# Auteur : John Paul CELESTE
# Date de création : 29/07/2024
# Version : 1.0
# Date de dernière mise à jour : 30/07/2024

# Ce script installe un serveur web Apache2 PHP-FPM, et / ou Wordpress
# L'installation est écrite pour un système Linux Debian 12 (Bookworm)
# Il faut avoir un niveau root pour l'exécuter 

# Ce script : 
## Vérifie / Modifie l'adressage IPv4
## Met en place du matériel cryptographique 
## Installe Apache2, PHP-FPM, MariaDB et Wordpress
## Met en place les supports pour le transport HTTPS 

# Remerciements :
## Merci à mon prof Monsieur Sebastien VINCENT, pour son soutien et ses conseils.
## C'est grâce à ses Travaux Pratiques que le processus de script a été guidé.
## Son site web : https://www.vincent-netsys.fr/html/index.html


# Verification de droit root
if [ "$EUID" -ne 0 ]; then 
    echo "Erreur: Vous devez être root pour executer ce script."
    exit
fi

# Fonctions Globales

function retry_prompt() {
    read -p "Réessayer de nouveau? O/N " REPONSE
    REPONSE=$(echo "$REPONSE" | awk '{print tolower($0)}')
    if [ "$REPONSE" = 'n' ] || [ "$REPONSE" = 'non' ]; then
        echo "Le programme se termine..."
        sleep 3
        exit
    fi
}

function service_test() {
    while ! systemctl is-active --quiet $1; do
        echo "Erreur: Démarrage de service échouée"
        echo "Veuillez vérifier la configuration $2"
        sleep 2
        vi $2
        systemctl restart $1
    done
}

# Main 
# Fonctions réseau
function config_reseau() {
    ## Test du mode de la config réseau et permet à l'utilisateur de changer l'adressage en mode statique
    if grep -q 'iface .* inet static' /etc/network/interfaces; then
        echo "Votre configuration réseau est déjà en mode statique."
        return 0
    else
        ### Affichage des interfaces réseaux
        echo
        echo "Interfaces :" 
        ip -o link show | awk -F': ' '{print $2}'
        echo 
        echo "Configuration IPv4"
        read -p "Nom d'Interface: " INTERFACE
        read -p "IPv4 address: " ADDRESS
        read -p "IP Netmask: " NETMASK
        read -p "Default Gateway: " GATEWAY
        read -p "DNS server: " DNS

        ### Modification du fichier /etc/network/interfaces et test de connectivité
        sed -i "/^iface $INTERFACE inet /c\iface $INTERFACE inet static\n    address $ADDRESS\n    netmask $NETMASK\n    gateway $GATEWAY\n    dns-nameservers $DNS" /etc/network/interfaces
        return 1
    fi
}

function test_connexion() {
    if ping -c 2 www.debian.org &> /dev/null; then
        echo "Test de connexion réussi !"
        return 0
    else
        echo "Connexion échouée, vérifiez votre réseau, svp."
        sleep 2
        vi /etc/network/interfaces
        systemctl restart networking.service
        return 1
    fi
}

## Partie 1: Configuration du réseau
CAP_TEST=1
while [ $CAP_TEST -eq 1 ]; do
    config_reseau
    CAP_CONF=$?
    if [ $CAP_CONF -eq 0 ]; then
        echo "Test de connexion sur internet"
        test_connexion
        CAP_TEST=$?
        if [ $CAP_TEST -eq 1 ]; then
            retry_prompt
        fi
    elif [ $CAP_CONF -eq 1 ]; then
        if ss -tulpn | grep -q ':22'; then
            echo "Connexion SSH détectée"
            echo "Le programme va se terminer..."
            echo "Veuillez reconnecter SSH avec le nouveau IP après le démarrage"
            sleep 2
        else 
            echo "Votre connexion va se redémarrer" 
            systemctl restart networking.service
            test_connexion
            CAP_TEST=$?
            if [ $CAP_TEST -eq 1 ]; then
                retry_prompt
            fi
        fi
    fi
done

## Mise à jour du système
echo "Mise-à-jour des paquets et du système"
apt-get update && apt-get upgrade -y


# Fonctions configuration web

function install_apache () {
    echo "Installation d'Apache2"
    apt-get install -y apache2 
}

function install_php() {
    echo "Installation des paquets PHP"
    apt-get install -y php8.2-fpm 
}

function config_apache() {
    echo "Configuration des modules Apache2"
    a2enmod proxy_fcgi
    a2enmod setenvif 
    a2dismod mpm_prefork
    a2enmod mpm_event
    a2enmod http2
}

function config_php() {
    ## Demander à l'utilisateur de donner les informations requises 
    read -p "Entrer le fuseau horaire (e.g., Europe/Paris): " TIMEZONE
    read -p "Entrer la limite de mémoire (e.g., 512M): " MEMORY_LIMIT
    read -p "Entrer le max temps d'exécution (e.g., 300): " MAX_EXECUTION_TIME

    ## Mettre à jour le fichier /etc/php/8.2/fpm/php.ini
    PHP_INI_FILE="/etc/php/8.2/fpm/php.ini"

    # Ensure the [Date] section exists and update date.timezone
    if grep -q '^\[Date\]' "$PHP_INI_FILE"; then
        sed -i "/^\[Date\]/,/^\[/ s|^;?date.timezone =.*|date.timezone = $TIMEZONE|" "$PHP_INI_FILE"
    else
        echo -e "\n[Date]\ndate.timezone = $TIMEZONE" >> "$PHP_INI_FILE"
    fi

    # Ensure the [PHP] section exists and update memory_limit
    if grep -q '^\[PHP\]' "$PHP_INI_FILE"; then
        sed -i "/^\[PHP\]/,/^\[/ s|^;?memory_limit =.*|memory_limit = $MEMORY_LIMIT|" "$PHP_INI_FILE"
    else
        echo -e "\n[PHP]\nmemory_limit = $MEMORY_LIMIT" >> "$PHP_INI_FILE"
    fi

    # Ensure the [PHP] section exists and update max_execution_time
    if grep -q '^\[PHP\]' "$PHP_INI_FILE"; then
        sed -i "/^\[PHP\]/,/^\[/ s|^;?max_execution_time =.*|max_execution_time = $MAX_EXECUTION_TIME|" "$PHP_INI_FILE"
    else
        echo -e "\n[PHP]\nmax_execution_time = $MAX_EXECUTION_TIME" >> "$PHP_INI_FILE"
    fi

    echo "Configuration mise à jour avec succès."
    return 0
}

## Partie 2 : Installation d'Apache2
if ! command -v apache2 > /dev/null 2>&1; then
    install_apache
else 
    echo "Apache2 déjà installé"
fi
echo
echo "Test Apache2"
systemctl enable --quiet apache2
service_test 'apache2' '/usr/sbin/apachectl'
echo 

## Partie 3 : Installation de PHP8.2-FPM
if ! command -v php > /dev/null 2>&1; then
    install_php
else 
    echo "PHP déjà installé"
fi
echo 

### Configuration des modules Apache2
config_apache

echo "Activation de la configuration PHP-FPM pour Apache2"
a2enconf php8.2-fpm
echo

### Mettre à jour le fichier /etc/apache2/sites-enabled/000-default.conf
echo "Configuration de /etc/apache2/sites-enabled/000-default.conf"
sed -i '/<FilesMatch \.php$>/,/<\/FilesMatch>/d' /etc/apache2/sites-enabled/000-default.conf
sed -i '/<\/VirtualHost>/i <FilesMatch \.php$>\n    SetHandler "proxy:unix:/var/run/php/php8.2-fpm.sock|fcgi://localhost/"\n</FilesMatch>' /etc/apache2/sites-enabled/000-default.conf
echo 

### Redémarrage et test d'Apache2
echo "Vérification de fonctionnement d'Apache2"
systemctl restart apache2
service_test 'apache2' '/etc/apache2/sites-enabled/000-default.conf'

echo
echo "Redémarrage apache2.service réussi"
echo

echo "Configuration PHP-FPM"
CAP_CONF=1
while [ $CAP_CONF -eq 1 ]; do
    config_php
    CAP_CONF=$?
    if [ $CAP_CONF -eq 1 ]; then
        retry_prompt
    fi
done
sleep 1
echo "Redémarrage du service php8.2-fpm"
systemctl restart php8.2-fpm
while [ $? -ne 0 ]; do
    echo "Erreur: Démarrage de service PHP-FPM échouée"
    echo "Veuillez vérifier la configuration php.ini"
    sleep 2
    vi /etc/php/8.2/fpm/php.ini
    systemctl restart php8.2-fpm 
    retry_prompt
done

### Modification du fichier /etc/apache2/conf-enabled/security.conf
sed -i 's/^ServerTokens.*/ServerTokens Prod/' /etc/apache2/conf-enabled/security.conf

### Supression du page web défaut Debian 
echo > /var/www/html/index.html
echo "Vérification de fonctionnement d'Apache2"
systemctl restart apache2
service_test 'apache2' '/etc/apache2/conf-enabled/security.conf'


## Configuration d'un VirtualHost
### Demander à l'utilisateur de fournir le ServerName
read -p "Veuillez entrer le ServerName (e.g., example.lan): " SERVERNAME

### Chemin du fichier de configuration
CONF_FILE="/etc/apache2/sites-available/${SERVERNAME}.conf"

### Créer le fichier de configuration avec le contenu spécifié
tee "$CONF_FILE" > /dev/null <<EOL
<VirtualHost *:80>
    ServerName $SERVERNAME
    ServerAdmin webmaster@$SERVERNAME
    DocumentRoot /var/www/$SERVERNAME/html
    ErrorLog \${APACHE_LOG_DIR}/${SERVERNAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${SERVERNAME}_access.log combined

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php8.2-fpm.sock|fcgi://localhost/"
    </FilesMatch>
</VirtualHost>
EOL

### Créer le répertoire DocumentRoot si ce n'est pas déjà fait
mkdir -p /var/www/$SERVERNAME/html

### Créer un fichier index.php avec un contenu plus beau
tee /var/www/$SERVERNAME/html/index.php > /dev/null <<EOL
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bienvenue sur $SERVERNAME</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f4;
            color: #333;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        .container {
            text-align: center;
            background-color: #fff;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        h1 {
            color: #007BFF;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Bienvenue sur $SERVERNAME</h1>
        <p>Ceci est la page par défaut de votre nouveau site web.</p>
        <p>Votre serveur est opérationnel et prêt à être utilisé.</p>
        <p>Pour plus d'informations, contactez <a href="https://www.linkedin.com/in/ariaceleste/">John Paul CELESTE</a>.</p>
    </div>
</body>
</html>
EOL

### Accorder les permissions nécessaires
chown -R www-data:www-data /var/www/$SERVERNAME
chmod -R 755 /var/www/$SERVERNAME

### Accorder les permissions au fichier index.php
chown www-data:www-data /var/www/$SERVERNAME/html/index.php

### Activer le virtual host
a2ensite "${SERVERNAME}.conf"

### Redémarrer Apache pour appliquer les modifications
echo "Vérification de fonctionnement d'Apache2"
systemctl restart apache2
service_test "apache2" "/var/www/$SERVERNAME/html/index.php"

echo
echo "Le virtual host pour $SERVERNAME a été configuré et activé avec succès."

### TODO: HTTPS, WordPress
# php8.2-fpm easy-rsa mariadb-server mariadb-client
