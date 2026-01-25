BINARY_NAME = vite
INSTALL_DIR = $(HOME)/.local/bin

install: release
	install -d $(INSTALL_DIR)
	install -m 755 .build/release/$(BINARY_NAME) $(INSTALL_DIR)/
	@echo "$(BINARY_NAME) installed to $(INSTALL_DIR)/$(BINARY_NAME)"
	@echo "Make sure $(INSTALL_DIR) is in your \$$PATH"

release:
	swift build -c release

clean:
	swift package clean

.PHONY: install release clean
