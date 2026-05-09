# Makefile for update-node-alternatives

PREFIX    ?= /usr/local
BINDIR    ?= $(PREFIX)/sbin
MANDIR    ?= $(PREFIX)/share/man/man8
PKGDIR    ?= $(PREFIX)/share/update-node-alternatives
NVMDIR    ?= $(PKGDIR)/nvm
PROFILED  ?= /etc/profile.d
DESTDIR   ?=

# Skip the man page when set to 0. Used by debian/rules so dh_installman
# can pick up the page from debian/manpages instead.
INSTALL_MAN ?= 1

INSTALL        ?= install
INSTALL_PROG   ?= $(INSTALL) -m 0755
INSTALL_DATA   ?= $(INSTALL) -m 0644
INSTALL_DIR    ?= $(INSTALL) -d -m 0755

SCRIPT     = update-node-alternatives
MANPAGE    = update-node-alternatives.8
PROFILE_SH = profile.d/update-node-alternatives.sh

NVM_FILES  = vendor/nvm/nvm.sh vendor/nvm/bash_completion vendor/nvm/LICENSE.md vendor/nvm/VERSION
NVM_EXEC   = vendor/nvm/nvm-exec

SHELLCHECK ?= shellcheck

.PHONY: all help install uninstall purge check man clean deb deb-clean check-upstream vendor-nvm vendor-nvm-show

all: help

help:
	@echo "Targets:"
	@echo "  make install       Install script + man page (honors DESTDIR, PREFIX)"
	@echo "  make uninstall     Remove installed script + man page"
	@echo "  make purge         uninstall + drop alternatives + /usr/local/share/nvm/"
	@echo "  make check         Run shellcheck on shell scripts"
	@echo "  make man           Show the man page"
	@echo "  make clean         Remove generated artifacts"
	@echo "  make deb           Build the Debian package into ../"
	@echo "  make deb-clean     Clean Debian build artifacts"
	@echo "  make check-upstream  Check upstream releases via uscan (debian/watch)"
	@echo "  make vendor-nvm-show Show currently bundled nvm version"
	@echo "  make vendor-nvm NVM_VERSION=X.Y.Z  Refresh vendor/nvm/ to a new version"
	@echo
	@echo "Variables: PREFIX=$(PREFIX)  BINDIR=$(BINDIR)  MANDIR=$(MANDIR)"

install:
	$(INSTALL_DIR) $(DESTDIR)$(BINDIR)
	$(INSTALL_DIR) $(DESTDIR)$(NVMDIR)
	$(INSTALL_DIR) $(DESTDIR)$(PROFILED)
	$(INSTALL_PROG) $(SCRIPT)    $(DESTDIR)$(BINDIR)/$(SCRIPT)
	$(INSTALL_DATA) $(NVM_FILES) $(DESTDIR)$(NVMDIR)/
	$(INSTALL_PROG) $(NVM_EXEC)  $(DESTDIR)$(NVMDIR)/nvm-exec
	$(INSTALL_DATA) $(PROFILE_SH) $(DESTDIR)$(PROFILED)/$(SCRIPT).sh
ifneq ($(INSTALL_MAN),0)
	$(INSTALL_DIR) $(DESTDIR)$(MANDIR)
	$(INSTALL_DATA) $(MANPAGE)  $(DESTDIR)$(MANDIR)/$(MANPAGE)
endif

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(SCRIPT)
	rm -f $(DESTDIR)$(PROFILED)/$(SCRIPT).sh
	rm -rf $(DESTDIR)$(NVMDIR)
	rmdir --ignore-fail-on-non-empty $(DESTDIR)$(PKGDIR) 2>/dev/null || true
ifneq ($(INSTALL_MAN),0)
	rm -f $(DESTDIR)$(MANDIR)/$(MANPAGE)
endif

# Full removal: also drop update-alternatives entries and the
# /usr/local/share/nvm/ store (every installed Node.js version).
# Intended for the manual install path; the Debian package uses
# `apt purge` plus the appropriate maintainer scripts instead.
purge:
	@if [ "$$(id -u)" -ne 0 ]; then \
	    echo "purge: root privileges required (use sudo)"; exit 1; \
	fi
	@echo "WARNING: this will:"
	@echo "  - remove update-alternatives entries for node, npm, npx, corepack"
	@echo "  - delete /usr/local/share/nvm/ (every installed Node.js version)"
	@printf "Continue? [y/N] "; \
	read ans; \
	case "$$ans" in [yY]*) ;; *) echo "Aborted."; exit 1 ;; esac; \
	$(MAKE) uninstall; \
	for alt in node npm npx corepack; do \
	    update-alternatives --remove-all $$alt 2>/dev/null || true; \
	done; \
	rm -rf /usr/local/share/nvm; \
	echo "Purge complete."

check:
	@command -v $(SHELLCHECK) >/dev/null 2>&1 || { \
	    echo "shellcheck not found. Install with: sudo apt install shellcheck"; exit 1; \
	}
	$(SHELLCHECK) --shell=bash $(SCRIPT)

man:
	@command -v man >/dev/null 2>&1 || { echo "man not found"; exit 1; }
	man ./$(MANPAGE)

clean:
	@:

deb:
	dpkg-buildpackage -us -uc -b

deb-clean:
	fakeroot debian/rules clean
	rm -f ../$(SCRIPT)_*.deb ../$(SCRIPT)_*.changes ../$(SCRIPT)_*.buildinfo

check-upstream:
	@command -v uscan >/dev/null 2>&1 || { \
	    echo "uscan not found. Install with: sudo apt install devscripts"; exit 1; \
	}
	uscan --no-download --report --verbose

vendor-nvm-show:
	@echo "Bundled nvm: $$(cat vendor/nvm/VERSION 2>/dev/null || echo '<missing>')"

vendor-nvm:
	@if [ -z "$(NVM_VERSION)" ]; then \
	    echo "Usage: make vendor-nvm NVM_VERSION=X.Y.Z"; \
	    echo "Currently bundled: $$(cat vendor/nvm/VERSION 2>/dev/null || echo '<none>')"; \
	    exit 1; \
	fi
	./debian/vendor-nvm.sh $(NVM_VERSION)
