# FAT32-Bootsector

A simple and a bit messy bootsector, which lets you load your bootloader or kernel from a file.

Build using attached script.

How it works? Let me explain parts that I found difficult at first:

## Theory (if you know how FAT works skip to practice)

### FAT32 basics


**File Allocation table** or **FAT** filesystem has 3 important parts:
+ BPB
+ FAT
+ Data clusters

### BPB

**BIOS Parameter Block** or **BPB** is the first sector of a partition. It contains info about the filesystem for example - size of clusters, size of sectors, amount of reserved sectors etc...
This is the first sector we need to find everything else.

### FAT

**File Allocation Table** or **FAT** is just a very long table of 4 byte entries. Each entry has a corresponding cluster.

### Data clusters

**Data** is where actual 'meat' is. It is 'sliced' to clusters, which are then connected to form a file.

### So how does it work?

![alt text](https://github.com/TebexPL/FAT32-Bootsector/blob/master/doc/fathowto.png "FAT_howto")

Here's an example - theese yellow fields belong to one file. Here we assume that file starts at cluster 1, so you load this cluster into memory, and check what address is at field 1 in File Allocation Table. As you can see address in field 1 points to the 4th cluster. When you load 4th cluster you check FAT's 4th entry, and you see address to the next cluster, and so on. When you loaded last cluster the address in FAT points to a value bigger than 0x0FFFFFF8. This is of course simplified but it shows how it works.

## Practice

### What does this bootsector actually do?

Here it is, step by step:

1. Check if BIOS supports extended load from disc
2. Looks for first FAT32, bootable partition
3. Searches for specified file in root directory
4. Loads it
5. Jumps to it

### OK so it loads... But what about my code? 

#### Memory layout when jumping to your code:
![alt text](https://github.com/TebexPL/FAT32-Bootsector/blob/master/doc/Memory_layout.png "Memory layout")

#### Registers
Most of registers **are not "zeroed" and garbage is assigned to them**

**Only those have valid values:**

+ CS - as on image(assigned to loaded file)
+ DS - as on above
+ SS - as on image(0x0000)
+ SP - as on image(0xFFFF)
+ DL - drive number(for bios interrupts)

## Limitations
+ It's all in real mode so maximum size of file must be less than **960 KB**
+ File must be in root directory of selected partition
+ Filename - max 8 characters for name and 3 for extention

## Cool! how do I make my HDD/SSD/SD card/Pendrive/floppy bootable?

Just use my script... **(Only for linux, Tested on Ubuntu)**

## Errors?

When error occurs bootsector draws error code on the screen.

### Here are codes and explanations of errors:

0 - extended BIOS functions not availble

1 - Bootable partition not found or it's type is not FAT32

2 - File not found

3 - Can't load sectors (BIOS interrupt error)

