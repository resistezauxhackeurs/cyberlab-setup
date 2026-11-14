#include <stdio.h>
#include <string.h>

unsigned char code[] = "" ; //insertion du shellcode

main()
{
	printf ("shellcode length: %d\n", strlen(code));
		
		int (*ret)() = (int(*)())code;
		ret();
}