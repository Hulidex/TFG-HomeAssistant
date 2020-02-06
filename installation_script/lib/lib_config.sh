#!/bin/bash
configure_raspi()
{
# For security reasons change pi's password
echo "Please for security reasons type a new password for the pi user" 
passwd pi
if [ ! $? -eq 0 ]
then
    echo "Aborting"
    exit 1
fi


# update and upgrade the system
apt update -y && apt upgrade -y

# Add to bashrc an environment variable to avoid issues with termite shells.
COMMAND="export TERM=xterm-color"
FILE="/etc/bash.bashrc"

if [ $(find_expr "$COMMAND" "$FILE") -eq 1 ]; then
   echo $COMMAND >> $FILE
   echo "Added environment variable named TERM with value 'xterm-color'"

fi

# Install neovim text editor.
COMMAND="apt install -y neovim"
make_question "Do you want to install Neo vim text editor?" "$COMMAND"
}
