clear
echo "To exit press enter with no value, at any time"
echo "Filename without extention: "
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

echo "Extention: "
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


nasm -d _FILENAME=\'"$_FILENAME"\' -o bin/bootloader.bin -f bin src/bootloader.asm

clear
echo "CHECK TWICE WHAT YOU'RE DOING NOW, YOUR PC MAY NOT BOOT IF YOU SCREW UP SOMETHING";
echo "Choose device to install bootsector:"
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
echo "Choose partition be set as boot:"
parts=$(sudo parted /dev/disk/by-id/${device[$REPLY]} print | grep "^ [0-9]");
if [ $? -eq 0 ]; then
    echo 
else
	clear
	echo "Bad data or device not available"
    exit
fi

num=1
while read -r line; do

   	part[$num]=$line
   	echo ${part[$num]};
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
echo
echo "Device: "$bootdev
echo "Bootable Partition: "${part[$REPLY]}
read
if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] ; then
	echo 
else
	exit
fi

	tmp=$(wc -c ./bin/bootloader.bin | awk '{printf $1}')
	if (("$tmp" > "446")) ; then
		clear
		echo "Critical Error - bootsector code exceeds 446 bytes";
		exit
	fi
	if [ -z "$(echo ${part[$bootpart]} | grep "boot" )" ] ; then
		sudo parted /dev/disk/by-id/$bootdev toggle $bootpart boot > /dev/null
	fi
	sudo dd if=./bin/bootloader.bin of=/dev/disk/by-id/$bootdev
	#clear
	echo "DONE"
	echo "Now copy "$filename" to root directory of selected partition, and you can boot from this device"


