;AquaSeven --- The Aqua Seven Operating System Kernel
;===================================================================

	BITS 16
	%DEFINE MYOS_VER '0.0.1'	 ;OS version number
	%DEFINE AQUASEVENOS_API_VER 1	; API version for programs to check
	%DEFINE KEY_ESC		27

	disk_buffer equ 24576 

os_call_vectors:
	jmp os_main 			; 0000h --called from bootloader
	jmp os_print_string		; 0003h
	jmp os_move_cursor		; 0006h
	jmp os_wait_for_key		; 0012h
	jmp os_draw_background		; 002Ah
	





;--------------------------------------------------------------
; START OF MAIN KERNEL CODE


	
os_main:
	cli				; Clear interrupts
	mov ax, 0
	mov ss, ax			; Set stack segment and pointer
	mov sp, 0FFFFh
	sti				; Restore interrupts

	cld				; The default direction for string operations
					; will be 'up' - incrementing address in RAM

	mov ax, 2000h			; Set all segments to match where kernel is loaded
	mov ds, ax			; After this, we don't need to bother with
	mov es, ax			; segments ever again, as AquaSevenOS and its programs
	mov fs, ax			; live entirely in 64K
	mov gs, ax

	cmp dl, 0
	je no_change


no_change:
	mov ax, 1003h			; Set text output with certain attributes
	mov bx, 0			; to be bright, and not blinking
	int 10h

option_screen:
	mov ax, os_init_msg		; Set up the welcome screen
	mov bx, os_version_msg
	mov cx, 10001111b		; Colour: white text on light blue
	call os_draw_background

	mov ax, strserialport1		; Ask if user wants app selector or command-line
	mov bx, dialog_string_2
	mov cx, dialog_string_3
	mov dx, 1			; We want a two-option dialog box (HDI or EXIT)
	;call os_dialog_box

	cmp ax, 1			; If HDIOK (option 0) chosen, start app selector
	jne os_draw_background1
	
	call os_exit		; Otherwise clean screen and start the CLI
	


	; Data for the above code...

	os_init_msg		db '*************************Welcome to MYOS OS****************************', 0
	os_version_msg		db 'Version ', MYOS_VER, 0

	os_init_msg2		db '                         MyOs Hardware Details                               ', 0
	os_version_msg2		db 'Version ', MYOS_VER, 0

	dialog_string_1		db 'Welcome to MYOS Operating System', 0
	dialog_string_2		db 'Please select HDI for HardwareInfo or', 0
	dialog_string_3		db 'select Exit for quit the OS.', 0

os_exit:
	mov ax, 5307h
	mov cx, 3
 	mov bx, 1
	int 15h

os_draw_background1:
	mov ax, os_init_msg2		; Set up the welcome screen
	mov bx, os_version_msg2
	mov cx, 00001111b		; Colour: white text on black
	

	pusha

	push ax				; Store params to pop out later
	push bx
	push cx

	mov dl, 0
	mov dh, 0
	call os_move_cursor

	mov ah, 09h			; Draw white bar at top
	mov bh, 0
	mov cx, 80
	mov bl,01110000b   ;;changed
	mov al, ' '
	int 10h

	mov dh, 1
	mov dl, 0
	call os_move_cursor

	mov ah, 09h			; Draw colour section
	mov cx, 1840
	pop bx				; Get colour param (originally in CX)
	mov bh, 0
	mov al, ' '
	int 10h

	mov dh, 24
	mov dl, 0
	call os_move_cursor

	mov ah, 09h			; Draw white bar at bottom
	mov bh, 0
	mov cx, 80
	mov bl, 01110000b
	mov al, ' '
	int 10h

	mov dh, 24
	mov dl, 0
	call os_move_cursor
	pop bx				; Get bottom string param
	mov si, bx
	call os_print_string

	mov dh, 0
	mov dl, 1
	call os_move_cursor
	pop ax				; Get top string param
	mov si, ax
	call os_print_string

	call os_hardware

	mov dh, 1			; Ready for app text
	mov dl, 0
	call os_move_cursor

	call os_hardware


	popa
	ret



