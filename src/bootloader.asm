;Welcome, this is my FAT32 bootsector
;Comments that have no code to the left are the most important(they say what is going on)
;Comments that have code on their left explain how that code works(if you know assembly it's optional)

;Let's jump right int othe code:

;I couldn't afford leaving space for DAP, so:
;I overwrite code that was already executed with DAP
;(DAP is just some info about data you want to load/store, which you 'show' to BIOS through interrupt)
%define size 0x00       ;byte: size of DAP(value 0x10)
%define nul 0x01        ;byte: null byte(value 0x00)
%define sectors 0x02    ;word: number of sectors to load/store(value: numbers of sectors)
                        ;REMEMBER that multi byte(words, dwords, qwords) fields must be in Little-endian

%define offset 0x04     ;word: offset in memory to where data will be loaded/stored into/from
%define segment 0x06    ;word: segment in memory which with offset creates address to buffer
                        ;REMEMBER segment address is multiplied by 0x10, so:
                        ;offset 0x7C00 is equal to segment 0x07C0
                        
%define address 0x08    ;Qword: 8 bytes containing address of sector on drive to load/store data
                        
                        ;END OF DAP

;right after DAP I overwrite code with some useful info,
;such as:
;addresses of first FAT and data sectors
;device from which I am loading
;etc

%define dev 0x10        ;byte: device containing this bootsector
%define curcluster 0x11 ;Dword: current cluster
%define fat 0x15        ;Dword: first FAT sector address
%define data 0x19       ;Qword: first data sector address

;This are defined offsets to info which is loaded from first sector of partition
%define clustersize 0x020D ;byte:  number of sectors per cluster
%define ressecs 0x020E     ;word:  number of reserved sectors right after the BPB(first sector of partition)
%define numfats 0x0210     ;byte:  number of FATs
%define fatsize 0x0224     ;Dword: size of one FAT in sectors
%define rootcluster 0x022C ;Dword: root directory cluster number 

;offsets to info about file in root directory
%define lwordcluster 0x061A;word: high word of first cluster of the file
%define hwordcluster 0x0614;word; low word...

;and offset in bootsector to first MBR partition
%define first_part 0x01BE
                                       
;Real mode of course                                                                               
BITS 16 
                 
      
         
                                                                 
                                                                                                 
;Setting segments                                        
xor ax, ax
mov ss, ax  ;SS=0x0000
not ax
mov sp, ax  ;SP=0xFFFF
mov ax, 0x07C0
mov ds, ax  ;DS=0x7c00(where bootsector is loaded)

;Checking if BIOS supports extended interrupts 
mov ah, 0x41
mov bx, 0x55AA
int 13h
;if not:
mov al, 0x30;load al with error code    
jc err;and jump to error routine

;a loop searching for bootable, FAT32 partition
mov bx, first_part
findpart:
cmp byte [bx], 0x80;checking tif it's bootable
jne chk_next
cmp byte [bx+4], 0x0B;checking it's type(not very professional but effective)
je foundpart   ;if both(bootable, type) match, then jump to the next part
chk_next: ;if not, check next partition entry
cmp bl, 0xFE    ;if checked all of them and none is matching:
mov dl, byte[dev]
mov al, 0x31   ;save error code
je err         ;and jump to error routine
add bl, 0x10
jmp findpart

;When partition is found set the DAP with address of that partition
foundpart:
mov dword [size], 0x00010010    
mov dword [offset], 0x07e00000  
mov eax, dword [bx+8]     
mov dword [address], eax        
mov dword [address+4], 0x00000000
mov byte [dev], dl              
;and load it's first sector
call load       

;Save/calculate values for later use

    ;first FAT sector
xor ebx, ebx
mov bx, word [ressecs]
add ebx, dword [address]
mov dword[fat], ebx 
    ;first data cluster
xor eax, eax
mov al, byte [numfats]
mul dword[fatsize] 
mov dword[data+4], edx  
add ebx, eax
xor eax, eax
mov al, byte[clustersize] 
mul dword [rootcluster] 
sub ebx, eax
mov dword[data], ebx
    ;and copy root cluster number(so it will be loaded next)
mov eax,dword [rootcluster]
mov dword [curcluster],eax

;This chunk of code loads root directory cluster, searches for the file, if not found loads next, searches, and so on
;needed FAT sector is loadaed to 0x8000, and directory cluster to 0x8200
lndir:  
mov word[segment], 0x0820;

call lnc   ;this routine loads cluster(curcluster), and saves number of next cluster to load
lncall:;this is just to check later from which place routine was called 
    
;loop compairinn filenames
mov si, kern_filename
mov bx, 0x0200
xor ax, ax
mov al, byte [clustersize]
mul bx
xor bx, bx
searchdir:
    
call cmp_filename ;routine comparing filenames character by character
searchcall:
add bx, 0x20
cmp bx, ax
je lndir
jmp searchdir   
;NOTICE that escape from this loop is made in routine 'lnc'
;when lnc loaded last cluster(file not found), or filenames match(file found)they both jump to 'end:'
                    


;this is the place where routines jump
end:
pop cx 
cmp cl, searchcall  ;check if filenames match or file ended
jne theend  ;jump to another check if file ended
            
;if filenames were matching, set DAP, and curcluster for loading the file
mov word [segment], 0x1000
mov cx, word [bx+hwordcluster]
shl ecx, 0x10
mov cx, word [bx+lwordcluster] 
mov dword [curcluster], ecx
;a loop which just loads the file
endrepeat:
call lnc
endcall:
add word [segment], 0x0020
jmp endrepeat
;NOTICE, once again it exits when lnc loads last cluster


theend: 
cmp cl, endcall ;this checks which file ended(root directory because file wasn't found,
                ;                             or file was succesfully loaded)
              
;if file wasn't found:              
mov al, 0x32   ;save error code 
jne err        ;and jump to error routine
;if all is good, set registers and jump to loaded file
mov ax, 0x1000  
mov ds, ax    
xor eax, eax    
not ax
mov sp, ax      
jmp 0x1000:0x0000
;THE END



;FUNCTIONS:

;comparing filenames, if match jump to 'end:'
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
    
   


;loading cluster, if last cluster loaded jump to 'end:'
lnc:
    cmp dword [curcluster], 0x0FFFFFF8   
    ja end                             
    
    xor eax, eax 
    mov al, byte [clustersize]
    mov word [sectors], ax
    mul dword [curcluster]
    add eax, dword [data]
    add edx, dword [data+4]
    
    mov dword [address], eax
    mov dword [address+4], edx
    call load
    
   
    xor eax, eax
    mov dword [address+4], eax
    mov al, 0x01
    mov word [sectors], ax
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
    
    pop bx
    and dword [bx+0x0400], 0x0FFFFFFF 
    mov eax, dword [bx+0x0400]
    mov dword [curcluster], eax
    ret


;simple routine for loading sectors
load:
    mov cl, 0x05
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
    
;error routine, prints error and stops
err:
    mov ah, 0x0e
    int 0x10
    jmp $

    
kern_filename: db _FILENAME;8.3 filename of kernel or whatever, all in capital letters
                    ;8 characters of name and 3 of extention, rest of spaces

                   
