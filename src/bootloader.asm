;Welcome!
;Before you look at code below I only want to explain something:
;Most of the code could be written more efficiently, but
;as the name indicates(bootsector) I only had 446 bytes
;to write all of this, so thing that mattered the most was space
;Let's now jmp into the code:

;As I said space matters so I overwrited executed code with DAP data
;DAP is a piece of info about sectors on disk you want to read or write,
;which you later 'show to the BIOS' by an interrupt
%define size 0x00       ;byte: size of a DAP(always value=0x10)
%define nul 0x01        ;byte: NULL-which means value=0x00
%define sectors 0x02    ;word containing number of sectors to be written/read
                        ;REMEMBER that multi byte fields must be in Little-endian
%define offset 0x04     ;word containing offset address to buffer in memory
%define segment 0x06    ;word containing segment address of buffer in memory
                        ;REMEMBER segment address is multiplied by 0x10, so:
                        ;offset 0x7C00 is equal to segment 0x07C0
%define address 0x08    ;Quad word containing LBA address to sector you want
%define dev 0x10        ;byte containing number of device we're booting from
%define fat 0x11        ;double word containing LBA address to start of FAT table
%define data 0x15       ;Quad word containing LBA address to start of Data clusters

;Theese are addresses to info which will be loaded and are hardwired to this code,
;and hardwired to positions of segments and DAP offsets
%define clustersize 0x020D  ;address of 'sectors per cluster' info
%define ressecs 0x020E      ;address of 'reserverd sectors' info
%define numfats 0x0210      ;address of 'number of FATS' info
%define fatsize 0x0224      ;address of 'FAT size' info
%define curcluster 0x022C   ;address of 'current cluster' info

%define first_part 0x01BE0
                                
BITS 16 
                 
                
         
                                                                 
                                                                                                 
;Loading segments, and stack pointer                                                         
xor ax, ax
mov ss, ax
mov ax, 0x07C0
mov ds, ax
not ax
mov sp, ax
;Making sure BIOS can handle extended interrupts
mov ah, 0x41
mov bx, 0x55AA
int 13h
mov al, 0x30    ;if not save error code
jc err          ;and jump to print it
;find first FAT32, bootable partition
mov bx, first_part;address of first MBR Partition
findpart:
cmp byte [bx], 0x80
jne chk_next
cmp byte [bx+4], 0x0B
je foundpart
chk_next:
cmp bl, 0xFE
mov al, 0x31    ;another error code
je err          ;and jump to print (if there's no FAT32 bootable partition)             
add bl, 0x10
jmp findpart
;loading first sector of a partition to get data about filesystem
foundpart:
mov dword [size], 0x00010010    ;this sets DAP parameters(size = 0x10, null = 0x00, sectors = 0x0001)
mov dword [offset], 0x07e00000  ;this sets segment/offset of buffer right after this bootsector
mov eax, dword [bx+8]           ;copying first sector of partition 
mov dword [address], eax        ;to LBA addres of DAP
mov dword [address+4], 0x00000000;rest of the address is cleaned to 0's
mov byte [dev], dl              ;saving this boot device number
call load       ;calling function which actually loads sector

;Saving data:
    ;saving FAT address
xor ebx, ebx
mov bx, word [ressecs]
add ebx, dword [address]
mov dword[fat], ebx
    ;saving data address
xor eax, eax
mov al, byte [numfats]
mul dword[fatsize]
add eax, ebx
sub eax, dword [curcluster]
mov dword[data], eax
mov dword[data+4], edx
;now a loop which:
    ;loads a directory cluster:
lndir:  
mov word[segment], 0x0820
call lnc    ;load cluster by it's number, and prepare new number to follow the chain
lncall:
    ;sets register values
mov si, kern_filename
mov bx, 0x0200
xor ax, ax
mov al, byte [clustersize]
mul bx
xor bx, bx
searchdir:
    ;and compares filename with root directory entries
call cmp_filename
searchcall:
add bx, 0x20
cmp bx, ax
je lndir
jmp searchdir   ;there is no escape, 
                ;because getting out of loop is achieved inside loading sectors,
                ;or if names match-out of comparing function
                    

;CONTINUE:
end:
pop cx ;both functions escape to the same place, SO:
cmp cl, searchcall  ;we have to check what happened- did filename match or it wasn't found at all?
jne theend   ;if file wasn't fount it has to be checked once again
             ;(function loading new cluster is used to both load a file and load root directory, so it has to be checked)
;It's time to load our Binary kernel:
mov word [segment], 0x1000
mov cx, word [bx+0x0614]
shl ecx, 0x10
mov cx, word [bx+0x061A] 
mov dword [curcluster], ecx
;And here load cluster of this file
endrepeat:
call lnc
endcall:
add word [segment], 0x0020
jmp endrepeat; once again the escape is being done by loading function when file is loaded

;So this is the second check
theend: 
cmp cl, endcall ;it checks which file ended(root directory because file wasn't found), -ERROR
                ;or file which was loaded -NOT ERROR
                
mov al, 0x32    ;if error, save error code
jne err         ;and print it
jmp 0x1000:0x0000;THIS is the end. It just jumps to loaded kernel

;FUNCTIONS:

;Function comparing filename saved in bootsector with filenames in root directory
cmp_filename:
    pusha 
    mov cl, 0x0B
.repeat:    
    lodsb
    cmp al, [bx+0x0600]
    jne .ne
    dec cl
    cmp cl, 0x00
    je .e
    inc bx
    jmp .repeat
    
.ne:
    popa 
    ret
.e:
    popa
    jmp end
    


;Function loading cluster by it's number and saving next cluster number 
lnc:
    cmp dword [curcluster], 0x0FFFFFF8  ;Here is THE escape; If it was the last cluster to load: 
    ja end                              ;just exit to the end
    
    xor eax, eax 
    mov al, byte [clustersize]
    mov word [sectors], ax; save number of sectors to load whole cluster at once
    mul dword [curcluster]
    add eax, dword [data]
    add edx, dword [data+4]
    ;LBA address of the cluster=clusterSize*currentCluster+dataLBA_Address
    mov dword [address], eax
    mov dword [address+4], edx
    call load
    
    ;load FAT sector of next address
    xor eax, eax
    mov dword [address+4], eax
    mov word [sectors], ax
    add word [sectors], 0x0001
    xor ebx, ebx
    mov al, 0x04
    mul dword [curcluster]
    mov bx, 0x0200
    div dword ebx
    add eax, dword [fat]
    mov dword [address], eax
    mov word [segment], 0x0800
    push dx
    call load
    ;and copy this address
    pop bx
    and dword [bx+0x0400], 0x0FFFFFFF ;HAHA FAT32 is using only 28 bits to address clusters
    mov eax, dword [bx+0x0400]
    mov dword [curcluster], eax
    ret


;Load sectors according to DAP
load:
    mov cl, 0x05; If something goes wrong retry five times
repload:
    dec cl
    cmp cl, 0x00
    mov al, 0x33
    je err
    mov dl, byte[dev]
    mov si, 0x0000 
    mov ah, 0x42
    int 13h
    jc repload 
    ret 
    
;function reporting an error to screen
err:
    mov ah, 0x0e
    int 0x10
    jmp $;and it stops
    
kern_filename: db _FILENAME;8.3 filename of kernel or whatever all in capital letters
                    ;8 characters of name and 3 of extention, rest of spaces

                    ;Make sure device is bootable(At the end of MBR there should be a magic Word: 0x55 0xAA)
