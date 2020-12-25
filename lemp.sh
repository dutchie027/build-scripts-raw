#!/usr/bin/env bash
#
# Disable user promt
read -p "What is the FQDN of the web server: "  wsname
echo "Adding Extra PHP and Nginx Repositories"
add-apt-repository -y -q ppa:ondrej/php
add-apt-repository -y -q ppa:ondrej/nginx-mainline
echo "Updating APT Libraries..."
apt update -y -q
echo "Installing PHP..."
apt install -y -q php7.4-{cli,json,fpm,mysql,gd,soap,mbstring,bcmath,common,xml,curl}
apt install unzip -q -y
echo "Installing Nginx..."
apt install -y -q nginx
echo "Updating remaining libraries..."
apt dist-upgrade -y -q
echo "Installing composer"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
rm /etc/nginx/sites-available/default
tee -a /etc/nginx/sites-available/no-site <<EOF
# If a client requests for an unknown server name and there's no default server
# name defined, Nginx will serve the first server configuration found. To
# prevent this, we have to define a default server name and drop the request.
server {
    listen 80 default_server deferred;
    listen [::]:80 default_server deferred;
    server_name _;

    # Return 444 (No Response)
    return 444;
}
EOF
ln -s /etc/nginx/sites-available/no-site /etc/nginx/sites-enabled/no-site
# Disable external access to PHP-FPM scripts
sed -i "s/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.4/fpm/php.ini
service nginx restart