os_hardware:
	cli
	mov ss, ax			;stack segment
	mov sp, 0xFFFF			;stack pointer at 64k limit
	sti

	push dx
	push es
	xor ax, ax
	mov es, ax
	cli
	mov word [es:0x21*4], _int0x21	; setup interrupt service
	mov [es:0x21*4+2], cs
	sti
	pop es
	pop dx

	call _shell			; call the shell
	
	
	cmdMaxLen		db	255			;maximum length of commands

	
	strMajorVer		db	"0", 0x00
	strMinorVer		db	".04", 0x00

	
	txtVersion		db	"version", 0x00	;messages and other strings
	msgUnknownCmd		db	"Unknown command or bad file name!", 0x00
	
	strmemory		db	"Base Memory size: ", 0x00
	strsmallextended	db	"Extended memory between(1M - 16M): ", 0x00
	strbigextended		db      "Extended memory above 16M: ", 0x00
	strCPUVendor		db	"CPU Vendor : ", 0x00
	strCPUdescription	db	"CPU description: ", 0x00
	strNotSupported		db	"Not supported.", 0x00
	strhdnumber		db	"Number of hard drives: ",0x00
	strserialportnumber	db	"Number of serial ports: ", 0x00
	strserialport1		db	"Base I/O address for serial port 1 (communications port 1 - COM 1): ", 0x00
	strtotalmemory		db	"Total memory: ", 0x00
	exitmsg			db	"................................................................................"
	


	strUserCmd	resb	256		;buffer for user commands
	cmdChrCnt	resb	1		;count of characters
	strCmd0		resb	256		;buffers for the command components
	strCmd1		resb	256
	strCmd2		resb	256
	strCmd3		resb	256
	strCmd4		resb	256
	strVendorID	resb	16
	strBrand	resb	48
	basemem		resb	2
	extmem1		resb	2
	extmem2		resb	2

	
	
_int0x21:
	_int0x21_ser0x01:       ;service 0x01
	cmp al, 0x01            ;see if service 0x01 wanted
	jne _int0x21_end        ;goto next check (now it is end)
    
	_int0x21_ser0x01_start:
	lodsb                   ; load next character
	or  al, al              ; test for NUL character
	jz  _int0x21_ser0x01_end
	mov ah, 0x0E            ; BIOS teletype
	mov bh, 0x00            ; display page 0
	mov bl, 0x07            ; text attribute
	int 0x10                ; invoke BIOS
	jmp _int0x21_ser0x01_start
	_int0x21_ser0x01_end:
	jmp _int0x21_end

	_int0x21_end:
    	iret

_shell:
	_shell_begin:
	;move to next line
	call _display_endl
	
	
	
	; display hardware info
	_cmd_info:		
	
	
	call _display_endl
	call _display_hardware_info	;display Information

	call _display_endl
	call _display_endl
	call _display_endl
	mov si, exitmsg
	mov al, 0x01
	int 0x21

	mov byte dl, [cursor_x]			; Move cursor to user-set position
	mov byte dh, [cursor_y]
	call os_move_cursor

	call os_wait_for_key			; Get input

	cmp al, KEY_ESC				; Quit if Esc pressed
	je option_screen
	
	cursor_x	db 0			; User-set cursor position
	cursor_y	db 0
	

	ret




_display_space:
	mov ah, 0x0E                            ; BIOS teletype
	mov al, 0x20
	mov bh, 0x00                            ; display page 0
	mov bl, 0x07                            ; text attribute
	int 0x10                                ; invoke BIOS
	ret

_display_endl:
	mov ah, 0x0E		; BIOS teletype acts on newline!
	mov al, 0x0D
	mov bh, 0x00
	mov bl, 0x07
	int 0x10

	mov ah, 0x0E		; BIOS teletype acts on linefeed!
	mov al, 0x0A
	mov bh, 0x00
	mov bl, 0x07
	int 0x10
	ret


	
