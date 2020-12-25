#!/usr/bin/env bash
#
# Disable user promt
read -p "What is the FQDN of the web server: "  wsname
echo "Adding Extra PHP and Nginx Repositories"
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:ondrej/nginx-mainline
echo "Updating APT Libraries..."
apt update -y -q
echo "Installing PHP..."
apt install -y -q php7.4-{cli,json,fpm,mysql,gd,soap,mbstring,bcmath,common,xml,curl}
apt install unzip -q -y
echo "Installing Nginx..."
apt install -y nginx -q
echo "Updating remaining libraries..."
apt dist-upgrade -y -q
echo "Installing composer"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
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

    include snippets/deny-git.conf;
    include snippets/deny-htaccess.conf;
    include snippets/deny-license-readme.conf;
    include snippets/deny-composer.conf;
    include snippets/add-headers.conf;

    access_log   /var/log/nginx/ssl.pallet.access.log combined;
    error_log    /var/log/nginx/ssl.pallet.error.log;
}
EOF

ln -s /etc/nginx/sites-available/lemp /etc/nginx/sites-enabled/lemp

# Disable external access to PHP-FPM scripts
sed -i "s/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.4/fpm/php.ini
service nginx restart
sudo apt install -y certbot python3-certbot-nginx
