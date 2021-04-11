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

# lets take the "wsname" var and make sure it actually works
resolvedIP=$(nslookup "$wsname" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
[[ -z "$resolvedIP" ]] && echo "$wsname" lookup failure && exit || echo "$wsname" resolved to "$resolvedIP"

# now lets check to make sure the email address entered is valud
regex="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"
if [[ $userem =~ ${regex} ]]; then
  echo "Valid email...continuing"
else
  echo "$userem is not a valid email"
  exit
fi

echo "Adding Extra PHP and Nginx Repositories"
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:ondrej/nginx-mainline
echo "Updating APT Libraries..."
apt update -y -q
clear
echo "APT Libraries updated..."
echo "Installing PHP..."
sleep 2
apt install -y -q php-{cli,json,fpm,mysql,gd,soap,mbstring,bcmath,common,xml,curl,imagick}
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
sleep 2
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
clear
echo "Composer Successfully Installed"
echo
echo "Cleaning Up Directories..."
sleep 2
rmdir /var/www/html
mkdir /var/www/lemp
rm /etc/nginx/sites-enabled/default
clear
echo "Directories cleaned and new ones created."
echo "Creating supplemental files"
sleep 2
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
tee -a /etc/nginx/snippets.d/deny-env.conf <<EOF
location ~ /\.env {
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
    	try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \\.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm-lemp.sock;
    }

    error_page  404 /;

    include snippets.d/deny-git.conf;
    include snippets.d/deny-htaccess.conf;
    include snippets.d/deny-env.conf;
    include snippets.d/deny-license-readme.conf;
    include snippets.d/deny-composer.conf;
    include snippets.d/add-headers.conf;

    access_log   /var/log/nginx/ssl.$wsname.access.log combined;
    error_log    /var/log/nginx/ssl.$wsname.error.log;
}
EOF
tee -a /var/www/lemp/index.php <<EOF
<?php
phpinfo();
EOF
chown -R lemp:lemp /var/www/lemp
clear
echo "Supplemental files created"
echo "Linking Sites..."
sleep 2
ln -s /etc/nginx/sites-available/lemp /etc/nginx/sites-enabled/lemp
# Disable external access to PHP-FPM scripts
sed -i "s/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.4/fpm/php.ini
useradd lemp
usermod -a -G lemp www-data
ram=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
free=$(((ram/1024)-128-256-8))
php=$(((free/32)))
children=$(printf %.0f $php)
sed -i "s/^\[www\]/\[lemp\]/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^user = www-data/user = lemp/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^group = www-data/group = lemp/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/php7\.4\-fpm\.sock/php7\.4\-fpm\-lemp\.sock/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^pm = dynamic/pm = ondemand/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^;pm.process_idle_timeout = 10s;/pm.process_idle_timeout = 10s/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^;pm.max_requests = 500/pm.max_requests = 500/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^pm.max_children = .*/pm.max_children = $children/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^pm.start_servers = .*/;pm.start_servers = 5/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^pm.min_spare_servers = .*/;pm.min_spare_servers = 2/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/^pm.max_spare_servers = .*/;pm.max_spare_servers = 2/" /etc/php/7.4/fpm/pool.d/www.conf
mv /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/lemp.conf
echo "Restarting Nginx"
service nginx restart
echo "Restarting PHP FPM"
service php7.4-fpm restart
echo "Installing Certbot"
sleep 2
sudo apt install -y certbot python3-certbot-nginx
apt autoremove -y
certbot --nginx --redirect -d $wsname -m $userem --agree-tos -n
clear
echo "If everything went correct you should be able to visit https://$wsname"
echo "There is a default index.php created in the web root"
echo "The web root is: /var/www/lemp"
echo "The user that runs everything is: lemp"
echo "MariaDB has also been installed but is using the default configuration"
echo "You should run mysql_secure_installation and finalize the configuration"
echo "of MariaDB"
