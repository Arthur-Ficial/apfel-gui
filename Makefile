PREFIX ?= /usr/local
BINARY_NAME = apfel-gui

.PHONY: build install clean

build:
	swift build -c release

install: build
	@mkdir -p $(PREFIX)/bin
	@cp .build/release/$(BINARY_NAME) $(PREFIX)/bin/$(BINARY_NAME)
	@mkdir -p $(PREFIX)/share/apfel-gui/mcp/debug-tools
	@cp mcp/debug-tools/server.py $(PREFIX)/share/apfel-gui/mcp/debug-tools/server.py
	@chmod +x $(PREFIX)/share/apfel-gui/mcp/debug-tools/server.py
	@echo "Installed $(BINARY_NAME) to $(PREFIX)/bin/$(BINARY_NAME)"
	@echo "Installed MCP debug-tools to $(PREFIX)/share/apfel-gui/mcp/debug-tools/"

clean:
	swift package clean
	rm -rf .build
