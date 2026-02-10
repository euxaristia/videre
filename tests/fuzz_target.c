#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>

// AFL fuzz target for videre - tests file loading operations
__attribute__((section(".text")))
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    // Create temporary file with fuzz data
    char temp_file[] = "/tmp/fuzz_videre_XXXXXX";
    int fd = mkstemp(temp_file);
    if (fd == -1) return 0;
    
    // Write fuzz data to temp file
    write(fd, data, size);
    close(fd);
    
    // Test videre with the fuzz data as input file
    // We'll run videre with the file and immediately quit
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "echo ':q' | timeout 1s ./videre '%s' >/dev/null 2>&1", temp_file);
    
    // Run videre with the fuzz input
    system(cmd);
    
    // Cleanup
    unlink(temp_file);
    
    return 0;
}

// Dummy main for AFL (won't be used during fuzzing)
int main() {
    return 0;
}