# FAT32-Bootsector

A simple and VERY compact bootsector, which lets you load your bootloader or kernel from a file.

Build using attached script.

Notice: Don't read this, read the source code. It is commented, so all the info is there

## What does this bootsector actually do?

Here it is, step by step:

1. Check if BIOS supports extended Disk operation
2. Looks for first active FAT32 partition
3. Looks for your file on that partition(in root directory)
4. Loads it into memory
5. Executes it

## State of memory after my bootsector

### Your Code:
  Your code is loaded at 0x1000:0x0000(segment:offset), or 0x10000(linear).

### Registers
Most of registers **are not "zeroed" and garbage is assigned to them**

**Only those have valid values:**

+ CS:IP - 0x1000:0x0000 (assigned to loaded file)
+ DS - 0x1000 (also assigned to loaded file)
+ SS:SP - 0x0000:0xFFFF (stack in first segment)
+ DL - drive number(for bios interrupts)

### Useful data left in memory

#### after jumping to loaded file there is still some useful data left in memory:
**(all offsets are specified in source code)**

+ 0x7C00 - current disk(device number), FAT address, first data sector address and similar info.
+ 0x7E00 - BPB sector of that partition



## Limitations
+ It's all in real mode so maximum size of file shouldn't be bigger than a few hundred Kilobytes
+ File must be in root directory of selected partition
+ Filename - Bootsector searches for file with 8.3 filename

## Install methods

To install use:

+ On ubuntu compatible systems use Install.sh script
+ On Windows use Fat32-bootsector.exe

**Notice** Windows version does not use letters for partitions, but phisycal partitions(not logical), so:
It may be more difficult to match partition-letter, but on the other hand it supports **multi partition usb drives**

## Errors?

When error occurs bootsector draws error code on the screen.

### Here are codes and explanations of errors:

0 - extended BIOS functions not availble

1 - Bootable partition not found

2 - Bootable partition  is not FAT32

3 - File not found

4 - Can't load sectors (BIOS interrupt error)
