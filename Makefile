CC = gcc
CFLAGS = -Wall -Wextra -Iinclude -O2
TARGET = videre

SRC = src/main.c src/terminal.c src/fileio.c src/buffer.c src/rows.c src/search.c src/syntax.c
OBJ = $(SRC:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(OBJ) -o $(TARGET)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) $(TARGET)

.PHONY: all clean