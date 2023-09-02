#!/bin/sh

set -e

DOMAIN_NAME=$1

if [ -z "${DOMAIN_NAME}" ]
then
  echo "Missing domain name."
  exit -1
fi

read -p "Using ${DOMAIN_NAME} as domain name, are you sure (N/y)? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  echo "ABORTED."
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

sudo apt-get update
sudo apt-get install apt-transport-https
wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
sudo apt-get update
sudo apt-get install dart
echo 'vm.swappiness = 5' | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl --system
sudo apt-get install npm -y
sudo npm install -g sass

# nginx setup
sudo apt-get instll nginx python3-certbot-nginx
cat nginx.conf | sudo tee /etc/nginx/sites-enabled/dungeonclub.conf
sudo certbot --nginx -d $DOMAIN_NAME
sudo systemctl reload nginx
sudo ufw disable
