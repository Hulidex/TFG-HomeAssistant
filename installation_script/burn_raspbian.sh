# Author: Jose Luis Izquierdo
# Description: Script to automatically format a SD card and burn Raspian-lite
# on it.

#!/bin/bash

source ./lib/lib_common.sh
source ./lib/lib_sd.sh

# VARS
NEEDED_PACKAGES="pv jq curl unzip"

# MAIN

# Aborts script if the user executing the script doesn't have root permissions
check_root

# Aborts script if one needed package is missing on the system.
check_packages $NEEDED_PACKAGES

# Show an information message
INFO_MESSAGE="This script is meant to format an SD card and burn
raspbian-buster's image on it, please, be careful, you need to select your SD
device, if you select another by mistake, you will lose all the data on that
device and maybe you could break your operating system. PLEASE MAKE SURE THAT
YOU ARE SELECTING THE PROPER DEVICE, I WILL NOT TAKE ANY RESPONSIBILITY FOR YOU
BREAKING YOUR SYSTEM OR LOSING DATA."
QUESTION="Do you want to continue?"

echo -e "$INFO_MESSAGE"
make_question "$QUESTION" 'echo "Continuing"' 'abort_script "Aborting"'

# Try to detect SD card
INFO_MESSAGE="For avoiding mistakes the script will try to auto recognize your
SD card, please if you had already inserted the SD card REMOVE IT NOW from the
system and select "yes" option (if you select "no" the script will abort)."

echo -e "$INFO_MESSAGE"
make_question "$QUESTION" 'detect_sd' 'abort_script "Aborting"'

# Select an image to burn on the SD card
QUESTION="If you already have a raspbian buster lite image, you can select it
from your file system, otherwise, Do you want to download one right now?"
make_question "$QUESTION" "download_image" "select_image_from_folder"

# Format SD
echo -e "Formatting SD..."
format_sd
echo -e "done"

# Optional: SD zero filling
QUESTION="This step is totally optional, Do you want to write zeros on the
selected device? (Filling a device with zeros is a low level way of format a
device, this method is cleaner but can take several minutes depending on the
device's size)"

make_question "$QUESTION" "write_zeros" 'echo "Zero filling operation aborted"'

# Burn raspbian image
echo -e "Burning image..."
burn_image

# Enable ssh-service into raspberry
enable_rasp_ssh

MESSAGE="Installation finished, extract sd device and insert it into the
raspberry"
echo -e "$MESSAGE"
