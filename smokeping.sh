#!/usr/bin/env bash
#
clear
echo "This script will automate the installation of Nginx and SmokePing"
echo "It will ask you for fully qualified name (example.server.com) as well"
echo "your email address. The email address is simply used to register the"
echo "SSL Certificate against and also to notify you if the certificate fails"
echo "to renew every 90 days in an automated fashion"
echo
echo "If you want to exit this script without continuing, please press CTRL-C"
echo
read -p "What is the FQDN of the web server: "  wsname
read -p "What is your email address: "  userem

# TODO: Grab some user information as well as possibly
# grabbing the hostname or even using wsname
# and populating the default Targets
# and changing the config with sed
#
#read -p "What is your First and Last Name: " flname
#
#
#

apt update -y
apt dist-upgrade -y
apt install nginx -y
apt install fcgiwrap -y
apt install smokeping -y
cp /usr/share/doc/fcgiwrap/examples/nginx.conf /etc/nginx/fcgiwrap.conf
tee -a /etc/nginx/sites-available/smokeping <<EOF
server {
        listen 80;
        listen [::]:80;
        server_name $wsname;

        location = /smokeping/smokeping.cgi {
                fastcgi_intercept_errors on;

                fastcgi_param   SCRIPT_FILENAME         /usr/lib/cgi-bin/smokeping.cgi;
                fastcgi_param   QUERY_STRING            \$query_string;
                fastcgi_param   REQUEST_METHOD          \$request_method;
                fastcgi_param   CONTENT_TYPE            \$content_type;
                fastcgi_param   CONTENT_LENGTH          \$content_length;
                fastcgi_param   REQUEST_URI             \$request_uri;
                fastcgi_param   DOCUMENT_URI            \$document_uri;
                fastcgi_param   DOCUMENT_ROOT           \$document_root;
                fastcgi_param   SERVER_PROTOCOL         \$server_protocol;
                fastcgi_param   GATEWAY_INTERFACE       CGI/1.1;
                fastcgi_param   SERVER_SOFTWARE         nginx/$nginx_version;
                fastcgi_param   REMOTE_ADDR             \$remote_addr;
                fastcgi_param   REMOTE_PORT             \$remote_port;
                fastcgi_param   SERVER_ADDR             \$server_addr;
                fastcgi_param   SERVER_PORT             \$server_port;
                fastcgi_param   SERVER_NAME             \$server_name;
                fastcgi_param   HTTPS                   \$https if_not_empty;

                fastcgi_pass unix:/var/run/fcgiwrap.socket;
        }

        location ^~ /smokeping/ {
                alias /usr/share/smokeping/www/;
                index smokeping.cgi;
                gzip off;
        }

        location / {
                return 301 http://\$server_name/smokeping/smokeping.cgi;
        }
}
EOF
ln -s /etc/nginx/sites-available/smokeping /etc/nginx/sites-enabled/smokeping
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
service nginx restart
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx --redirect -d $wsname -m $userem --agree-tos -n
apt autoremove -y
clear
echo "If everything went correct you should be able to visit https://$wsname"
echo "There is a redirect in place that will take you to the default SmokePing"
echo "page and show you the graphs"
