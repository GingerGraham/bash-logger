# bash-logger Makefile

# Installation directories
PREFIX ?= /usr/local
DESTDIR ?=
BINDIR = $(PREFIX)/lib/bash-logger
DOCDIR = $(PREFIX)/share/doc/bash-logger

# User installation directories
USER_PREFIX ?= $(HOME)/.local
USER_BINDIR = $(USER_PREFIX)/lib/bash-logger
USER_DOCDIR = $(USER_PREFIX)/share/doc/bash-logger

# Files to install
LIBRARY = logging.sh
DOCS = README.md LICENSE CHANGELOG.md

# Shell for execution
SHELL := /bin/bash

.PHONY: all help install install-user uninstall uninstall-user test lint lint-shell lint-markdown check demo demos clean pre-commit

all: help

help:
	@echo "bash-logger - Installation and development targets"
	@echo ""
	@echo "Installation targets:"
	@echo "  make install         Install system-wide (requires root/sudo)"
	@echo "  make install-user    Install for current user only"
	@echo "  make uninstall       Remove system-wide installation"
	@echo "  make uninstall-user  Remove user installation"
	@echo ""
	@echo "Development targets:"
	@echo "  make test            Run test suite"
	@echo "  make demo            Run all demo scripts"
	@echo "  make lint            Run all linters (shellcheck + markdownlint)"
	@echo "  make lint-shell      Run shellcheck only"
	@echo "  make lint-markdown   Run markdownlint only"
	@echo "  make check           Run tests and all linters"
	@echo "  make pre-commit      Run pre-commit hooks on all files"
	@echo "  make clean           Remove temporary files"
	@echo ""
	@echo "Installation options:"
	@echo "  PREFIX=/path         Change installation prefix (default: /usr/local)"
	@echo "  USER_PREFIX=/path    Change user prefix (default: ~/.local)"
	@echo ""
	@echo "Examples:"
	@echo "  make install PREFIX=/opt"
	@echo "  sudo make install"
	@echo "  make install-user"
	@echo "  make check           # Run before committing"

install:
	@echo "Installing bash-logger to $(DESTDIR)$(BINDIR)..."
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 644 "$(LIBRARY)" "$(DESTDIR)$(BINDIR)/$(LIBRARY)"
	@if [ -d docs ]; then \
		echo "Installing documentation to $(DESTDIR)$(DOCDIR)..."; \
		install -d "$(DESTDIR)$(DOCDIR)"; \
		for doc in $(DOCS); do \
			if [ -f "$$doc" ]; then \
				install -m 644 "$$doc" "$(DESTDIR)$(DOCDIR)/"; \
			fi; \
		done; \
	fi
	@echo ""
	@echo "Installation complete!"
	@echo ""
	@echo "To use bash-logger, add this to your script:"
	@echo "  source $(PREFIX)/lib/bash-logger/logging.sh"
	@echo ""
	@echo "Or add to your ~/.bashrc:"
	@echo "  source $(PREFIX)/lib/bash-logger/logging.sh"

install-user:
	@echo "Installing bash-logger to $(USER_BINDIR)..."
	install -d "$(USER_BINDIR)"
	install -m 644 "$(LIBRARY)" "$(USER_BINDIR)/$(LIBRARY)"
	@if [ -d docs ]; then \
		echo "Installing documentation to $(USER_DOCDIR)..."; \
		install -d "$(USER_DOCDIR)"; \
		for doc in $(DOCS); do \
			if [ -f "$$doc" ]; then \
				install -m 644 "$$doc" "$(USER_DOCDIR)/"; \
			fi; \
		done; \
	fi
	@echo ""
	@echo "Installation complete!"
	@echo ""
	@echo "To use bash-logger, add this to your script:"
	@echo "  source $(USER_PREFIX)/lib/bash-logger/logging.sh"
	@echo ""
	@echo "Or add to your ~/.bashrc:"
	@echo "  source $(USER_PREFIX)/lib/bash-logger/logging.sh"

uninstall:
	@echo "Removing bash-logger installation from $(DESTDIR)$(PREFIX)..."
	rm -f "$(DESTDIR)$(BINDIR)/$(LIBRARY)"
	rmdir "$(DESTDIR)$(BINDIR)" 2>/dev/null || true
	rm -rf "$(DESTDIR)$(DOCDIR)"
	@echo "Uninstall complete!"

uninstall-user:
	@echo "Removing bash-logger installation from $(USER_PREFIX)..."
	rm -f "$(USER_BINDIR)/$(LIBRARY)"
	rmdir "$(USER_BINDIR)" 2>/dev/null || true
	rm -rf "$(USER_DOCDIR)"
	@echo "Uninstall complete!"

test:
	@if [ -d tests ]; then \
		echo "Running test suite..."; \
		if [ -f tests/run_tests.sh ]; then \
			if [ ! -x tests/run_tests.sh ]; then \
				chmod +x tests/run_tests.sh; \
			fi; \
			./tests/run_tests.sh; \
		elif command -v bats >/dev/null 2>&1; then \
			bats tests/; \
		else \
			echo "No test runner found. Install bats or create tests/run_tests.sh"; \
			exit 1; \
		fi; \
	else \
		echo "No tests directory found"; \
		exit 1; \
	fi

demo: demos

demos:
	@if [ -d demo-scripts ]; then \
		echo "Running demo scripts..."; \
		if [ -f demo-scripts/run_demos.sh ]; then \
			if [ ! -x demo-scripts/run_demos.sh ]; then \
				chmod +x demo-scripts/run_demos.sh; \
			fi; \
			./demo-scripts/run_demos.sh; \
		else \
			echo "Error: demo-scripts/run_demos.sh not found"; \
			exit 1; \
		fi; \
	else \
		echo "No demo-scripts directory found"; \
		exit 1; \
	fi

lint-shell:
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		echo "Error: pre-commit not found."; \
		echo "Install with: pip install pre-commit"; \
		exit 1; \
	fi
	@echo "Running shellcheck (via pre-commit)..."
	@pre-commit run shellcheck --all-files

lint-markdown:
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		echo "Error: pre-commit not found."; \
		echo "Install with: pip install pre-commit"; \
		exit 1; \
	fi
	@echo "Running markdownlint (via pre-commit)..."
	@pre-commit run markdownlint --all-files

lint: lint-shell lint-markdown
	@echo ""
	@echo "✓ All linting passed!"

pre-commit:
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		echo "Error: pre-commit not found."; \
		echo "Install with: pip install pre-commit"; \
		exit 1; \
	fi
	@echo "Running pre-commit hooks on all files..."
	@pre-commit run --all-files

check: lint test
	@echo ""
	@echo "✓ All checks passed!"

clean:
	@echo "Cleaning temporary files..."
	@find . -name "*.log" -type f -delete 2>/dev/null || true
	@find . -name "*~" -type f -delete 2>/dev/null || true
	@find . -name ".*.swp" -type f -delete 2>/dev/null || true
	@echo "✓ Clean complete!"