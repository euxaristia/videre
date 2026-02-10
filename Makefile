CC = gcc
CFLAGS = -Wall -Wextra -Iinclude -O2
TARGET = videre

SRC = src/main.c src/terminal.c src/fileio.c src/buffer.c src/rows.c src/search.c src/syntax.c src/edit.c src/undo.c src/core.c
OBJ = $(SRC:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(OBJ) -o $(TARGET)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

test: src/fileio.o src/buffer.o src/rows.o src/search.o src/syntax.o src/edit.o src/undo.o src/core.o tests/mocks.c tests/test_videre.c
	$(CC) $(CFLAGS) $^ -o run_tests
	./run_tests

# Security tests (standalone)
security-test: tests/security_tests.c
	$(CC) $(CFLAGS) -g -fsanitize=address,undefined $^ -o security_tests
	./security_tests

# Fuzzing target (AFL)
fuzz-target: tests/fuzz_target.c
	$(CC) $(CFLAGS) -g -fsanitize=address,undefined $^ -o fuzz_target

# Security testing with AFL
fuzz-setup:
	@echo "Setting up AFL fuzzing..."
	@if ! command -v afl-fuzz &> /dev/null; then \
		echo "Installing AFL..."; \
		sudo apt-get update && sudo apt-get install -y afl++; \
	fi
	mkdir -p fuzz/input fuzz/output
	@echo "Creating seed files..."
	echo "Hello, World!" > fuzz/input/seed1.txt
	echo "Line 1\nLine 2\nLine 3" > fuzz/input/seed2.txt
	echo "" > fuzz/input/empty.txt
	echo -e "\x1b[31mColored text\x1b[0m" > fuzz/input/ansi.txt
	echo -e "Tab\tseparated\ttext" > fuzz/input/tabs.txt
	echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAA" > fuzz/input/long_line.txt
	echo -ne "\x00\x01\x02\x03\x04\x05" > fuzz/input/binary1.bin
	echo -ne "\xff\xfe\xfd\xfc\xfb\xfa" > fuzz/input/binary2.bin
	echo -ne "\x1b[A\x1b[B\x1b[C\x1b[D" > fuzz/input/escape_sequences.bin
	head -c 10000 /dev/urandom | tr -d '\0' > fuzz/input/large_random.txt
	echo -e "$(printf 'A%.0s' {1..1000})\n$(printf 'B%.0s' {1..1000})" > fuzz/input/buffer_overflow.txt

fuzz-build:
	@echo "Building with AFL instrumentation..."
	make clean
	CC=afl-clang-fast CFLAGS="-Wall -Wextra -Iinclude -O2 -g -fsanitize=address,undefined" make $(TARGET)
	afl-clang-fast -Wall -Wextra -Iinclude -O2 -g -fsanitize=address,undefined \
		tests/fuzz_target.c -o fuzz/fuzz_target

fuzz-run: fuzz-build
	@echo "Starting AFL fuzzing (this will run for a long time)..."
	afl-fuzz -i fuzz/input -o fuzz/output -- fuzz/fuzz_target

fuzz-parallel: fuzz-build
	@echo "Starting parallel AFL fuzzing on multiple cores..."
	@echo "Run this in multiple terminals:"
	@echo "  afl-fuzz -i fuzz/input -o fuzz/output -M fuzzer01 -- fuzz/fuzz_target"
	@echo "  afl-fuzz -i fuzz/input -o fuzz/output -S fuzzer02 -- fuzz/fuzz_target"
	@echo "  afl-fuzz -i fuzz/input -o fuzz/output -S fuzzer03 -- fuzz/fuzz_target"

fuzz-analyze:
	@if [ -d "fuzz/output" ]; then \
		echo "AFL fuzzing statistics:"; \
		afl-whatsup fuzz/output; \
		echo ""; \
		echo "Crash files found:"; \
		ls -la fuzz/output/*/crashes/ 2>/dev/null || echo "No crashes found"; \
	else \
		echo "No fuzz output found. Run 'make fuzz-run' first."; \
	fi

# Static analysis for security
security-scan:
	@echo "Running security scans..."
	@if command -v cppcheck &> /dev/null; then \
		echo "Running cppcheck..."; \
		cppcheck --enable=all --std=c99 src/; \
	fi
	@if command -v scan-build &> /dev/null; then \
		echo "Running clang static analyzer..."; \
		scan-build make clean && scan-build make; \
	fi

# Memory error detection
memcheck: $(TARGET)
	@if command -v valgrind &> /dev/null; then \
		echo "Running valgrind..."; \
		echo "test" | timeout 10s valgrind --leak-check=full --show-leak-kinds=all ./$(TARGET) || true; \
	else \
		echo "Valgrind not installed. Install with: sudo apt-get install valgrind"; \
	fi

clean:
	rm -f $(OBJ) $(TARGET) run_tests fuzz/fuzz_target
	rm -rf fuzz/output

.PHONY: all clean test fuzz-setup fuzz-build fuzz-run fuzz-parallel fuzz-analyze security-scan memcheck