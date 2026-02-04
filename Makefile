BINARY_NAME = vite
INSTALL_DIR = /usr/local/bin
MAN_DIR = /usr/local/share/man/man1

install: release
	install -d $(INSTALL_DIR)
	install -m 755 .build/release/$(BINARY_NAME) $(INSTALL_DIR)/
	install -d $(MAN_DIR)
	install -m 644 $(BINARY_NAME).1 $(MAN_DIR)/
	@echo "$(BINARY_NAME) installed to $(INSTALL_DIR)/$(BINARY_NAME)"
	@echo "$(BINARY_NAME) man page installed to $(MAN_DIR)/$(BINARY_NAME).1"
	@echo "Make sure $(INSTALL_DIR) is in your \$$PATH"

install-local: INSTALL_DIR = $(HOME)/.local/bin
install-local: MAN_DIR = $(HOME)/.local/share/man/man1
install-local: install

release:
ifeq ($(shell id -u),0)
	@if [ -n "$(SUDO_USER)" ]; then \
		sudo -u $(SUDO_USER) swift build -c release; \
	else \
		swift build -c release; \
	fi
else
	swift build -c release
endif

clean:
	swift package clean

.PHONY: install install-local release clean
