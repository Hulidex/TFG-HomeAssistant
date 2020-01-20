#!/bin/bash 

# VARIABLES

DEBIAN_FRONTEND=noninteractive # Avoid apt package manager to ask for
			       # confirmation when installing a package or
			       # upgrading the system

# Functions

# DESCRIPTION: Look for an expression in a given file
# ARGS: $1 is the pattern to look for in the file path specified by $2
# Returns 0 if the expression is found or 1 otherwise
find_expr()
{
    grep -o "$1" "$2" -q
    echo $?
}

# DESCRIPTION: Make a yes/no question to the user and execute a command if
# answer is affirmative.
# ARGS: $1 is the question to ask, $2 is the command to execute
# Returns Nothing
make_question()
{
    echo -e $1
    options=("Yes" "No")
    PS3="Type an option number (1-${#options[@]})>> "
    select option in "${options[@]}"
    do
	case $option in
	    "Yes")
		eval $2
		break
		;;
	    "No")
		break
		;;
	    *) echo "Invalid option"
	esac
    done
}

check_user()
{
    getent passwd | grep -o "^$1" -q
    echo $?
}

# MAIN

# Abort if the user executing the script doesn't have root permissions
if [ ! $(id -u) -eq 0 ]
then
   echo "Sorry, but you need to execute this script with root permissions"
   exit 1
fi

INFO_MESSAGE="Before going any further this script is just compatible with
debian based Linux distributions but right now is only tested on Raspbian buster
lite for raspberry pi 3/4, if your system is different, run this script at your
own risk.\n\nThis installation is based on the following
guide:\n\nhttps://www.home-assistant.io/docs/installation/raspberry-pi/\n\nIf
everything run successfully, Home assistant will be installed on your system the
hard way, so you can control all by yourself but remember with great power comes
great responsibility, you will have to upgrade and install add-ons manually,
therefore, this script is make with the purpose of speed up the process of
setting up the machine, but after the installation you are alone."
QUESTION="Press any key to continue... or type 'n' if you want to quit >> "

echo -e "$INFO_MESSAGE"
read -n1 -r -p "$QUESTION" answer

if [ $answer = "n" ]  || [ $answer = "N" ];then
    echo -e "\nAborting"
    exit 1
fi

# # For security reasons change pi's password
# echo "Please for security reasons type a new password for the pi user" 
# passwd pi
# if [ ! $? -eq 0 ]
# then
#     echo "Aborting"
#     exit 1
# fi


# update and upgrade the system
apt update && apt upgrade

# Add to bashrc an environment variable to avoid issues with termite shells.
COMMAND="export TERM=xterm-color"
FILE="/etc/bash.bashrc"

if [ $(find_expr "$COMMAND" "$FILE") -eq 1 ]; then
   echo $COMMAND >> $FILE
   echo "Added environment variable named TERM with value 'xterm-color'"

fi

# Install neovim text editor.
COMMAND="apt install neovim"
make_question "Do you want to install Neo vim text editor?" "$COMMAND"

# Install Home assistant dependencies

echo "Home assistant dependencies will be installed on the system, please wait"
apt install python3 python3-dev python3-venv python3-pip libffi-dev libssl-dev

# Create Home assistant user
echo "Creating Home assistant user"
USER_NAME="homeassistant"
useradd -rm $USER_NAME -G dialout,gpio,i2c 2> /dev/null
if [ $(check_user "$USER_NAME") -eq 1 ]; then
    echo "Can't create user $USER_NAME, aborting"
    exit 1
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

# Run Home assistant for the first time, and finish installation
hass
EOF


PRIVATE_IP=$(ip route get 8.8.4.4 | head -1 | cut -d' ' -f7)
echo -e "Home assistant installed, check that
everything is OK by accessing with your browser to the following
address:\nhttp://$PRIVATE_IP:8123\nIf you have any question, please refer to
Home assistant official site:\nhttps://www.home-assistant.io/"
