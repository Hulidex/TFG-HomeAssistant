#!/bin/bash

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
# answer is affirmative or negative.
# ARGS: $1 is the question to ask, $2 is the command to
# execute if the answer is affirmative and $3 is the command to execute if the
# answer is negative. IMPORTANT the parameters must be strings. $2 and $3 are
# optional.
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
		if [ -n "$2" ]; then eval $2; fi
		break
		;;
	    "No")
		if [ -n "$3" ]; then eval $3; fi
		break
		;;
	    *) echo "Invalid option"
	esac
    done
}


# DESCRIPTION:  Check if a user exists in the system
# ARGS: $1 is the user name to look for.
# Returns Zero if the user exists or One otherwise.
check_user()
{
    getent passwd | grep -o "^$1" -q
    echo $?
}

# DESCRIPTION: Abort script execution displaying a message
# ARGS: $1: Message to be displayed before aborting.
# Returns Nothing
abort_script()
{
    echo $1
    exit 1
}

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
