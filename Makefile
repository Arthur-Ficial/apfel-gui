PREFIX ?= /usr/local
BINARY_NAME = apfel-gui

.PHONY: build install clean

build:
	swift build -c release

install: build
	@mkdir -p $(PREFIX)/bin
	@cp .build/release/$(BINARY_NAME) $(PREFIX)/bin/$(BINARY_NAME)
	@echo "Installed $(BINARY_NAME) to $(PREFIX)/bin/$(BINARY_NAME)"

clean:
	swift package clean
	rm -rf .build
