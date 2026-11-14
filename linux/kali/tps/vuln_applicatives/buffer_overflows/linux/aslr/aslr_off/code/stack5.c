#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>

#define welcome "Session open...\n"
#define bye "Session end...\n"

void process(int s)
{
	char buffer[255];
	dup2(s, 0);
	dup2(s, 1);
	dup2(s, 2);
	read(s, buffer, 1024);
}

int main(void)
{
	int s = 0;
	struct sockaddr_in h;

	bzero(&h, sizeof(h));

	if((s = socket(AF_INET, SOCK_STREAM, 0)) >= 0)
	{
		h.sin_port = htons(8888);
		h.sin_family = AF_INET;
		h.sin_addr.s_addr = htonl(INADDR_ANY);
		
		if(bind(s, (struct sockaddr *)&h, sizeof(h)) == 0)
		{
			if(listen(s, 20) == 0)
			{
				while(1)
				{
					int c = accept(s, NULL, NULL);

					switch(fork())
					{
						case -1:
							break;

						case 0:
							close(s);
							write(c, welcome, strlen(welcome));
							process(c);
							write(c, bye, strlen(bye));
							exit(0);
						default:
							close(c);
							wait(NULL);
					}
				}
			}	
		}
	}	
}
