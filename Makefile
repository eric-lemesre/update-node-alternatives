# Makefile for update-node-alternative

PREFIX    ?= /usr/local
BINDIR    ?= $(PREFIX)/sbin
MANDIR    ?= $(PREFIX)/share/man/man8
PKGDIR    ?= $(PREFIX)/share/update-node-alternative
NVMDIR    ?= $(PKGDIR)/nvm
DESTDIR   ?=

INSTALL        ?= install
INSTALL_PROG   ?= $(INSTALL) -m 0755
INSTALL_DATA   ?= $(INSTALL) -m 0644
INSTALL_DIR    ?= $(INSTALL) -d -m 0755

SCRIPT     = update-node-alternative
INSTALLER  = install-node-alternative.sh
MANPAGE    = update-node-alternative.8

NVM_FILES  = vendor/nvm/nvm.sh vendor/nvm/bash_completion vendor/nvm/LICENSE.md vendor/nvm/VERSION
NVM_EXEC   = vendor/nvm/nvm-exec

SHELLCHECK ?= shellcheck

.PHONY: all help install install-nvm uninstall check man clean

all: help

help:
	@echo "Targets:"
	@echo "  make install       Install script + man page (honors DESTDIR, PREFIX)"
	@echo "  make install-nvm   Run install-node-alternative.sh (needs root)"
	@echo "  make uninstall     Remove installed script + man page"
	@echo "  make check         Run shellcheck on shell scripts"
	@echo "  make man           Show the man page"
	@echo "  make clean         Remove generated artifacts"
	@echo
	@echo "Variables: PREFIX=$(PREFIX)  BINDIR=$(BINDIR)  MANDIR=$(MANDIR)"

install:
	$(INSTALL_DIR) $(DESTDIR)$(BINDIR)
	$(INSTALL_DIR) $(DESTDIR)$(MANDIR)
	$(INSTALL_DIR) $(DESTDIR)$(NVMDIR)
	$(INSTALL_PROG) $(SCRIPT)   $(DESTDIR)$(BINDIR)/$(SCRIPT)
	$(INSTALL_DATA) $(MANPAGE)  $(DESTDIR)$(MANDIR)/$(MANPAGE)
	$(INSTALL_DATA) $(NVM_FILES) $(DESTDIR)$(NVMDIR)/
	$(INSTALL_PROG) $(NVM_EXEC)  $(DESTDIR)$(NVMDIR)/nvm-exec

install-nvm:
	@if [ "$$(id -u)" -ne 0 ]; then \
	    echo "install-nvm: root privileges required (use sudo)"; exit 1; \
	fi
	./$(INSTALLER)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(SCRIPT)
	rm -f $(DESTDIR)$(MANDIR)/$(MANPAGE)
	rm -rf $(DESTDIR)$(NVMDIR)
	rmdir --ignore-fail-on-non-empty $(DESTDIR)$(PKGDIR) 2>/dev/null || true

check:
	@command -v $(SHELLCHECK) >/dev/null 2>&1 || { \
	    echo "shellcheck not found. Install with: sudo apt install shellcheck"; exit 1; \
	}
	$(SHELLCHECK) --shell=bash $(SCRIPT) $(INSTALLER)

man:
	@command -v man >/dev/null 2>&1 || { echo "man not found"; exit 1; }
	man ./$(MANPAGE)

clean:
	@:
