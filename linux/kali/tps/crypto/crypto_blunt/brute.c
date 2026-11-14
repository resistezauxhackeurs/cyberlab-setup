#include <stdio.h>


unsigned long mod_pow(unsigned long base, unsigned long expo, unsigned long mod) {
    unsigned long result = 1;
    base = base % mod; // Ensure base is within the modulus

    while (expo > 0) {
        // If exp is odd, multiply result with base and take the remainder with mod
        if (expo % 2 == 1)
            result = (result * base) % mod;

        // exp must be even now
        expo = expo >> 1; // Divide exp by 2
        base = (base * base) % mod;
    }

    return result;
}

int main() {
    unsigned long p = 0xdd6cc28d;
    unsigned long g = 0x83e21c05;
    unsigned long A = 0xcfabb6dd;
    unsigned long B = 0xc4a21ba9;

    // Brute force for a
    for (unsigned long a = 1; a < p; ++a) {
        if (mod_pow(g, a, p) == A) {
            printf("a = %lu\n", a);
            break;
        }
    }

    // Brute force for b
    for (unsigned long b = 1; b < p; ++b) {
        if (mod_pow(g, b, p) == B) {
            printf("b = %lu\n", b);
            break;
        }
    }

    return 0;
}
