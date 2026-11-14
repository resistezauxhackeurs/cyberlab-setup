#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void get_name(void)
{
	char buffer[255];
	read(0, buffer, 1024);
}

int main(void)
{
	get_name();
	return 0;
}
