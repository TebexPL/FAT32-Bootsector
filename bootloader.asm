;defining offsets to data (DAP), which will be written over executed code(to save space)
%define bs 0x7c00 ;since I'm saving every byte I can instead of setting DS to 0x07C0,
                  ;I add this to addresses
                 
;Start of DAP defines
%define nul 0x01 ;byte 
%define sectors 0x02 ;word 
%define offset 0x04 ;word 
%define segment 0x06 ;word
%define address 0x08 ;qword
%define dev 0x10 ;byte 
%define fat 0x11 ;dword 
%define data 0x15 ;qword
;End of DAP defines
%define clustersize 0x7E0D ;address of loaded fat32 boot sector+offset to sectors per cluster
%define ressecs 0x7E0E ;the same but offset points to number of reserved sectors before FAT
%define numfats 0x7E10 ;the same but offset points to number of FATs
%define fatsize 0x7E24 ;... size of one FAT
%define curcluster 0x7E2C ;At the begining it's root cluster number, then I save there current cluster number


BITS 16 ;inform assembler It's 16 bit mode
                 
                
         
                                                                 
                                                                                                 
;Set segment registers to 0x0000                                                                            
xor ax, ax
mov ss, ax
mov ds, ax
not ax
mov sp, ax
;Check if BIOS supports extended LBA operations
mov ah, 0x41
mov bx, 0x55AA
int 13h
mov al, 0x30 ;save error code before jump
jc err     ;jump if bios doesn't support extended int 0x13 (ERROR)       
;Search for bootable FAT32 partition
mov bx, bs+first_part
findpart:
cmp byte [bx], 0x80
jne chk_next
cmp byte [bx+4], 0x0B
je foundpart
chk_next:
cmp bl, 0xFE
mov al, 0x31
je err                       ;jump if bootable partition not found
add bl, 0x10
jmp findpart
;Load first sector from found partition
foundpart:
mov dword [bs], 0x00010010
mov dword [bs+offset], 0x07e00000
mov eax, dword [bx+8]
mov dword [bs+address], eax
mov dword [bs+address+4], 0x00000000
mov byte [bs+dev], dl
call load
;Save some data:
    ;fat start address
xor ebx, ebx
mov bx, word [ressecs]
add ebx, dword [bs+address]
mov dword[bs+fat], ebx
    ;data start address
xor eax, eax
mov al, byte [numfats]
mul dword[fatsize]
add eax, ebx
sub eax, dword [curcluster]
mov dword[bs+data], eax
mov dword[bs+data+4], edx
;search for kernel filename in root directory
lndir:  ;load root dir cluster
mov word[bs+segment], 0x0820
call lnc
lncall:
mov si, bs+kern_filename
mov bx, 0x0200
xor ax, ax
mov al, byte [clustersize]
mul bx
xor bx, bx
searchdir:;compare names
call cmp_filename
searchcall:
add bx, 0x20
cmp bx, ax
je lndir
jmp searchdir

;after finding file, or end of directory
end:
pop cx
cmp cl, searchcall  ;check if file is file was found
jne theend   ;if jump to next step of checking
;set everything for loading of file
mov word [bs+segment], 0x1000
mov cx, word [bx+0x8214]
shl ecx, 0x10
mov cx, word [bx+0x821A] 
mov dword [curcluster], ecx
endrepeat:;load file
call lnc
endcall:
add word [bs+segment], 0x0020
jmp endrepeat

theend: ;ultimate question
cmp cl, endcall ;check if the file ended or file not found
mov al, 0x32
jne err;jump if not found (ERROR)
jmp 0x1000:0x0000;jump to loaded file. THE END

;function comparing filename in memory with ones on the disk
cmp_filename:
    pusha 
    mov cl, 0x0B
.repeat:    
    lodsb
    cmp al, [bx+0x8200]
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
    


;function loading pending cluster and finding next in a chain
lnc:
    cmp dword [curcluster], 0x0FFFFFF8
    ja end 
    xor eax, eax 
    mov al, byte [clustersize]
    mov word [bs+sectors], ax
    mul dword [curcluster]
    add eax, dword [bs+data]
    add edx, dword [bs+data+4]
    mov dword [bs+address], eax
    mov dword [bs+address+4], edx
    call load
    
    xor eax, eax
    mov dword [bs+address+4], eax
    mov word [bs+sectors], ax
    add word [bs+sectors], 0x0001
    xor ebx, ebx
    mov al, 0x04
    mul dword [curcluster]
    mov bx, 0x0200
    div dword ebx
    add eax, dword [bs+fat]
    mov dword [bs+address], eax
    mov word [bs+segment], 0x0800
    push dx
    call load
    pop bx
    and dword [bx+0x8000], 0x0FFFFFFF
    mov eax, dword [bx+0x8000]
    mov dword [curcluster], eax
    ret


;Function loading sectors to memory according to DAP
load:
    mov cl, 0x05
repload:
    dec cl
    cmp cl, 0x00
    mov al, 0x33
    je err
    mov dl, byte[bs+dev]
    mov si, bs 
    mov ah, 0x42
    int 13h
    jc repload 
    ret 
    
err:
    mov ah, 0x0e
    int 0x10
    jmp $
    
kern_filename: db 'WAVE32  OS '

times 446-($-$$) db 0
first_part: db 0x80
times 510-($-$$) db 0
dw 0xAA55