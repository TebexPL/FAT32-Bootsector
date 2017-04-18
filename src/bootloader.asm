;This defines offset to first/
;MBR entry
%define MBR 0x7DBE  

;This defines address to a buffer/
;for loading root directory entries
%define rootbuffer 0x0840

    ;Theese define memory locations/
;where useful data will be saved 

;DAP
%define DAP 0x7E00  ;DAP for Extended BIOS Interrupts
    %define Dsize 0x00 
    %define Dnull 0x01
    %define Dsectors 0x02 
    %define Doffset 0x04
    %define Dsegment 0x06
    %define Daddress 0x08
    ;End of DAP
   
;More useful data
%define BPB 0x7E10    ;(DWORD) LBA of first /
                      ;sector of loaded partition
%define FAT 0x7E14    ;(DWORD) LBA of first FAT sector
%define DATA 0x7E18   ;(QWORD) LBA of first DATA sector
%define BLOCK 0x7E20  ;(DWORD) LBA of cluster to be loaded
%define Secsize 0x7E24;(DWORD) Size of one sector(in bytes)
%define DEV 0x7E28    ;(BYTE)  Current device(for bios interrupts)  

;Memory addresses to FAT info which is loaded later
%define INFO 0x8000
    %define ResSecs 0x0E    
    %define Fats 0x10
    %define Fatsize 0x24
    %define Rootcluster 0x2C
    %define Secperblock 0x0D
    %define Bytespersec 0x0B

;Setting registers
xor ax, ax
mov ds, ax
mov ss, ax
not ax
mov sp, ax
;Checking if BIOS supports extended interrupts
mov ah,0x41
int 0x13
mov al, 0x30 ;if not-save error code/
jc err;       and jump to error routine

;search for first Bootable, FAT32 partition
xor bx, bx
checkparts:
cmp byte [MBR+bx], 0x80
jne partrepeat
cmp byte [MBR+bx+0x04], 0x0B
je foundpart
partrepeat:
cmp bx, 0x30
mov al, 0x31;if not-save error code/
je err;       and jump to error routine
add bx, 0x10
jmp checkparts;

;When found partition/
;load it's first sector to get more info
foundpart:
mov dword [DAP], 0x00010010
mov dword [DAP+0x04], 0x08000000
mov dword ecx, [MBR+bx+0x08]
mov dword [DAP+0x08], ecx
mov dword [DAP+0x0C], 0x00000000
mov byte [DEV], dl
call dapLoad

;Then calculate and save that info:

;LBA of first FAT sector
mov dword [BPB], ecx
add cx, word [INFO+ResSecs]
mov dword [FAT], ecx

;LBA of first DATA sector
xor eax, eax
mov al, byte [INFO+Secperblock]
mul dword [INFO+Rootcluster]
sub ecx, eax
xor eax, eax
mov al, byte [INFO+Fats]
mul dword [INFO+Fatsize]
add eax, ecx
mov dword[DATA], eax
mov [DATA+4], edx

;cluster number of Root directory 
mov eax, dword [INFO+Rootcluster]
mov dword [BLOCK], eax ;save as pending cluster/
                       ;to be loaded

;Number of bytes per sector
mov ax, word [INFO+Bytespersec]
mov word[Secsize], ax

;set segment register for a buffer
mov ax, rootbuffer
mov es, ax

;search root directory for specified filename
searchdirs:
mov word [DAP+Dsegment],rootbuffer
call lnc
File_not_found: 
sub ax, 0x0840
shl ax, 0x04
mov di, ax
xor bx, bx
xor dx, dx
xor cl, cl
mov si, 0x7c00+filename
cmp_chars:
cmp cl, 0x0B
je match
lodsb
cmp al, byte[es:bx]
jne next_filename
inc bx
inc cl
jmp cmp_chars
next_filename:
xor cl, cl
add dx, 0x20
cmp dx, di
je searchdirs
mov bx, dx
mov si, 0x7c00+filename
jmp cmp_chars

;if filename matches get this file's cluster number
match:
mov bx, dx
mov ax, word[es:bx+0x14]
shl eax, 0x10
mov ax, word[es:bx+0x1A]
mov dword [BLOCK], eax
mov word [DAP+Dsegment], 0x1000
;and load it
loadfile:
call lnc
jmp loadfile

;This is where function jumps when whole file is loaded
eof:
pop ax
cmp al, File_not_found;this checks why file ended:
                        ;1.root directory ended because/
                        ;file wasn't found.
                        ;OR
                        ;2.file was found and successfully/
                        ;loaded
mov al, 0x32;if file wasn't found-save error code
je err ;        and jump to error routine
;Set registers
mov ax, 0x1000
mov ds, ax
;And Jump to loaded Code
jmp 0x1000:0x0000   ; THE END


;Routines:


;lnc - Load Next Cluster
;loads cluster into memory, and saves next cluster's number
lnc:
cmp dword [BLOCK], 0x0FFFFFF8
jae eof;if file ended jump to specified code

;this part saves next cluster's number
push dword [BLOCK]
push word [DAP+Dsegment]
xor eax, eax
mov al, 0x04
mul dword[BLOCK]
div dword [Secsize] 
add eax, dword[FAT]
mov dword[DAP+Daddress], eax
mov word [DAP+Dsegment], 0x0820
mov word [DAP+Dsectors], 0x0001
push dx
call dapLoad
pop bx
mov eax, dword [bx+0x8200]
and eax, 0x0FFFFFFF
mov dword [BLOCK], eax

;This part loads current cluster into memory
pop word [DAP+Dsegment]
xor eax, eax
mov al, byte[INFO+Secperblock]
mov [DAP+Dsectors], al
pop dword ebx
mul ebx
add eax, [DATA]
add edx, [DATA+4]
mov dword[DAP+Daddress], eax
mov dword[DAP+Daddress+4], edx
call dapLoad
;Also sets buffer for next cluster right after loaded one
xor eax, eax
mov al, byte[INFO+Secperblock]
mul word [INFO+Bytespersec]
shr ax, 0x04
add word [DAP+Dsegment], ax
ret 

;Simple routine loading sectors according to DAP
dapLoad:
xor dh, dh
.repeat:
cmp dh, 0x05
mov al, 0x33
je err ;XXX
inc dh
mov ah, 0x42
mov si, DAP
mov dl, byte [DEV]
int 0x13
jc .repeat
ret


;Simple Error routine(only prints one character)
err:
mov ah, 0x0E
int 0x10
jmp $

filename: db _FILENAME; Filename in 8.3 format
