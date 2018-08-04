;All of theese are defining offsets in memory to store data later, or to load data

;This defines offset to first/
;MBR entry-0x10
  %define MBR 0x7DAE

;This defines address to a buffer for loading root directory clusters
  %define RootBuffer 0x0800
;Offset to this bootloader in memory
  %define BootOffset 0x7C00
;Loaded file Segment
  %define FileBuffer 0x1000

;Theese define memory locations, where useful data will be saved
;Also, this data is overwritten over already executed code. (for space saving)
  %define BPB_LBA 0x7C00    ; <--Dword - Points to LBA of first sector of loaded partition
  %define FAT_LBA 0x7C04    ; <--Dword - Points to LBA of first FAT sector
  %define DATA_LBA 0x7C08   ; <--Dword - Points to LBA of first DATA sector
  %define CLUSTER BPB+RootCluster    ; <--Dword - Points to Temporary number of cluster to be loaded
  %define DEV 0x7C14        ; <--Byte  - Points to Current storage device index (for bios interrupts)


;Memory address to FAT BPB which is loaded later
  %define BPB 0x7E00
  ;And some offsets in loaded BPB for calculating FAT values
    %define BytesPerSec   0x0B ; <--Word  - Points to Bytes Per Sector
    %define SecPerCluster 0x0D ; <--Byte  - Points to Sectors Per Cluster
    %define ResvdSecs     0x0E ; <--Word  - Points to Reserved Sectors
    %define FatCount      0x10 ; <--Byte  - Points to Number of FATs
    %define FatSize       0x24 ; <--Dword - Points to Size of one FAT
    %define RootCluster   0x2C ; <--Dword - Points to Root Cluster Number
;Error codes and their meanings
  %define ERR_NO_EXT      0x30 ; <-- Extended BIOS interrupts not supported
  %define ERR_NO_ACTIVE   0x31 ; <-- No active partition found
  %define ERR_NOT_FAT32   0x32 ; <-- Active partition is not FAT32
  %define ERR_NOT_FOUND   0x33 ; <-- File is not present in root directory
  %define ERR_HARDWARE    0x34 ; <-- Loading sector error(probably hardware error)

;Misc defines
  %define FAT32 0x0B
  %define FAT32LBA 0x0C
  %define HIDFAT32 0x1B
  %define HIDFAT32LBA 0x1C
;Setting segment registers, and Stack
  cli
  xor ax, ax
  mov ds, ax
  mov ss, ax
  mov es, ax
  or sp, 0xFFFF
  sti
;Checking if BIOS supports extended interrupts
  mov ah, 0x41
  mov bx, 0x55AA
  int 0x13
    mov al, ERR_NO_EXT ;if not - save error code and jump to error routine
    jc ErrorRoutine

;Find active partition
  mov bx, MBR
findActivePart:
  add bl, 0x10
  cmp bl, 0xFE
    mov al, ERR_NO_ACTIVE;if no bootable partition was found - save error code and jump to error routine
    je ErrorRoutine
  cmp byte [bx], 0x80
  jne findActivePart;

;Check active partition type
  cmp byte[bx+0x04], FAT32
  je loadBPB
  cmp byte[bx+0x04], FAT32LBA
  je loadBPB
  cmp byte[bx+0x04], HIDFAT32
  je loadBPB
  cmp byte[bx+0x04], HIDFAT32LBA
  je loadBPB
  mov al, ERR_NOT_FAT32
  jmp ErrorRoutine


loadBPB:
;When found active partition, load it's first sector to get FAT information
  mov ecx, dword [bx+0x08]
  mov dword [DAP.address+BootOffset], ecx
  mov byte [DEV], dl
  call dapLoad

;Then calculate and save that information:

;LBA of first FAT sector
  mov ecx, dword [DAP.address+BootOffset]
  mov dword [BPB_LBA], ecx
  add cx, word [BPB+ResvdSecs]
  mov dword [FAT_LBA], ecx

