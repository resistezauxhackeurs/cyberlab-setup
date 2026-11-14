#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void get_name(void)
{
	char buffer[50] = {0};
	read(0, buffer, 256);
}

int main(void)
{
	puts("This time I won't give you a shell function!");
	get_name();
	return 0;
}
