PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
UNITDIR ?= $(PREFIX)/lib/systemd/user
DOCDIR  ?= $(PREFIX)/share/doc/played

.PHONY: all install uninstall lint test user-install user-uninstall

all:
	@echo "make install            # system-wide (PREFIX=$(PREFIX))"
	@echo "make user-install       # ~/.local/bin + ~/.config/systemd/user"
	@echo "make lint               # shellcheck"

install:
	install -Dm755 bin/played             $(DESTDIR)$(BINDIR)/played
	install -Dm644 systemd/played.service $(DESTDIR)$(UNITDIR)/played.service
	install -Dm644 README.md              $(DESTDIR)$(DOCDIR)/README.md
	install -Dm644 LICENSE                $(DESTDIR)$(DOCDIR)/LICENSE
	install -Dm644 examples/config.example $(DESTDIR)$(DOCDIR)/config.example

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/played
	rm -f $(DESTDIR)$(UNITDIR)/played.service
	rm -rf $(DESTDIR)$(DOCDIR)

user-install:
	install -Dm755 bin/played             $(HOME)/.local/bin/played
	install -Dm644 systemd/played.service $(HOME)/.config/systemd/user/played.service
	@echo "installed. enable with:  systemctl --user enable --now played"

user-uninstall:
	rm -f $(HOME)/.local/bin/played
	rm -f $(HOME)/.config/systemd/user/played.service

lint:
	shellcheck -x bin/played

test:
	bash tests/test-sanitize.sh
