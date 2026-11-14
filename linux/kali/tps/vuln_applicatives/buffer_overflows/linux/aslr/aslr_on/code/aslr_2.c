#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void echo(void)
{
	char buffer[57] = {0};
	int n = read(0, buffer, 255);
	puts(buffer);
}

int main(void)
{
	echo();
	return 0;
}
