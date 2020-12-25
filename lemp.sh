#!/usr/bin/env bash
#
clear
echo "This script will automate the installation of Nginx, PHP and MariaDB"
echo "It will ask you for fully qualified name (example.server.com) as well"
echo "your email address. The email address is simply used to register the"
echo "SSL Certificate against and also to notify you if the certificate fails"
echo "to renew every 90 days in an automated fashion"
echo
echo
echo "If you want to exit this script without continuing, please press CTRL-C"
echo
read -p "What is the FQDN of the web server: "  wsname
read -p "What is your email address: "  userem
echo "Adding Extra PHP and Nginx Repositories"
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:ondrej/nginx-mainline
echo "Updating APT Libraries..."
apt update -y -q
clear
echo "APT Libraries updated..."
echo "Installing PHP..."
sleep 2
apt install -y -q php7.4-{cli,json,fpm,mysql,gd,soap,mbstring,bcmath,common,xml,curl}
apt install unzip -q -y
clear
echo "PHP Installed Successfully."
echo "Installing Nginx..."
sleep 2
apt install -y nginx -q
clear
echo "Nginx installed."
echo "Installing MariaDB..."
sleep 2
apt install mariadb-server -y
clear
echo "MariaDB Installed successfully."
echo "Updating remaining libraries..."
sleep 2
apt dist-upgrade -y -q
clear
echo "Server updated."
echo "Installing composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
rmdir /var/www/html
mkdir /var/www/lemp
chown -R www-data:www-data /var/www/lemp
rm /etc/nginx/sites-enabled/default
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
mkdir -p /etc/nginx/snippets.d
tee -a /etc/nginx/snippets.d/deny-git.conf <<EOF
location ~ /\.git {
	deny all;
}
EOF
tee -a /etc/nginx/snippets.d/deny-composer.conf <<EOF
location ~ /vendor/\.cache {
	deny all;
}

location ~ /(composer.json|composer.lock) {
	deny all;
}
EOF
tee -a /etc/nginx/snippets.d/deny-htaccess.conf <<EOF
location ~ /\.ht {
	deny all;
}
EOF
tee -a /etc/nginx/snippets.d/deny-license-readme.conf <<EOF
location ~ /(LICENSE.md|README.md) {
	deny all;
}
EOF
tee -a /etc/nginx/snippets.d/add-headers.conf <<EOF
server_tokens off;
add_header X-Frame-Options SAMEORIGIN;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF
tee -a /etc/nginx/sites-available/lemp <<EOF
server {
    server_name $wsname;
    root /var/www/lemp;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \\.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    }

    error_page  404 /;

    include snippets.d/deny-git.conf;
    include snippets.d/deny-htaccess.conf;
    include snippets.d/deny-license-readme.conf;
    include snippets.d/deny-composer.conf;
    include snippets.d/add-headers.conf;

    access_log   /var/log/nginx/ssl.pallet.access.log combined;
    error_log    /var/log/nginx/ssl.pallet.error.log;
}
EOF

ln -s /etc/nginx/sites-available/lemp /etc/nginx/sites-enabled/lemp

# Disable external access to PHP-FPM scripts
sed -i "s/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.4/fpm/php.ini
service nginx restart
service php7.4-fpm restart
sudo apt install -y certbot python3-certbot-nginx
apt autoremove -y
echo "If everything went correct you should be able to visit https://$website"
