global _start
section .text
_start:
	mov eax, xxxx
	mov ebx, xxxxx
	mov ecx, xxxxxx
	mov edx, xxxxxx
	int 0x80
	mov eax, 1 ; sys_exit
	xor ebx, ebx
	int 0x80
section .data
	message: db "Hello, World", 10