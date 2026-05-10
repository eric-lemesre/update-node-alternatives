# update-node-alternatives

[English](../README.md) | [Français](README.fr.md) | **Deutsch** | [Español](README.es.md) | [Italiano](README.it.md) | [Português (Brasil)](README.pt_BR.md)

Ein systemweiter Node.js-Versionsmanager für Debian, im Stil von
[`update-java-alternatives(8)`](https://manpages.debian.org/update-java-alternatives).

Er kombiniert die [NVM](https://github.com/nvm-sh/nvm)-Infrastruktur
(zum Herunterladen und Speichern der Node.js-Binärdateien) mit dem
[`update-alternatives(1)`](https://manpages.debian.org/update-alternatives)-Mechanismus
von Debian (zum Umschalten des systemweiten `node`-Symlinks — die
Slaves wie `npm`, `npx`, `corepack` sowie alle Binärdateien, die
`sudo npm install -g` für diese Version ablegt, werden dynamisch
erkannt). Ein debconf-artiges interaktives Frontend wird über
`whiptail` bereitgestellt (mit Rückfall auf `dialog` oder einfaches
readline).

## Funktionen

- Node.js-Versionen via NVM installieren, entfernen und auflisten
- Aktive Version systemweit mit `update-alternatives` umschalten
  (manueller oder automatischer Modus)
- `node` ist der Master-Link; die Slaves werden dynamisch durch das
  Scannen von `<version>/bin/` erkannt, sodass durch `sudo npm
  install -g` abgelegte Binärdateien (`ng`, `tsc`, `pnpm`, ...) unter
  `/usr/local/bin/` verfügbar werden
- Priorität wird automatisch aus der Node.js-Version berechnet:
  `major * 100 + minor` (z. B. `v22.14.0` → `2214`)
- Interaktive Migration globaler npm-Pakete zwischen Versionen
  (Checkliste)
- Per-User-Pakete von `npm install -g` in die systemweite Schicht
  befördern (`--promote-user-globals`) und die redundanten
  Per-User-Kopien aufräumen (`--cleanup-user-globals`)
- Liefert `/etc/profile.d/update-node-alternatives.sh` aus, sodass ein
  `npm i -g` als normaler Benutzer automatisch in `~/.npm-global`
  landet und die systemweite Binärdatei über die `PATH`-Reihenfolge
  überschreibt
- Bash-Vervollständigung unter
  `/usr/share/bash-completion/completions/`
- Berücksichtigt `DEBIAN_FRONTEND` (siehe
  [`debconf(7)`](https://manpages.debian.org/debconf.7)); unterstützt
  `dialog` (whiptail/dialog), `readline`, `gnome` (zenity), `kde`
  (kdialog) und `noninteractive`. Wird automatisch erkannt, wenn
  nicht gesetzt.

## Schnellstart

```bash
# Erstellen und installieren (aus dem Quellbaum)
sudo make install   # installiert Skript + Manpage + eingebettetes nvm unter $PREFIX (Standard /usr/local)

# Die neueste Node 22 installieren und registrieren
sudo update-node-alternatives --install 22

# Darauf umschalten
sudo update-node-alternatives --set v22.14.0

# Status prüfen
update-node-alternatives --list
```

Für ein vollständiges Debian-Paket:

```bash
make deb
sudo apt install -y ../update-node-alternatives_*.deb
```

## Verwendung

```
usage: update-node-alternatives [-v|--verbose] <action> [options]

NVM-Aktionen:
  -i, --install <version>            Eine Node.js-Version installieren
  -r, --remove <version>             Eine installierte Version entfernen
  -R, --list-remote [--lts]          Zum Download verfügbare Versionen auflisten
  -p, --list-packages <version>      Globale npm-Pakete einer Version auflisten
  --upgrade <version> [--from <ver>] Installieren, aktivieren und Pakete migrieren
  --reinstall-packages --from <ver> --to <ver>
                                     Globale Pakete zwischen zwei Versionen migrieren

update-alternatives-Aktionen:
  -l, --list                         Installierte Versionen auflisten
  -s, --set <nodename>               Aktive Version festlegen (manueller Modus)
  -u, --update                       Alle Versionen mit alternatives neu registrieren
                                       (nach `npm install -g <pkg>` erneut ausführen,
                                       damit <pkg> unter /usr/local/bin sichtbar wird)
  -a, --auto                         In den Automatikmodus wechseln (höchste Priorität)

Per-User-Globals:
  --promote-user-globals             [root] Per-User-`npm i -g`-Pakete von $SUDO_USER
                                       in die systemweite Schicht befördern
  --cleanup-user-globals             [user] Per-User-`npm i -g`-Pakete entfernen,
                                       die bereits systemweit abgedeckt sind

Optionen:
  -v, --verbose                      Ausführliche Ausgabe
  --frontend <name>                  Frontend erzwingen: dialog, readline,
                                       gnome, kde, noninteractive
  --no-dialog                        Alias für --frontend=readline
  -h, --help                         Hilfe anzeigen
```

Siehe [`update-node-alternatives(8)`](../update-node-alternatives.8) für das vollständige Handbuch.

## Beispiele

```bash
# Die neueste LTS per Alias installieren
sudo update-node-alternatives --install lts/jod

# Zum Download verfügbare LTS-Releases auflisten
update-node-alternatives --list-remote --lts

# Globale Pakete einer installierten Version anzeigen
update-node-alternatives --list-packages v22.14.0

# Upgrade von v20 auf v22 mit interaktiver Paketmigration
sudo update-node-alternatives --upgrade 22 --from v20.18.1

# Globale Pakete zwischen zwei bereits installierten Versionen migrieren
sudo update-node-alternatives --reinstall-packages --from v20.18.1 --to v22.14.0

# In den Automatikmodus wechseln (höchste Priorität gewinnt)
sudo update-node-alternatives --auto

# Nach einem systemweiten `npm install -g` <pkg> unter /usr/local/bin sichtbar machen
sudo npm install -g @angular/cli
sudo update-node-alternatives --update

# Per-User-`npm i -g`-Pakete von $SUDO_USER in die systemweite Schicht
# befördern (und im Anschluss anbieten, die Per-User-Kopien zu entfernen)
sudo update-node-alternatives --promote-user-globals

# Per-User-`npm i -g`-Pakete entfernen, die bereits systemweit
# in derselben oder einer neueren Version abgedeckt sind
update-node-alternatives --cleanup-user-globals
```

## Verzeichnisstruktur

```
/usr/local/share/nvm/                 # systemweites NVM
  nvm.sh, nvm-exec
  versions/node/vX.Y.Z/               # installierte Node.js-Versionen
  versions/node_binaries.info         # Statusdatei (Union + pro Version)
/usr/local/sbin/update-node-alternatives
/usr/local/bin/node                   # Master-Symlink (update-alternatives)
/usr/local/bin/{npm,npx,corepack,...} # dynamische Slaves (auch ng, tsc, ...)
/usr/local/share/man/man8/update-node-alternatives.8
/etc/profile.d/update-node-alternatives.sh           # NPM_CONFIG_PREFIX + PATH
/usr/share/bash-completion/completions/update-node-alternatives
```

## Abhängigkeiten

- `bash` ≥ 4.0 (assoziative Arrays)
- `whiptail` **oder** `dialog` (optional — Rückfall auf readline)
- `curl` **oder** `wget` (von NVM zum Herunterladen von Node.js verwendet)
- `update-alternatives` (aus `dpkg`)

## Build & Entwicklung

```bash
make help           # verfügbare Targets auflisten
make check          # shellcheck ausführen
sudo make install   # in $PREFIX installieren (Standard /usr/local)
sudo make uninstall # installierte Dateien entfernen
sudo make purge     # uninstall + Alternativen entfernen + /usr/local/share/nvm/
make man            # Manpage anzeigen
```

### Migration von einem Per-User-nvm

Wenn Sie zuvor `~/.nvm` verwendet haben, kopieren Sie die installierten
Node.js-Versionen in den systemweiten Speicher und registrieren Sie sie
erneut bei `update-alternatives`:

```bash
sudo mkdir -p /usr/local/share/nvm/versions/node
sudo cp -a ~/.nvm/versions/node/* /usr/local/share/nvm/versions/node/
sudo update-node-alternatives --update
```

### Debian-Paketierung

```bash
make deb            # baut das .deb in ../ (umhüllt dpkg-buildpackage -us -uc -b)
make deb-clean      # Debian-Build-Artefakte aufräumen
lintian ../update-node-alternatives_*.changes
```

### Eingebettetes nvm

Das Paket liefert eine Upstream-Kopie von [nvm](https://github.com/nvm-sh/nvm)
unter `vendor/nvm/` (installiert nach
`/usr/share/update-node-alternatives/nvm/`). Die genaue Version wird in
`vendor/nvm/VERSION` festgehalten und vom Binärpaket über
`Provides: bundled-nvm-<version>` veröffentlicht.

```bash
make vendor-nvm-show               # aktuell eingebettete nvm-Version anzeigen
make check-upstream                # auf neue Releases prüfen (uscan + debian/watch)
make vendor-nvm NVM_VERSION=0.40.4 # vendor/nvm/ auf eine bestimmte Version aktualisieren
```

`make vendor-nvm` startet `debian/vendor-nvm.sh`, das den Upstream-Tarball
herunterlädt, die Dateien unter `vendor/nvm/` ersetzt, `vendor/nvm/VERSION`
aktualisiert und `Provides: bundled-nvm-<version>` in `debian/control`
hochzählt. Im Anschluss einen Changelog-Eintrag mit
`dch -i "Update bundled nvm to <version>."` hinzufügen, committen, dann
`make deb` ausführen.

## Lizenz

GPL-2.0-or-later — siehe [LICENSE](../LICENSE).

## Autor

Eric Lemesre <eric.lemesre@gmail.com>
