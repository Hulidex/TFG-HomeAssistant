#!/bin/bash

# First source lib_common.sh and them this file, otherwise anything will work
# correctly...

check_packages()
{
    arr=("$@")
    for package in ${arr[*]}; do
	which $package &> /dev/null 
	if [ $? -eq 1 ]; then
	    abort_script "Needed package '$package' but not found, please install it"
	fi
    done
}


check_file_exists()
{
    ls -1 "$1" | grep -o -q "^$2\$" &> /dev/null
    echo $?
}


read_blkdev()
{
    MESSAGE="Type the SD's card block device name, Example: if the
device is '/dev/mmcblk0' you only have to type its name 'mmcblk0'.
Type 'no' if you want to quit the script without making any changes."

    echo -e "$MESSAGE"

    EXIT_FLAG=1
    while [ $EXIT_FLAG -eq 1 ]; do
	read USER_INPUT

	if [ $USER_INPUT = "no" ]; then abort_script "Aborting"; fi

	if [ $(check_file_exists "/dev" "$USER_INPUT") -eq 1 ]; then
	    EXIT_FLAG=1
	    echo -e "ERROR block device with name '$USER_INPUT' doesn't exist
please try again..."
	    echo -e "$MESSAGE"
	else
	    EXIT_FLAG=0
	    SELECTED_DEVICE="/dev/$USER_INPUT"
	    MESSAGE="You selected '$SELECTED_DEVICE' block device, if you
continue, all data in that device will be lost, Are you sure?"
	    make_question "$MESSAGE" 'echo "You selected $SELECTED_DEVICE"' 'abort_script "Aborting"'
	fi
    done
}

detect_sd()
{
    sleep 2

    # Capture all system's block devices without the SD card
    BLOCK_DEVICES0=$(lsblk -J | jq '.blockdevices[] | .name')

    INFO_MESSAGE="Now insert your SD card, and choose option "yes", the script will
try to identify it."
    echo -e "$INFO_MESSAGE"
    make_question "$QUESTION" 'echo "Continuing"' 'abort_script "Aborting"'
    
    sleep 2 # Pause the script 2 seconds and give the system time to detect SD

    
    # Capture all system's block devices when SD card is inserted
    BLOCK_DEVICES1=$(lsblk -J | jq '.blockdevices[] | .name')

    # Make the intersection to get SD card block name
    SD_CARD=$(echo -e "$BLOCK_DEVICES1" | grep -v "$BLOCK_DEVICES0" | head -n 1 | sed 's/[" ]//g')

    ERROR_MESSAGE="For some reason the script can't recognize your SD card, if
your SD card is correctly inserted and you know which block device is
mapping it, insert now the name of that device (devices blocks have
the form '/dev/X' where 'X' is the device's name for example
'/dev/mmcblk0'):"
    
    if [ -z "$SD_CARD" ]; then
	echo -e $ERROR_MESSAGE
	read_blkdev
    else

	if [ $(check_file_exists "/dev" "$SD_CARD") -eq 1 ]; then
	    echo -e $ERROR_MESSAGE
	    read_blkdev
	else
	    SELECTED_DEVICE="/dev/$SD_CARD"
	    SUCCESS_MESSAGE="It seems like the script found the recently inserted
SD card, and seems like it's mapped to the following block device:
'$SELECTED_DEVICE'. Is this correct? (WARNING, if your decision is 
wrong you could lose your data or broke the system)"

	    make_question "$SUCCESS_MESSAGE" 'echo "You selected $SELECTED_DEVICE"' 'read_blkdev'
	fi
    fi
}

download_image()
{
    URL="https://downloads.raspberrypi.org/raspbian_lite_latest"
    LOCATION="/tmp/raspbian_buster_lite.zip"
    echo "Downloading latest raspbian lite image..."
    curl -L -# $URL > $LOCATION

    echo "Extracting image"
    IMAGE_FOLDER="/tmp/rasp-image"
    mkdir $IMAGE_FOLDER
    unzip -jq $LOCATION -d $IMAGE_FOLDER
    IMAGE_NAME=$(ls $IMAGE_FOLDER | grep -o ".*\.img")
    if [ -z "$IMAGE_NAME" ]; then
	MESSAGE="Something went wrong downloading or extracting the image.
please, download and extract the image manually, check Raspberry pi official
site: https://www.raspberrypi.org/downloads/raspbian/"
	abort_script "$MESSAGE"
    fi

    IMAGE="$IMAGE_FOLDER/$IMAGE_NAME"
    QUESTION="The image was downloaded and extracted producing a file at $IMAGE
with the following sha256sum:

$(sha256sum $LOCATION)

please, don't forget to compare it with the ones given in the following link:
https://www.raspberrypi.org/downloads/raspbian/\nDo you want to continue?"

    make_question "$QUESTION" 'echo "Continuing"' 'abort_script "Aborting"'
}

select_image_from_folder()
{
   MESSAGE="Please type an ABSOLUTE path to the image, verify that the image
is a valid raspbian buster image before doing anything, otherwise the SD card
may get corrupted or broken"

    echo -e "$MESSAGE"

    EXIT_FLAG=1
    while [ $EXIT_FLAG -eq 1 ]; do
	read USER_INPUT

	if [ $USER_INPUT = "no" ]; then abort_script "Aborting"; fi

	IMAGE_NAME=$(echo "$USER_INPUT" | sed -r 's/(^.*)\/(.*$)/\2/')
	IMAGE_FOLDER=$(echo "$USER_INPUT" | sed -r 's/(^.*)\/(.*$)/\1/')

	if [ $(check_file_exists "$IMAGE_FOLDER" "$IMAGE_NAME") -eq 1 ]; then
	    EXIT_FLAG=1
	    echo -e "ERROR file '$IMAGE_NAME' doesn't exist under '$IMAGE_FOLDER'
please try again..."
	    echo -e "$MESSAGE"
	else
	    EXIT_FLAG=0
	    IMAGE="$USER_INPUT"
	    MESSAGE="You selected the given image '$IMAGE', are you sure?"
	    make_question "$MESSAGE" 'echo "Continuing"' 'abort_script "Aborting"'
	fi
    done
}
