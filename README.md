# update-node-alternatives

**English** | [Français](docs/README.fr.md) | [Deutsch](docs/README.de.md) | [Español](docs/README.es.md) | [Italiano](docs/README.it.md) | [Português (Brasil)](docs/README.pt_BR.md)

A system-wide Node.js version manager for Debian, in the spirit of
[`update-java-alternatives(8)`](https://manpages.debian.org/update-java-alternatives).

It combines the [NVM](https://github.com/nvm-sh/nvm) infrastructure
(to download and store Node.js binaries) with Debian's
[`update-alternatives(1)`](https://manpages.debian.org/update-alternatives)
mechanism (to switch the system-wide `node` symlink — slaves like
`npm`, `npx`, `corepack`, plus any binary deposited by `sudo npm
install -g` for that version, are discovered dynamically). A
debconf-style interactive frontend is provided via `whiptail` (with
a `dialog` or plain readline fallback).

## Features

- Install, remove and list Node.js versions via NVM
- Switch the active version system-wide with `update-alternatives` (manual or auto mode)
- `node` is the master link; the slaves are discovered dynamically by
  scanning `<version>/bin/`, so binaries deposited by `sudo npm install -g`
  (`ng`, `tsc`, `pnpm`, ...) are exposed under `/usr/local/bin/`
- Priority auto-computed from the Node.js version: `major * 1000000 + minor * 1000 + patch`
  (e.g. `v22.14.0` → `22014000`)
- Interactive migration of global npm packages between versions (checklist)
- Promote per-user `npm install -g` packages into the system-wide layer
  (`--promote-user-globals`) and clean up the redundant per-user copies
  (`--cleanup-user-globals`)
- Ships `/etc/profile.d/update-node-alternatives.sh` so a regular user's
  `npm i -g` automatically lands in `~/.npm-global` and overrides the
  system-wide binary via `PATH` order
- Bash completion under `/usr/share/bash-completion/completions/`
- Honours `DEBIAN_FRONTEND` (see [`debconf(7)`](https://manpages.debian.org/debconf.7));
  supports `dialog` (whiptail/dialog), `readline`, `gnome` (zenity), `kde`
  (kdialog) and `noninteractive`. Auto-detected when unset.

## Quick start

```bash
# Build and install (from the source tree)
sudo make install   # installs script + man page + vendored nvm under $PREFIX (default /usr/local)

# Install the latest Node 22 and register it
sudo update-node-alternatives --install 22

# Switch to it
sudo update-node-alternatives --set v22.14.0

# Check status
update-node-alternatives --list
```

For a full Debian package:

```bash
make deb
sudo apt install -y ../update-node-alternatives_*.deb
```

## Usage

```
usage: update-node-alternatives [-v|--verbose] <action> [options]

NVM actions:
  -i, --install <version>            Install a Node.js version
  -r, --remove <version>             Remove an installed version
  -R, --list-remote [--lts]          List versions available for download
  -p, --list-packages <version>      List global npm packages of a version
  --upgrade <version> [--from <ver>] Install, activate and migrate packages
  --reinstall-packages --from <ver> --to <ver>
                                     Migrate global packages between versions

update-alternatives actions:
  -l, --list                         List installed versions
  -s, --set <nodename>               Set the active version (manual mode)
  -u, --update                       Re-register all versions with alternatives
                                       (replay after `npm install -g <pkg>`
                                       to expose <pkg> under /usr/local/bin)
  -a, --auto                         Switch to automatic mode (highest priority)

Per-user globals:
  --promote-user-globals             [root] Promote $SUDO_USER's `npm i -g`
                                       packages into the system-wide layer
  --cleanup-user-globals             [user] Drop per-user `npm i -g` packages
                                       already covered system-wide

Options:
  -v, --verbose                      Verbose output
  --frontend <name>                  Force frontend: dialog, readline,
                                       gnome, kde, noninteractive
  --no-dialog                        Alias for --frontend=readline
  -h, --help                         Show help
```

See [`update-node-alternatives(8)`](update-node-alternatives.8) for the full manual.

## Examples

```bash
# Install the latest LTS by alias
sudo update-node-alternatives --install lts/jod

# List LTS releases available for download
update-node-alternatives --list-remote --lts

# Show global packages of an installed version
update-node-alternatives --list-packages v22.14.0

# Upgrade from v20 to v22 with interactive package migration
sudo update-node-alternatives --upgrade 22 --from v20.18.1

# Migrate global packages between two already-installed versions
sudo update-node-alternatives --reinstall-packages --from v20.18.1 --to v22.14.0

# Switch to auto mode (highest priority wins)
sudo update-node-alternatives --auto

# After a system-wide `npm install -g`, expose <pkg> under /usr/local/bin
sudo npm install -g @angular/cli
sudo update-node-alternatives --update

# Promote $SUDO_USER's per-user `npm i -g` packages into the system-wide
# layer (and offer to clean up the per-user copies right after)
sudo update-node-alternatives --promote-user-globals

# Drop per-user `npm i -g` packages already covered system-wide at
# the same or a newer version
update-node-alternatives --cleanup-user-globals
```

## Layout

```
/usr/local/share/nvm/                 # system-wide NVM
  nvm.sh, nvm-exec
  versions/node/vX.Y.Z/               # installed Node.js versions
  versions/node_binaries.info         # state file (union + per-version)
/usr/local/sbin/update-node-alternatives
/usr/local/bin/node                   # master symlink (update-alternatives)
/usr/local/bin/{npm,npx,corepack,...} # dynamic slaves (also ng, tsc, ...)
/usr/local/share/man/man8/update-node-alternatives.8
/etc/profile.d/update-node-alternatives.sh           # NPM_CONFIG_PREFIX + PATH
/usr/share/bash-completion/completions/update-node-alternatives
```

## Dependencies

- `bash` ≥ 4.0 (associative arrays)
- `whiptail` **or** `dialog` (optional — fallback to readline)
- `curl` **or** `wget` (used by NVM to download Node.js)
- `update-alternatives` (from `dpkg`)

## Build & development

```bash
make help           # list available targets
make check          # run shellcheck
sudo make install   # install into $PREFIX (default /usr/local)
sudo make uninstall # remove installed files
sudo make purge     # uninstall + drop alternatives + /usr/local/share/nvm/
make man            # view the man page
```

### Migrating from a per-user nvm

If you previously used `~/.nvm`, copy the installed Node.js versions to the
system-wide store and re-register them with `update-alternatives`:

```bash
sudo mkdir -p /usr/local/share/nvm/versions/node
sudo cp -a ~/.nvm/versions/node/* /usr/local/share/nvm/versions/node/
sudo update-node-alternatives --update
```

### Debian packaging

```bash
make deb            # build .deb into ../ (wraps dpkg-buildpackage -us -uc -b)
make deb-clean      # clean Debian build artifacts
lintian ../update-node-alternatives_*.changes
```

### Bundled nvm

The package ships an upstream copy of [nvm](https://github.com/nvm-sh/nvm)
under `vendor/nvm/` (installed to `/usr/share/update-node-alternatives/nvm/`).
The exact version is recorded in `vendor/nvm/VERSION` and advertised by the
binary package via `Provides: bundled-nvm-<version>`.

```bash
make vendor-nvm-show               # show currently bundled nvm version
make check-upstream                # check for new releases (uscan + debian/watch)
make vendor-nvm NVM_VERSION=0.40.4 # refresh vendor/nvm/ to a given version
```

`make vendor-nvm` runs `debian/vendor-nvm.sh`, which downloads the upstream
tarball, replaces the files under `vendor/nvm/`, updates `vendor/nvm/VERSION`
and bumps `Provides: bundled-nvm-<version>` in `debian/control`. After running
it, add a changelog entry with `dch -i "Update bundled nvm to <version>."`,
commit, then `make deb`.

## License

GPL-2.0-or-later — see [LICENSE](LICENSE).

## Author

Eric Lemesre <eric.lemesre@gmail.com>
