#!/bin/bash

# DESCRIPTION: Check if a list of packages are installed on the system
# ARGS: As many as packages
# Returns: Nothing, if a package on the list isn't on the list the script is
# aborted.
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

# DESCRIPTION: Check if a block device exists, if it exists initialize
# 'SELECTED_DEVICE' variable, otherwise it tells the user that the device
# doesn't exist and ask they to insert the name of the block
# device they want to format again and again until they introduce a
# valid one or they type 'no' and then the script aborts.
# ARGS: None
# Returns: Nothing
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

	if ! [ -e "/dev/$USER_INPUT" ]; then
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


# DESCRIPTION: This function tries to detect a block device which was inserted by
# the user. For being able to detect the device are necessary two phases, The
# first face scan all the computer's device blocks and store them, then the
# second phase where the user physically insert the desired device and another
# scan is made to guess which is the inserted device.
# If a new device can't be found the function 'read_blkdev' is executed,
# otherwise the variable 'SELECTED_DEVICE' is initialized.
# ARGS: None
# Returns: Nothing
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

	if ! [ -e "/dev/$SD_CARD" ]; then
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

# DESCRIPTION: Download and extract a valid Raspbian-buster image into /tmp
# folder, and initialize 'IMAGE' variable.
# ARGS: None
# Returns: Nothing
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

# DESCRIPTION: Initialize 'IMAGE' variable with a custom raspbian-buster image
# given by the user. This function doesn't check if it is a valid image,
# only that the image is an existing file.
# Note: this function has a similar behaviour than the function 'read_blkdev'
# in the way of checking if the image exists and asking the user.
# ARGS: None
# Returns: Nothing
select_image_from_folder()
{
   MESSAGE="Please type an ABSOLUTE path to the image, verify that the image is a valid raspbian buster image before doing anything, otherwise the SD card
may get corrupted or broken"

    echo -e "$MESSAGE"

    EXIT_FLAG=1
    while [ $EXIT_FLAG -eq 1 ]; do
	read USER_INPUT

	if [ $USER_INPUT = "no" ]; then abort_script "Aborting"; fi

	if ! [ -e "$USER_INPUT" ]; then
	    EXIT_FLAG=1
	    echo -e "ERROR file '$USER_INPUT' doesn't exist please try again..."
	    echo -e "$MESSAGE"
	else
	    EXIT_FLAG=0
	    IMAGE="$USER_INPUT"
	    MESSAGE="You selected the given image '$IMAGE', are you sure?"
	    make_question "$MESSAGE" 'echo "Continuing"' 'abort_script "Aborting"'
	fi
    done
}


# DESCRIPTION: Wipe all partitions in the device stored in the previous defined
# 'SELECTED_DEVICE' variable.
# The wipe is done by creating a new GPT table in the device.
# ARGS: None
# Returns: Nothing
format_sd()
{
    fdisk $SELECTED_DEVICE << EOF
g
w
EOF
}


# DESCRIPTION: It performs a low level operation which truly wipes all the
# device data. It needs 'SELECTED_DEVICE' variable previous defined.
# ARGS: None
# Returns: Nothing
write_zeros()
{
    pv < /dev/zero > $SELECTED_DEVICE 2> /dev/null
}

# DESCRIPTION: Burns the image which path is stored in 'IMAGE' variable into
# the block device stored in 'SELECTED_DEVICE' variable.
# ARGS: None
# Returns: Nothing
burn_image()
{
    pv < $IMAGE > $SELECTED_DEVICE
}


# DESCRIPTION: This function enables the ssh-service for the raspberry, for
# doing so, we have to mount the boot partition created on the formatted and burned
# block device and create there a file with name 'ssh'. (This way of doing
# things is extracted from the official raspberry site)
# ARGS: None
# Returns: Nothing
enable_rasp_ssh()
{
    #Look for boot partion
    blockdev=$(lsblk -J | jq ".blockdevices[0] | .name" | sed 's/"//g')
    count=0
    while [ "$blockdev" != "null" ] && [ $count -lt 500 ]; do  # Second condition avoid infinite loops
	echo "$SELECTED_DEVICE" | grep -oq "$blockdev"
	if [ $? -eq 0 ]; then
	    sd_boot_part=$(lsblk -J | jq ".blockdevices[$count].children[0].name" | sed 's/"//g')
	    if [ "$sd_boot_part" = "null" ]; then
		MESSAGE="Something went wrong when the image was burned, and
the boot partition couldn't be found, Is the image broken or corrupted?"
		abort_script "$MESSAGE"
	    fi
	fi


	((count++))
	blockdev=$(lsblk -J | jq ".blockdevices[$count] | .name" | sed 's/"//g')
    done

    if [ -z "$sd_boot_part" ]; then
	MESSAGE="Something went wrong detecting partitions associated with device
$SELECTED_DEVICE, abort_scripting"
	abort_script "$MESSAGE"
    fi

    # Mount boot partition
    mount_dir="/run/media/boot_partition"
    mkdir -p $mount_dir
    echo "Mounting sd boot partition..."
    mount "/dev/$sd_boot_part" $mount_dir
    if [ $? -gt 0 ]; then
	abort_script "Can't mount boot partition aborting..."
    fi

    # Create ssh file into boot partition to enable ssh-service in raspberry
    echo "Activating ssh service by creating 'ssh' file..."
    file="$mount_dir/ssh"
    touch $file
    if ! [ -e $file ]; then
	abort_script "Can't create ssh file into boot partition aborting"
    fi

    sync

    # Unmount partition
    echo "Unmounting boot partition..."
    umount $mount_dir
    if [ $? -gt 0 ]; then
	MESSAGE="Can't unmount sd boot partition, but the installation was
correct, unmount it manually and everything should be fine."
	echo -e "$MESSAGE"
    fi
}
