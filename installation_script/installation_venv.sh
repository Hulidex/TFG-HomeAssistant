# Author: Jose Luis Izquierdo
# Description: This is script is made for installing
# HASS (Home assistant) using venv method, optionally you can configure a
# raspberry pi3/4 before installing anything

#!/bin/bash 
source ./lib/lib_common.sh
source ./lib/lib_config.sh

# MAIN

# Abort if the user executing the script doesn't have root permissions
check_root

INFO_MESSAGE="Before going any further this script is just compatible with
debian based Linux distributions but right now is only tested on Raspbian buster
lite for raspberry pi 3/4, if your system is different, run this script at your
own risk.\n\nThis installation is based on the following
guide:\n\nhttps://www.home-assistant.io/docs/installation/raspberry-pi/\n\nIf
everything run successfully, Home assistant will be installed on your system the
hard way, so you can control all by yourself but remember with great power comes
great responsibility, you will have to upgrade and install add-ons manually,
therefore, this script is make with the purpose of speed up the process of
setting up the machine, but after the installation you are at your own."
QUESTION="Do you want to continue?"

echo -e "$INFO_MESSAGE"
make_question "$QUESTION" 'echo "Continuing..."' 'abort_script "Aborting"'

QUESTION="If you are installing Home assistant on a Raspberry Pi 3/4 and you
didn't configure your system yet, this script will do it. Do you want to
configure it? WARNING: Respond yes only if you are using a raspberry pi 3/4,
other Debian based systems must answer no."
make_question "$QUESTION" "configure_raspi"

# Install Home assistant dependencies

echo "Home assistant dependencies will be installed on the system, please wait"
apt install -y python3 python3-dev python3-venv python3-pip libffi-dev libssl-dev

# Create Home assistant user
echo "Creating Home assistant user"
USER_NAME="homeassistant"
useradd -rm $USER_NAME -G dialout,gpio,i2c 2> /dev/null
if [ $(check_user "$USER_NAME") -eq 1 ]; then
    abort_script "Can't create user $USER_NAME, aborting" 
fi

# The proper Linux directory for contain site-specific data which is served by
# the system is /srv, so we are going to create a folder on that directory for
# the installation of Home Assistant.
cd /srv
mkdir $USER_NAME # Create folder with the same name that the user
chown "$USER_NAME:$USER_NAME" $USER_NAME # Give it proper permissions

# Now we need to run some commands as Home assistant's user
su $USER_NAME <<EOF

# Create the virtual environment to make sure that Python installation and Home
# Assistant installation won't impact one another.
cd "/srv/$USER_NAME"
python3 -m venv .
source bin/activate

# Install some required python packages 
python3 -m pip install wheel

# Now we can install Home assistant
pip3 install homeassistant


EOF

# Create a service to auto-initialize Home assistant at server's boot time
SERVICE_NAME="home-assistant"
cat << EOSU > "/etc/systemd/system/$SERVICE_NAME@$USER_NAME.service"
[Unit]
Description=Home Assistant
After=network-online.target

[Service]
Type=simple
User=%i
ExecStart=/srv/homeassistant/bin/hass -c "/home/%i/.homeassistant"

[Install]
WantedBy=multi-user.target
EOSU

# Reload systemd daemon
systemctl --system daemon-reload

# Enable Home assistant service
systemctl enable $SERVICE_NAME@$USER_NAME.service

# Start Home assistant
systemctl start $SERVICE_NAME@$USER_NAME.service

PRIVATE_IP=$(ip route get 8.8.4.4 | head -1 | cut -d' ' -f7)
echo -e "Home assistant installed, check that
everything is OK by accessing with your browser to the following
address:\nhttp://$PRIVATE_IP:8123\nIf you have any question, please refer to
Home assistant official site:\nhttps://www.home-assistant.io/"
