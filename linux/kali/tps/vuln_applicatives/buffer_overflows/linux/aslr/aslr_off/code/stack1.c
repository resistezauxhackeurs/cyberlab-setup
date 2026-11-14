#include <stdio.h>
#include <stdlib.h>

int main(void)
{
	int condition = 0;
	char buffer[32] = {0};

	printf("Enter your name: ");

	scanf("%s", buffer);

	printf("Hello, %s !\n", buffer);

	if(condition == 0xdeadbeef)
	{
		puts("Congratulations ! You succeed !");
	}

	else if(condition != 0)
	{
		puts("You are on the rigth way !");
	}

	return 0;
}