;LBA of first DATA sector
  xor eax, eax
  mov al, byte [BPB+FatCount]
  mul dword [BPB+FatSize]
  add ecx, eax
  xor eax, eax
  mov al, byte [BPB+SecPerCluster]
  sub ecx, eax
  sub ecx, eax
  mov dword[DATA_LBA], ecx



;search root directory for specified filename
searchCluster:
  cmp dword [CLUSTER], 0x0FFFFFF8
  mov al, ERR_NOT_FOUND;if file wasn't found(searched whole root directory)-save error code
  jae ErrorRoutine ;        and jump to error routine
  ;Load one cluster of root directory
  mov word [DAP.segment+BootOffset], RootBuffer
  call lnc
  ;Prepare registers for searching cluster
  mov dx, word [DAP.segment+BootOffset]
  shl dx, 0x04
  mov bx, RootBuffer*0x10-0x20 ; <-- Offset to Root Buffer-0x20
  ;Prepare registers for each filename comparison
  searchPrep:
  add bx, 0x0020
  cmp dx, bx ; <--- if whole cluster was checked - load another one
    je searchCluster
  ;Check if entry has attribute VOLUME_ID or DIRECTORY
  test byte[es:bx+0x0b], 0x18
    jnz searchPrep
  mov di, bx
  mov cx, 0x000B
  mov si, BootOffset+filename
  ;Compare single characters of filenames from root directory with our filename
  repe cmpsb
    jne searchPrep ;<--- if filenames don't match, try another filename

;if filename matches get this file's cluster number
match:
mov ax, word[es:bx+0x14]
mov dx, word[es:bx+0x1A]
mov word [CLUSTER], dx
mov word [CLUSTER+2], ax
mov word [DAP.segment+BootOffset], FileBuffer
;and load it
loadfile:
call lnc
cmp dword [CLUSTER], 0x0FFFFFF8
jb loadfile

;This is where function jumps when whole file is loaded
fileLoaded:
;Set registers
push FileBuffer
pop ds
;And Jump to loaded Code
mov dl, byte[DEV]
jmp FileBuffer:0x0000   ; THE END


;Routines:


;lnc - Load Next Cluster
;loads cluster into memory, and saves next cluster's number
lnc:
;this part saves next cluster's number
push dword [CLUSTER]
push word [DAP.segment+BootOffset]
xor eax, eax
mov al, 0x04
mul dword[CLUSTER]
xor ebx, ebx
mov bx, word [BPB+BytesPerSec]
div ebx
add eax, dword[FAT_LBA]
mov dword[DAP.address+BootOffset], eax
mov word [DAP.segment+BootOffset], RootBuffer
mov word [DAP.count+BootOffset], 0x0001
xchg bx, dx
call dapLoad
mov eax, dword [bx+(RootBuffer*0x10)]
and eax, 0x0FFFFFFF
mov dword [CLUSTER], eax

;This part loads current cluster into memory
pop word [DAP.segment+BootOffset]
xor eax, eax
mov al, byte[BPB+SecPerCluster]
mov byte[DAP.count+BootOffset], al
pop dword ebx
mul ebx
add eax, dword[DATA_LBA]
mov dword[DAP.address+BootOffset], eax
call dapLoad
;Also sets buffer for next cluster right after loaded one
xor eax, eax
mov al, byte[BPB+SecPerCluster]
mul word [BPB+BytesPerSec]
shr ax, 0x04
add word [DAP.segment+BootOffset], ax
ret

;Simple routine loading sectors according to DAP
;It also tries to call BIOS interrupt 5 times, if error occurs
dapLoad:
mov cx, 0x0005
.repeat:
mov ah, 0x42
mov si, DAP+BootOffset
mov dl, byte [DEV]
int 0x13
jnc .end
loop .repeat
mov al, ERR_HARDWARE
jmp ErrorRoutine
.end:
ret


;Simple Error routine(only prints one character - error code)
ErrorRoutine:
mov ah, 0x0E
int 0x10
cli
jmp $


filename: db _FILENAME; Filename in 8.3 format


DAP:
.size: db 0x10
.null: db 0x00
.count: dw 0x0001
.offset: dw 0x0000
.segment: dw BPB/0x10
.address: dq 0x0000000000000000
