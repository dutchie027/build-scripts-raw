# build-scripts-raw
---
## To build an Asterisk 18 host simply run:

    # source <(curl -s https://raw.githubusercontent.com/dutchie027/build-scripts-raw/main/a18.sh)
---
## To build a Smokeping host simlpy run:

    # source <(curl -s https://raw.githubusercontent.com/dutchie027/build-scripts-raw/main/smokeping.sh)
---
## To build a LEMP host simply run:

    # source <(curl -s https://raw.githubusercontent.com/dutchie027/build-scripts-raw/main/lemp.sh)

## Prerequisites

- You need to have an A record set up for the name of the host you intend to use

## Running the Script

When you run the script it will ask you two questions:
- The FQDN of the host you intend to make the server (i.e. demo.example.com)
- An email address to associate with the SSL Certification Registration

After providing the two above values the script will:

- Install PHP 8.0
  - cli
  - json
  - fpm
  - mysql
  - gd
  - soap
  - mbstring
  - bcmath
  - common
  - xml
  - curl
  - zip
- Nginx
- It will remove the `default` site link `/etc/nginx/sites-enabled/default`
- It will create a site that 444's any requests not destined for `demo.example.com` (whatever you set it to)
- It will create a `lemp` user
- It will remove `/var/www/html`
- It will create `/var/www/lemp`
- It will create a `/etc/nginx/snippets.d` directory and put the following files in it (which are later linked)
  - deny-git.conf
  - deny-htaccess.conf
  - deny-license-readme.conf
  - deny-composer.conf
  - add-headers.conf
- It will install the latest version of composer
- It will create and link a `lemp` site configuration in `/etc/nginx/sites-available/lemp` and link it to `/etc/nginx/sites-enabled/lemp`
- It will change the PHP8.0-FPM thread to use the `lemp` user
- It will change the PHP8.0-FPM pool name to `lemp`
- It will change the PHP-FPM Pool to be Dynamic
- It will create an index.php with phpinfo()
- It will request an SSL cert for `demo.example.com` and associate it and redirect all HTTP requests to HTTPS
- It will redirect any 404s to the root of the web server
