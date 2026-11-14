#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void get_name(void)
{
	char buffer_b[32] = {0};
	char buffer_a[255] = {0};
	fgets(buffer_a, 128, stdin); // N0 0V3RFL0W
	strncpy(buffer_b, buffer_a, strlen(buffer_a));
}

int main(void)
{
	printf("Ahaha! This time the stack isn't executable!\n");
	get_name();
	return 0;
}
