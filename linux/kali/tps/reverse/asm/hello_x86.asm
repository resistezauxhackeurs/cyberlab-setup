global _start
section .text
_start:
	mov eax, 4 ; sys_write
	mov ebx, 1 ; stdout
	mov ecx, message
	mov edx, 13
	int 0x80
	mov eax, 1 ; sys_exit
	xor ebx, ebx
	int 0x80
section .data
	message: db "Hello, World", 10