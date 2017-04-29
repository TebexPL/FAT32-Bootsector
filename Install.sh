RED='\033[0;31m'
NC='\033[0m' 
clear
printf "${RED}"
echo "This script needs NASM to compile source code, It will be installed right now"
printf "${NC}"
echo "(press anything to continue)"
read -n 1 -s
clear
sudo apt-get install nasm -qq > /dev/null




bool="1"

clear
printf "${RED}"
echo "To exit press enter with no value, at any time"
printf "${NC}"
echo "(press anything to continue)"
read -n 1 -s
while [ "$bool" = "1" ]; do
clear
echo "Filename without extention: "
echo "---------------------------"
read 
if [ -z "$REPLY" ] ; then
	exit 
fi
while (( "${#REPLY}" > "8" )) ; do
	echo "max 8 characters"
	read
done
_FILENAME=$REPLY
filename=$REPLY
while (( "${#_FILENAME}" < "8" )) ; do
	_FILENAME="$_FILENAME "
done
clear
echo "Extention: "
echo "----------"
read
if [ -z "$REPLY" ] ; then
	exit 
fi
while (( "${#REPLY}" > "3" )) ; do
	echo "max 3 characters"
	read
done
filename+="."
filename+=$REPLY
_FILENAME="$_FILENAME""$REPLY"
while (( "${#_FILENAME}" < "11" )) ; do
	_FILENAME="$_FILENAME "
done

_FILENAME=$(echo "$_FILENAME" | awk '{printf toupper($0)}')

clear
echo "Is that correct?(y/n)"
echo "---------------------"
echo "Filename: "$filename

read
if [ -z "$REPLY" ] ; then
		exit 
fi
if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] ; then
	bool="0"
else
	bool="1"
fi

done

nasm -d _FILENAME=\'"$_FILENAME"\' -o bin/bootloader.bin -f bin src/bootloader.asm

clear

printf "${RED}"
echo "CHECK TWICE WHAT YOU'RE DOING NOW, IF YOU CHOOSE WRONG DEVICE YOUR PC WON'T BOOT";
printf "${NC}"
echo "(press anything to continue)"
read -n 1 -s 
clear
echo "Choose device you want to boot from:"
echo "--------------------------------------------------------------------------------"
devices=$(sudo ls /dev/disk/by-id/ | grep -v "part[0-9]$");
num=1
for word in $devices
do
	device[$num]=$word
    echo $num". "${device[$num]};
	num=$((num+1));
done 
read
while [ -z "$REPLY" ] || (( "$REPLY" < "1" )) || (( "$REPLY" >= "$num")) ; do
	if [ -z "$REPLY" ] ; then
		exit 
	fi
	echo "Not a valid value!"
	read
	if [ -z "$REPLY" ] ; then
		exit 
	fi
done


bootdev=${device[$REPLY]}
clear
echo "Choose partition you want to boot from:"
echo "---------------------------------------"
parts="$(sudo parted /dev/disk/by-id/${device[$REPLY]} print | grep "^ [0-9]")";

if [ $? -eq 0 ]; then
	info=$(sudo parted /dev/disk/by-id/${device[$REPLY]} print | grep "^Number");
	info=${info%"Flags"}
    echo "$info"
else
	clear
	echo "Bad data or device not available"
    exit
fi

num=1
while read -r line; do

   	part[$num]=$line
	curpart=${part[$num]%"boot"}
    echo " $curpart"
 	num=$((num+1));
done <<< "$parts"
read
while [ -z "$REPLY" ] || (( "$REPLY" < "1" )) || (( "$REPLY" >= "$num")) || [ -z "$(echo ${part[$REPLY]} | grep "fat32")" ] ; do
	if [ -z "$REPLY" ] ; then
		exit 
	fi
	echo "Not a valid value or partition isn't FAT32!"
	read

done
clear
bootpart=$REPLY
echo "Are you sure you want to install bootsector on this device?[y/n]"
echo "----------------------------------------------------------------"
echo "Device:    "$bootdev
echo 
echo "Partition:  $info"
echo "            ${part[$REPLY]%"boot"}"
read
if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] ; then
	echo 
else
	exit
fi
	sudo dd if=/dev/disk/by-id/$bootdev of=backup/backup_bootsector_MBR.bin count=1 status=none
	sudo chmod 777 backup/backup_bootsector_MBR.bin
	tmp=$(wc -c ./bin/bootloader.bin | awk '{printf $1}')
	if (("$tmp" > "446")) ; then
		clear
		printf "${RED}"
		echo "Critical Error - bootsector code exceeds 446 bytes";
		echo "No changes were made to your device";
		printf "${NC}"
		exit
	fi
	if [ -z "$(echo ${part[$bootpart]} | grep "boot" )" ] ; then
		sudo parted /dev/disk/by-id/$bootdev toggle $bootpart boot > /dev/null
	fi
	clear
	sudo dd if=./bin/bootloader.bin of=/dev/disk/by-id/$bootdev status=none
	echo "DONE!" 
	printf "${RED}\n"
	printf "Now copy "${NC}$filename${RED}" to root directory of selected partition, and you're good to go"
	printf "${NC}\n"
	echo "(press anything to end)"
	read -n 1 -s
	clear

