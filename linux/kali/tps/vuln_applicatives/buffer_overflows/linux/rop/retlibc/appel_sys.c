#include <stdlib.h>

int main(void) {
    char command[] = "/bin/sh";
    system(command);
    return EXIT_SUCCESS;
}