#include <stdio.h>
#include <string.h>
#include <stdlib.h>

void vuln(int a, int b) {
        if (a == 0xdeadbeef && b == 231) {
                system("/bin/sh\00");
        }
}

int main() {
        char buf[32];
        printf("Input: ");
        fgets(buf, 256, stdin);
        printf("Result: %s", buf);
        return 0;
}