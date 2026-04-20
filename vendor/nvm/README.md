# Vendored NVM

This directory contains a copy of [nvm](https://github.com/nvm-sh/nvm),
shipped with `update-node-alternative` so that the Debian package can work
out of the box without requiring a per-user NVM installation.

## Current version

See [`VERSION`](VERSION).

## Files

| File              | Purpose                                                    |
| ----------------- | ---------------------------------------------------------- |
| `nvm.sh`          | NVM main shell library (sourced by `update-node-alternative`) |
| `nvm-exec`        | NVM helper used internally by `nvm run`                    |
| `bash_completion` | Optional bash completion for NVM commands                  |
| `LICENSE.md`      | Upstream MIT license text                                  |

## License

NVM is distributed under the MIT license by its upstream authors
(Tim Caswell, Jordan Harband and contributors). See
[`LICENSE.md`](LICENSE.md) for the full text. The MIT license is
compatible with the GPL-2.0-or-later license of `update-node-alternative`.

## Updating the vendored copy

```sh
NVM_VERSION=0.40.3   # pick the upstream tag you want
BASE="https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION"
curl -fsSLo vendor/nvm/nvm.sh          "$BASE/nvm.sh"
curl -fsSLo vendor/nvm/nvm-exec        "$BASE/nvm-exec"
curl -fsSLo vendor/nvm/bash_completion "$BASE/bash_completion"
curl -fsSLo vendor/nvm/LICENSE.md      "$BASE/LICENSE.md"
chmod 755 vendor/nvm/nvm-exec
echo "$NVM_VERSION" > vendor/nvm/VERSION
```

Then review the diff, update `debian/changelog`, and rebuild the package.
