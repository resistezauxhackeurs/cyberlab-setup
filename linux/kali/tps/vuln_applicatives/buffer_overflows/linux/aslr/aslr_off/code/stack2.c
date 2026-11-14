#include <stdio.h>
#include <stdlib.h>

void shell(void)
{
	system("/bin/sh");
}

void get_name(void)
{
	char buffer[32] = {0};
	scanf("%s", buffer);
}

int main(void)
{
	get_name();
	return 0;
}
