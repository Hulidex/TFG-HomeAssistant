#!/bin/bash

# Functions

# DESCRIPTION: Abort script execution displaying a message
# ARGS: $1: Message to be displayed before aborting.
# Returns Nothing
abort_script()
{
    echo -e "$1"
    exit 1
}

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
		clear

		if [ -n "$2" ]; then eval $2; fi
		break
		;;
	    "No")
		clear

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

# DESCRIPTION: Check if the user executing the script is root
check_root()
{
    MESSAGE="Sorry, but you need to execute this script with root permissions"
    if [ ! $(id -u) -eq 0 ]; then
	abort_script "$MESSAGE"
    fi   
}

# DESCRIPTION: Check if the machine has a specific operating system
# ARGUMENTS: Use the first argument to indicate the operating system you want to
# fetch
# RETURNS: 0 if the machine has the given operating system and 1 otherwise
check_so()
{
    lsb_release -a | grep -qoi "$1" &> /dev/null
    echo $?
}

# DESCRIPTION: Check if a given user exists and then add it to group docker.
# Is an interactive function because it asks the user for the user name.
# ARGUMENTS: None
# RETURNS: Nothing
add_user_to_docker()
{
    while :; do
	echo "Type the name of the user who will run docker: "
	read -p ">> " USER_INPUT

	if [ $(check_user $USER_INPUT) -eq 0 ]; then
	    usermod -aG docker $USER_INPUT
	    break
	else
	    clear
	    echo "The user '$USER_INPUT' doesn't exist, please try again"
	fi
    done
}



# DESCRIPTION: Set a flag needed to install Home Assistant properly
# It ask the user for the specific flag.
# ARGUMENTS: None
# RETURNS: Nothing
set_hass_flag()
{
    SUPPORTED_FLAGS="intel-nuc
odroid-c2
odroid-n2
odroid-xu
qemuarm
qemuarm-64
qemux86
qemux86-64
raspberrypi
raspberrypi2
raspberrypi3
raspberrypi4
raspberrypi3-64
raspberrypi4-64
tinker"

    while :;do
	echo -e "Please type the flag for your machine"
	read -p ">> " HASS_FLAG
	echo -e "$SUPPORTED_FLAGS" | grep -qo $HASS_FLAG

	if [ $? -eq 0 ]; then
	    echo "Setting flag to '$HASS_FLAG'"
	    break
	else
	    clear
	    echo "The flag '$HASS_FLAG' doesn't exist, please try again"
	    echo -e "It must be one of the following list: \n$SUPPORTED_FLAGS"
	fi
    done
}
