#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

#define BUF_LEN 2048


void vulnerable(int fd, size_t size);

int main(int argc, const char* argv[])
{
  if(argc < 2)
  {
    fprintf(stderr, "Usage: %s <file>\n", argv[0]);
    exit(EXIT_FAILURE);
  }


  int fd = open(argv[1], O_RDONLY);
  if(fd < 0)
  {
    perror("open()");
    exit(EXIT_FAILURE);
  }

  struct stat st;
  if(fstat(fd, &st) < 0)
  {
    perror("fstat()");
    close(fd);
    exit(EXIT_FAILURE);
  }

  vulnerable(fd, st.st_size);  

  close(fd);

  return EXIT_SUCCESS;
}

void vulnerable(int fd, size_t size)
{
  char buf[BUF_LEN];
  size_t i;
  for(i = 0; i < size; i += BUF_LEN)
  {
    read(fd, buf + i, BUF_LEN);
  }
}
