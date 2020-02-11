#!/bin/bash

source lib/lib_common.sh
source lib/lib_config.sh

# MAIN

# Abort if the user executing the script doesn't have root permissions
check_root

INFO_MESSAGE="Before going any further this script is just compatible with
debian based Linux distributions but right now is only tested on Raspbian buster
lite for raspberry pi 4, if your system is different, run this script at your
own risk.\n\nThis installation is based on the following
guide:\n\nhttps://www.home-assistant.io/hassio/installation/#alternative-install-on-a-generic-linux-host\n\nIf
everything run successfully, Home assistant will be installed on your system the
hard way, so you can control all by yourself but remember with great power comes
great responsibility,therefore, this script is make with the purpose of speed
up the process of setting up the machine, but after the installation you are at
your own."
QUESTION="Do you want to continue?"

echo -e "$INFO_MESSAGE"
make_question "$QUESTION" 'echo "Continuing..."' 'abort_script "Aborting"'

QUESTION="If you are installing Home assistant on a Raspberry Pi 3/4 and you
didn't configure your system yet, Do you want to configure it?
WARNING: Respond yes only if you are using a raspberry pi 3/4,
other Debian based systems must answer no."
make_question "$QUESTION" "configure_raspi"

# Install Home assistant and Docker CE dependencies
echo "Home assistant dependencies will be installed on the system, please wait"
apt install -y software-properties-common 
apt update -y
PKG="apparmor-utils apt-transport-https avahi-daemon ca-certificates curl dbus jq socat network-manager gnupg2"
apt install -y $PKG

# Disable modemmanager package to avoid issues with Z-Wave and Zig-bee
systemctl disable ModemManager

# Install docker CE
echo "Installing Docker CE..."

curl -fsSL get.docker.com -o get-docker.sh
sh get-docker.sh
if [ $? -gt 0 ]; then
    rm get-docker.sh
    abort_script "Can't install docker, Aborting..."
fi
rm get-docker.sh


echo "Docker CE installed"
# Add user to group docker to use it as non-root user
QUESTION="Docker will work only for the root user, Do you want other user to use it?"
make_question "$QUESTION" "add_user_to_docker"

# Enable docker at boot
systemctl enable docker

#Install Home-Assistant
QUESTION="Now Home assistant is ready to be installed, but depending on the
machine, a flag is needed for it proper installation. check the following list:
https://github.com/home-assistant/hassio-installer#supported-machine-types
Does your machine appear on that list?"
make_question "$QUESTION" "set_hass_flag"

echo "Installing Home Assistant"

HASS_URL="https://raw.githubusercontent.com/home-assistant/hassio-installer/master/hassio_install.sh"
if [ -n "$HASS_FLAG" ]; then
    curl -sL "$HASS_URL" | bash -s -- -m "$HASS_FLAG"
else
    curl -sL "$HASS_URL" | bash -s
fi
