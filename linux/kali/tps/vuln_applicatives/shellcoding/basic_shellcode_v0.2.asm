section .text
	global _start
	
_start:
	xor eax, eax ; eax = 0
	push eax ; 
	push 0x68732f2f; ascii sh//
	push 0x6e69622f; ascii nib/
	; comme la pile fait 4 octets, on pousse /bin//sh
	
	mov ebx, esp
	mov ecx, eax ; copy eax à 0 dans ecx

	mov al, 0xb ; on met 11 dans al
	int 0x80