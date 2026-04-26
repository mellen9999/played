PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
LIBDIR  ?= $(PREFIX)/lib/played
UNITDIR ?= $(PREFIX)/lib/systemd/user
DOCDIR  ?= $(PREFIX)/share/doc/played

.PHONY: all install uninstall lint test user-install user-uninstall

all:
	@echo "make install            # system-wide (PREFIX=$(PREFIX))"
	@echo "make user-install       # ~/.local/bin + ~/.local/lib + ~/.config/systemd/user"
	@echo "make lint               # shellcheck + python compile"
	@echo "make test               # run unit tests"

install:
	install -Dm755 bin/played             $(DESTDIR)$(BINDIR)/played
	install -Dm755 lib/played-match       $(DESTDIR)$(LIBDIR)/played-match
	install -Dm755 lib/played-cover       $(DESTDIR)$(LIBDIR)/played-cover
	install -Dm644 systemd/played.service $(DESTDIR)$(UNITDIR)/played.service
	install -Dm644 README.md              $(DESTDIR)$(DOCDIR)/README.md
	install -Dm644 LICENSE                $(DESTDIR)$(DOCDIR)/LICENSE
	install -Dm644 examples/config.example $(DESTDIR)$(DOCDIR)/config.example

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/played
	rm -rf $(DESTDIR)$(LIBDIR)
	rm -f $(DESTDIR)$(UNITDIR)/played.service
	rm -rf $(DESTDIR)$(DOCDIR)

user-install:
	install -Dm755 bin/played             $(HOME)/.local/bin/played
	install -Dm755 lib/played-match       $(HOME)/.local/lib/played/played-match
	install -Dm755 lib/played-cover       $(HOME)/.local/lib/played/played-cover
	install -Dm644 systemd/played.service $(HOME)/.config/systemd/user/played.service
	@echo "installed. enable with:  systemctl --user enable --now played"

user-uninstall:
	rm -f $(HOME)/.local/bin/played
	rm -rf $(HOME)/.local/lib/played
	rm -f $(HOME)/.config/systemd/user/played.service

lint:
	shellcheck -x bin/played
	python3 -m py_compile lib/played-match lib/played-cover

test:
	bash tests/test-sanitize.sh
	bash tests/test-match.sh
