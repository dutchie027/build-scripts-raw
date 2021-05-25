#!/usr/bin/env bash
#
clear
echo "This script will automate the installation of PHP and Asterisk 18"
echo "It is 99% automated with the exception on one prompt which will "
echo "ask you for the dial code of the country you are in"
echo
echo "If you want to exit this script without continuing, please press CTRL-C"
echo
read -p "Hit Enter to Continue..."  wsname
echo "Adding Extra PHP and Nginx Repositories"
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:ondrej/nginx-mainline
echo "Updating APT Libraries..."
apt update -y -q
clear
echo "APT Libraries updated..."
echo "Installing PHP..."
sleep 2
apt install -y -q php-{cli,json,fpm,mysql,gd,soap,mbstring,bcmath,common,xml,curl,imagick,zip}
apt install unzip -q -y
clear
echo "PHP Installed Successfully."
sleep 2
echo "Installing composer..."
sleep 2
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
clear
echo "Composer Successfully Installed"
echo
apt install wget build-essential git autoconf subversion pkg-config libtool -q -y
echo "Composer Successfully Installed"
echo
apt dist-upgrade -y -q
clear
echo "Server updated."
sleep 2
echo "Installing DAHDI Linux"
sleep 2
cd /usr/src/
git clone -b next git://git.asterisk.org/dahdi/linux dahdi-linux
cd dahdi-linux
make
make install
clear
echo "DAHDI Installed Successfully"
sleep 2
echo "Installing DAHDI Tools"
sleep 2
cd /usr/src/
git clone -b next git://git.asterisk.org/dahdi/tools dahdi-tools
cd dahdi-tools
autoreconf -i
./configure
make install
make install-config
dahdi_genconf modules
clear
echo "DAHDI Installed Successfully"
sleep 2
echo "Installing Lib PRI"
sleep 2
cd /usr/src/
git clone https://gerrit.asterisk.org/libpri libpri
cd libpri
make
make install
clear
echo "Lib PRI Installed Successfully"
sleep 2
echo "Here comes Asterisk..."
sleep 2
cd /usr/src/
git clone -b 18 https://gerrit.asterisk.org/asterisk asterisk-18
cd asterisk-18/
contrib/scripts/get_mp3_source.sh
contrib/scripts/install_prereq install
./configure
make menuselect.makeopts
menuselect/menuselect --enable format_mp3
make
make install WGET_EXTRA_ARGS="--no-verbose"
make config
make basic-pbx
adduser --system --group --home /var/lib/asterisk --no-create-home --gecos "Asterisk PBX" asterisk
sed -i "s~^#AST_USER=*~AST_USER=~" /etc/default/asterisk
sed -i "s~^#AST_GROUP=*~AST_GROUP=~" /etc/default/asterisk
usermod -a -G dialout,audio asterisk
chown -R asterisk: /var/{lib,log,run,spool}/asterisk /usr/lib/asterisk /etc/asterisk
chmod -R 750 /var/{lib,log,run,spool}/asterisk /usr/lib/asterisk /etc/asterisk
systemctl enable asterisk
clear
echo
echo "Asterisk Installed Successfull"
sleep 2
echo "Updating all remaining system data then i'm going to reboot"
apt update -y && apt dist-upgrade -y && apt autoremove -y
clear
echo
echo "Server updated and ready to use. I suggest a reboot first"
echo
