# update-node-alternative

[Français](README.fr.md) | **English**

A system-wide Node.js version manager for Debian, in the spirit of
[`update-java-alternatives(8)`](https://manpages.debian.org/update-java-alternatives).

It combines the [NVM](https://github.com/nvm-sh/nvm) infrastructure
(to download and store Node.js binaries) with Debian's
[`update-alternatives(1)`](https://manpages.debian.org/update-alternatives)
mechanism (to switch the `/usr/local/bin/{node,npm,npx,corepack}`
symlinks). A debconf-style interactive frontend is provided via
`whiptail` (with a `dialog` or plain readline fallback).

## Features

- Install, remove and list Node.js versions via NVM
- Switch the active version system-wide with `update-alternatives` (manual or auto mode)
- `node` is the master link; `npm`, `npx`, `corepack` are slaves
- Priority auto-computed from the Node.js version: `major * 100 + minor`
  (e.g. `v22.14.0` → `2214`)
- Interactive migration of global npm packages between versions (checklist)
- Non-interactive / scriptable mode via `--no-dialog`

## Quick start

```bash
# Build and install (from the source tree)
make install        # installs script + man page under $PREFIX (default /usr/local)
sudo ./install-node-alternative.sh   # sets up /usr/local/share/nvm (needs NVM installed per-user)

# Install the latest Node 22 and register it
sudo update-node-alternative --install 22

# Switch to it
sudo update-node-alternative --set v22.14.0

# Check status
update-node-alternative --list
```

For a full Debian package:

```bash
dpkg-buildpackage -us -uc -b
sudo dpkg -i ../update-node-alternative_*.deb
```

## Usage

```
usage: update-node-alternative [-v|--verbose] <action> [options]

NVM actions:
  -i, --install <version>            Install a Node.js version
  -r, --remove <version>             Remove an installed version
  -R, --list-remote [--lts]          List versions available for download
  -p, --packages <version>           List global npm packages of a version
  --upgrade <version> [--from <ver>] Install, activate and migrate packages
  --reinstall-packages --from <ver> --to <ver>
                                     Migrate global packages between versions

update-alternatives actions:
  -l, --list                         List installed versions
  -s, --set <nodename>               Set the active version (manual mode)
  -u, --update                       Re-register all versions with alternatives
  -a, --auto                         Switch to automatic mode (highest priority)

Options:
  -v, --verbose                      Verbose output
  --no-dialog                        Disable whiptail (readline mode)
  -h, --help                         Show help
```

See [`update-node-alternative(8)`](update-node-alternative.8) for the full manual.

## Examples

```bash
# Install the latest LTS by alias
sudo update-node-alternative --install lts/jod

# List LTS releases available for download
update-node-alternative --list-remote --lts

# Show global packages of an installed version
update-node-alternative --packages v22.14.0

# Upgrade from v20 to v22 with interactive package migration
sudo update-node-alternative --upgrade 22 --from v20.18.1

# Migrate global packages between two already-installed versions
sudo update-node-alternative --reinstall-packages --from v20.18.1 --to v22.14.0

# Switch to auto mode (highest priority wins)
sudo update-node-alternative --auto
```

## Layout

```
/usr/local/share/nvm/                 # system-wide NVM
  nvm.sh, nvm-exec
  versions/node/vX.Y.Z/               # installed Node.js versions
  versions/node_binaries.info         # state file
/usr/local/sbin/update-node-alternative
/usr/local/bin/{node,npm,npx,corepack}   # symlinks managed by update-alternatives
/usr/local/share/man/man8/update-node-alternative.8
```

## Dependencies

- `bash` ≥ 4.0 (associative arrays)
- `whiptail` **or** `dialog` (optional — fallback to readline)
- `curl` **or** `wget` (used by NVM to download Node.js)
- `update-alternatives` (from `dpkg`)
- An existing NVM installation when running `install-node-alternative.sh`
  (to bootstrap the system-wide NVM from a per-user one)

## Build & development

```bash
make help           # list available targets
make check          # run shellcheck
make install        # install into $PREFIX (default /usr/local)
make uninstall      # remove installed files
make man            # view the man page

# Debian packaging
dpkg-buildpackage -us -uc -b
lintian ../update-node-alternative_*.changes
```

## License

GPL-2.0-or-later — see [LICENSE](LICENSE).

## Author

Eric Lemesre <eric.lemesre@gmail.com>
