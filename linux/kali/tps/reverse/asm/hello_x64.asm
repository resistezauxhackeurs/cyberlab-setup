global _start
section .text
_start:
	mov rax, 1 ; sys_write
	mov rdi, 1 ; stdout
	mov rsi, message
	mov rdx, 13
	syscall
	mov rax, 60 ; sys_exit
	xor rdi, rdi
	syscall
section .data
	message: db "Hello, World", 10