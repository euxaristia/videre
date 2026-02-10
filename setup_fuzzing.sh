#!/bin/bash

# AFL fuzzing setup script for videre
set -e

echo "Setting up AFL fuzzing for videre..."

# Check if AFL is installed
if ! command -v afl-fuzz &> /dev/null; then
    echo "AFL not found. Installing AFL..."
    sudo apt-get update
    sudo apt-get install -y afl++
fi

# Create fuzzing directories
mkdir -p fuzz/input fuzz/output

# Create initial seed files for fuzzing
echo "Creating seed files..."

# Text files with various content
echo "Hello, World!" > fuzz/input/seed1.txt
echo "Line 1\nLine 2\nLine 3" > fuzz/input/seed2.txt
echo "" > fuzz/input/empty.txt
echo -e "\x1b[31mColored text\x1b[0m" > fuzz/input/ansi.txt
echo -e "Tab\tseparated\ttext" > fuzz/input/tabs.txt
echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAA" > fuzz/input/long_line.txt

# Binary files with edge cases
echo -ne "\x00\x01\x02\x03\x04\x05" > fuzz/input/binary1.bin
echo -ne "\xff\xfe\xfd\xfc\xfb\xfa" > fuzz/input/binary2.bin
echo -ne "\x1b[A\x1b[B\x1b[C\x1b[D" > fuzz/input/escape_sequences.bin

# Large file
head -c 10000 /dev/urandom | tr -d '\0' > fuzz/input/large_random.txt

# Special files for testing specific vulnerabilities
echo -e "$(printf 'A%.0s' {1..1000})\n$(printf 'B%.0s' {1..1000})" > fuzz/input/buffer_overflow.txt
echo -e "$(python3 -c 'print("A"*10000 + "\x00\x00\x00\x00")')" > fuzz/input/heap_overflow.txt

echo "Seed files created in fuzz/input/"

# Build videre with AFL instrumentation
echo "Building videre with AFL instrumentation..."
make clean

# Use AFL compiler for instrumentation
CC=afl-clang-fast CFLAGS="-Wall -Wextra -Iinclude -O2 -g -fsanitize=address,undefined" make videre

# Build fuzz target
echo "Building fuzz target..."
afl-clang-fast -Wall -Wextra -Iinclude -O2 -g -fsanitize=address,undefined \
    tests/fuzz_target.c src/core.c src/rows.c src/fileio.c src/search.c \
    src/syntax.c src/edit.c src/undo.c src/buffer.c -o fuzz/fuzz_target

echo "Setup complete! To run fuzzing:"
echo "  afl-fuzz -i fuzz/input -o fuzz/output -- fuzz/fuzz_target"
echo ""
echo "For parallel fuzzing (multiple cores):"
echo "  afl-fuzz -i fuzz/input -o fuzz/output -M fuzzer01 -- fuzz/fuzz_target"
echo "  afl-fuzz -i fuzz/input -o fuzz/output -S fuzzer02 -- fuzz/fuzz_target"
echo ""
echo "To analyze crashes:"
echo "  afl-whatsup fuzz/output"
echo "  gdb -ex 'run' -ex 'bt' -- fuzz/fuzz_target < fuzz/output/default/crashes/id:000000*"