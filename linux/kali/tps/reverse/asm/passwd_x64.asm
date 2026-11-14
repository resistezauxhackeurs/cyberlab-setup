global _start
section .text
_start:
	mov rax, 0 ; sys_read
	mov rdi, 1 ; stdout
	mov rsi, fichier
	mov rdx, 13
	syscall
	mov rax, 60 ; sys_exit
	xor rdi, rdi
	syscall
section .data
	fichier: db "/etc/passwd", 10