_display_hardware_info:			; Procedure for printing Hardware info
	
	push ax
	push bx
	push cx
	push dx
	push es
	push si

	
	call _display_endl
	call _display_endl
	
	
	mov si, strmemory	; Prints base memory string
	mov al, 0x01
	int 0x21

	; Reading Base Memory -----------------------------------------------
	push ax
	push dx
	
	int 0x12		; call interrupt 12 to get base mem size
	mov dx,ax 
	mov [basemem] , ax
	call _print_dec		; display the number in decimal
	mov al, 0x6b
        mov ah, 0x0E            ; BIOS teletype acts on 'K' 
        mov bh, 0x00
        mov bl, 0x07
        int 0x10
	
	pop dx
	pop ax

	; Reading extended Memory
	call _display_endl
        mov si, strsmallextended
        mov al, 0x01
        int 0x21

	xor cx, cx		; Clear CX
	xor dx, dx		; clear DX
	mov ax, 0xE801
	int 0x15		; call interrupt 15h
	mov dx, ax		; save memory value in DX as the procedure argument
	mov [extmem1], ax
	call _print_dec		; print the decimal value in DX
	mov al, 0x6b
        mov ah, 0x0E            ; BIOS teletype acts on 'K'
        mov bh, 0x00
        mov bl, 0x07
        int 0x10

	xor cx, cx		; clear CX
        xor dx, dx		; clear DX
        mov ax, 0xE801
        int 0x15		; call interrupt 15h
	mov ax, dx		; save memory value in AX for division
	xor dx, dx
	mov si , 16
	div si			; divide AX value to get the number of MB
	mov dx, ax
	mov [extmem2], ax
	push dx			; save dx value

	call _display_endl
        mov si, strbigextended
        mov al, 0x01
        int 0x21
	
	pop dx			; retrieve DX for printing
	call _print_dec
	mov al, 0x4D
        mov ah, 0x0E            ; BIOS teletype acts on 'M'
        mov bh, 0x00
        mov bl, 0x07
        int 0x10

	call _display_endl
	mov si, strtotalmemory
	mov al, 0x01
	int 0x21

	; total memory = basemem + extmem1 + extmem2
	mov ax, [basemem]	
	add ax, [extmem1]	; ax = ax + extmem1
	shr ax, 10
	add ax, [extmem2]	; ax = ax + extmem2
	mov dx, ax
	call _print_dec
	mov al, 0x4D            
	mov ah, 0x0E            ; BIOS teletype acts on 'M'
	mov bh, 0x00
	mov bl, 0x07
	int 0x10



	;CPU Information --------------------------------------------------------------------------
	call _display_endl
	mov si, strCPUVendor
	mov al, 0x01
	int 0x21
	mov eax, 0x00000000 	; set eax register to get the vendor
	cpuid		 	
	mov eax, ebx		; prepare for string saving
	mov ebx, edx
	mov edx, 0x00
	mov si, strVendorID
	call _save_string

	mov si, strVendorID	 ;print string
	mov al, 0x01
	int 0x21

	call _display_endl
	mov si, strCPUdescription
	mov al, 0x01
	int 0x21

	mov eax, 0x80000000		; First check if CPU support this 
	cpuid
	cmp eax, 0x80000004
	jb _cpu_not_supported		; if not supported jump to function end
	mov eax, 0x80000002		; get first part of the brand
	mov si, strBrand
	cpuid
	call _save_string
	add si, 16
	mov eax, 0x80000003		; get second part of the brand
	cpuid
	call _save_string
	add si, 16
	mov eax, 0x80000004		; get third part of the brand
	cpuid
	call _save_string

	mov si, strBrand		; print the saved Brand string
	mov al, 0x01
	int 0x21
	jmp _hard_info 

	
	;End of processor info

	_cpu_not_supported:
	mov si, strNotSupported
	mov al, 0x01
	int 0x21

	
	


	; Number of Harddrives -------------------------------------------------------------
_hard_info:
	call _display_endl
	mov si, strhdnumber
        mov al, 0x01
        int 0x21

	mov ax,0040h             ; look at 0040:0075 for a number
	mov es,ax                ;
	mov dl,[es:0075h]        ; move the number into DL register
	add dl,30h		; add 48 to get ASCII value            
	mov al, dl
        mov ah, 0x0E            ; BIOS teletype acts on character 
        mov bh, 0x00
        mov bl, 0x07
        int 0x10

_serial_ports:
	call _display_endl
	mov si, strserialportnumber
	mov al, 0x01
	int 0x21

	mov ax, [es:0x10]
	shr ax, 9
	and ax, 0x0007
	add al, 30h
	mov ah, 0x0E            ; BIOS teletype acts on character
	mov bh, 0x00
	mov bl, 0x07
	int 0x10


	; Reading base I/O addresses
	;Base I/O address for serial port 1 (communications port 1 - COM 1)
	mov ax, [es:0000h]	; Read address for serial port 1
	cmp ax, 0
	je _end
	call _display_endl
	mov si, strserialport1
        mov al, 0x01
        int 0x21	

	mov dx, ax
	call _print_dec

_end:
	;Base I/O address for serial port 1 (communications port 1 - COM 1)	
	
	call _display_endl

	pop si
        pop es
        pop dx
        pop cx
        pop bx
        pop ax

	ret

_print_dec:
	push ax			; save AX
	push cx			; save CX
	push si			; save SI
	mov ax,dx		; copy number to AX
	mov si,10		; SI is used as the divisor
	xor cx,cx		; clear CX

_non_zero:

	xor dx,dx		; clear DX
	div si			; divide by 10
	push dx			; push number onto the stack
	inc cx			; increment CX to do it more times
	or ax,ax		; clear AX
	jne _non_zero		; if not go to _non_zero

_prepare_digits:

	pop dx			; get the digit from DX
	add dl,0x30		; add 30 to get the ASCII value
	call _print_char	; print char
	loop _prepare_digits	; loop till cx == 0

	pop si			; restore SI
	pop cx			; restore CX
	pop ax			; restore AX
	ret                      

_print_char:
	push ax			; save AX 
	mov al, dl
        mov ah, 0x0E		; BIOS teletype acts on printing char
        mov bh, 0x00
        mov bl, 0x07
        int 0x10

	pop ax			; restore AX
	ret

_save_string:
	mov dword [si], eax
	mov dword [si+4], ebx
	mov dword [si+8], ecx
	mov dword [si+12], edx
	ret



; ------------------------------------------------------------------
; FEATURES -- Code to pull into the kernel


	%INCLUDE "features/keyboard.asm"
	%INCLUDE "features/screen.asm"
	


; ==================================================================
; END OF KERNEL
; ==================================================================







