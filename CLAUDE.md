# update-node-alternative — Contexte de projet

## Description

Outil de gestion system-wide de Node.js pour Debian, dans l'esprit de
`update-java-alternatives(8)`. Combine l'infrastructure
[NVM](https://github.com/nvm-sh/nvm) (téléchargement et stockage des binaires
Node.js) avec le mécanisme `update-alternatives(1)` de Debian (bascule des
liens `/usr/local/bin/{node,npm,npx,corepack}`).

L'interface interactive honore la convention `DEBIAN_FRONTEND` de
`debconf(7)` et supporte plusieurs backends : whiptail/dialog (TTY),
readline, zenity (GTK), kdialog (Qt), noninteractive.

## Arborescence du repo

```
update-node-alternative          # Script principal (bash)
update-node-alternative.8        # Page de manuel (section 8)
Makefile                         # Cibles install/uninstall/purge/deb/check-upstream/vendor-nvm/...
LICENSE                          # GPL-2.0-or-later (texte complet)
README.md / README.fr.md         # Documentation utilisateur (anglais / français)
CLAUDE.md                        # Ce fichier
vendor/nvm/                      # Copie vendorée de nvm-sh/nvm (MIT)
  VERSION                          # Version exacte embarquée
  nvm.sh, nvm-exec, bash_completion, LICENSE.md, README.md
debian/                          # Packaging Debian
  changelog, control, copyright (DEP-5), rules, watch
  source/format, *.examples, *.lintian-overrides
  vendor-nvm.sh                    # Helper de mise à jour du nvm vendoré
```

## Chemins d'installation

### Via le paquet Debian (`apt install update-node-alternative`)

- `/usr/sbin/update-node-alternative` — script
- `/usr/share/man/man8/update-node-alternative.8` — man page
- `/usr/share/update-node-alternative/nvm/` — nvm vendoré (nvm.sh, nvm-exec, …)

### Via `make install` (hors-paquet, par défaut `PREFIX=/usr/local`)

- `/usr/local/sbin/update-node-alternative`
- `/usr/local/share/man/man8/update-node-alternative.8`
- `/usr/local/share/update-node-alternative/nvm/`

### État runtime (créé/écrit par le script lui-même)

- `/usr/local/share/nvm/versions/node/vX.Y.Z/` — versions Node installées
- `/usr/local/share/nvm/{alias,.cache}/` — métadata + cache NVM
- `/usr/local/share/nvm/versions/node_binaries.info` — binaires enregistrés (Make slaves)
- `/usr/local/bin/{node,npm,npx,corepack}` — symlinks gérés par `update-alternatives`

## Mécanisme

1. NVM (version vendorée) télécharge les binaires Node dans
   `/usr/local/share/nvm/versions/node/vX.Y.Z/`.
2. `update-alternatives` gère les liens `/usr/local/bin/{node,npm,npx,corepack}`.
3. `node` est le master ; `npm`, `npx`, `corepack` sont des slaves.
4. Priorité = `major * 100 + minor` (v22.14.0 → 2214). En mode `auto`, la
   plus haute priorité gagne.
5. `load_nvm()` cherche `nvm.sh` dans (par ordre) :
   `/usr/share/update-node-alternative/nvm/nvm.sh` (paquet),
   `<script_dir>/vendor/nvm/nvm.sh` (sources),
   `$NVM_DIR/nvm.sh` (legacy).

## Commandes implémentées

### Actions NVM

- `-i, --install <version>` — Télécharge via NVM + enregistre dans alternatives
- `-r, --remove <version>` — Supprime (alternatives + fichiers NVM)
- `-R, --list-remote [--lts]` — Versions disponibles au téléchargement
- `-p, --list-packages <version>` — Paquets npm globaux d'une version
- `--upgrade <version> [--from <ver>]` — Install + set + migration paquets
- `--reinstall-packages --from <ver> --to <ver>` — Migration seule des paquets

### Actions update-alternatives

- `-l, --list` — Versions installées localement
- `-s, --set <nodename>` — Activer une version (mode manuel) + propose migration
- `-u, --update` — Re-enregistrer toutes les versions
- `-a, --auto` — Mode automatique (plus haute priorité)

### Options

- `-v, --verbose` — Affichage détaillé (inclut un dump des chemins/frontend)
- `--frontend <name>` — Force le frontend : `dialog`, `readline`, `gnome`,
  `kde`, `noninteractive`
- `--no-dialog` — Alias historique de `--frontend=readline`
- `--lts` — Filtrer LTS uniquement (avec `--list-remote`)
- `-h, -?, --help` — Afficher l'aide

### Variables d'environnement

- `DEBIAN_FRONTEND` — `dialog` / `readline` / `gnome` / `kde` /
  `noninteractive` / `text` / `editor` (mappé vers le frontend correspondant)

## Frontends interactifs

### Sélection (par ordre de priorité)

1. `--frontend=NAME`
2. `--no-dialog` (= `--frontend=readline`)
3. `DEBIAN_FRONTEND` (debconf convention)
4. Auto-détection : zenity/kdialog si `$DISPLAY` ou `$WAYLAND_DISPLAY`,
   sinon whiptail/dialog si dispo, sinon readline.

### Helpers (chacun branche selon `$frontend`)

- `dialog_yesno` — Confirmation oui/non
- `dialog_checklist` — Sélection multiple (migration paquets)
- `dialog_menu` — Sélection unique
- `dialog_msgbox` — Message d'information

## Migration des paquets globaux

- Déclenchée automatiquement lors d'un `--set` ou `--upgrade`
- Détecte les paquets dans `lib/node_modules/` (scoped et non-scoped)
- Exclut `npm` et `corepack` (fournis avec node)
- Checklist interactive (whiptail/zenity/kdialog/readline) pour sélectionner
  les paquets à migrer ; refuse silencieusement en `noninteractive`

## NVM vendoré

- Source : <https://github.com/nvm-sh/nvm> (MIT)
- Version actuelle : `vendor/nvm/VERSION` (au moment de l'écriture : 0.40.4)
- Annoncée par le paquet binaire : `Provides: bundled-nvm-X.Y.Z`
- Mise à jour : `make vendor-nvm NVM_VERSION=X.Y.Z`
  (script `debian/vendor-nvm.sh` + bump du `Provides:` + `dch -i` à faire ensuite)
- Surveillance upstream : `make check-upstream` (uscan + `debian/watch`,
  composant `nvm` configuré)

## Cibles Make

| Cible                          | Effet                                                                                          |
| ------------------------------ | ---------------------------------------------------------------------------------------------- |
| `install` / `uninstall`        | Standard, honore `PREFIX` et `DESTDIR`                                                         |
| `purge`                        | `uninstall` + retire alternatives + supprime `/usr/local/share/nvm/` (interactif, root requis) |
| `check`                        | shellcheck sur `update-node-alternative`                                                       |
| `man`                          | Affiche la man page                                                                            |
| `deb` / `deb-clean`            | Wrap `dpkg-buildpackage -us -uc -b` + clean                                                    |
| `check-upstream`               | `uscan --no-download --report --verbose`                                                       |
| `vendor-nvm-show`              | Affiche la version embarquée                                                                   |
| `vendor-nvm NVM_VERSION=X.Y.Z` | Rafraîchit `vendor/nvm/`                                                                       |

## Packaging Debian

- `debian/control` — `Architecture: all`, `Depends: bash (>=4.0), dpkg (>=1.15.4),
  whiptail | dialog, curl | wget, ca-certificates`, `Suggests: zenity, kdialog`,
  `Provides: bundled-nvm-X.Y.Z`
- `debian/copyright` — Format DEP-5 ; GPL-2+ pour le code, Expat (MIT) pour
  `vendor/nvm/*`
- `debian/rules` — `dh $@` + `dh_auto_install -- PREFIX=/usr`
- `debian/watch` — uscan v4 ; suit le repo principal + composant `nvm`
- `debian/vendor-nvm.sh` — helper de bump du nvm embarqué

## Dépendances

### Runtime

- `bash` ≥ 4.0 (associative arrays)
- `dpkg` ≥ 1.15.4 (pour `update-alternatives`)
- `whiptail` **ou** `dialog` (TTY)
- `curl` **ou** `wget` (téléchargement Node.js par NVM)
- `ca-certificates`
- `git` (recommandé, requis par certaines installations NVM)

### Frontends GUI optionnels (Suggests)

- `zenity` — frontend GTK (`DEBIAN_FRONTEND=gnome`)
- `kdialog` — frontend Qt (`DEBIAN_FRONTEND=kde`)

### Dev / packaging

- `shellcheck` (`make check`)
- `devscripts` + `debhelper` ≥ 13 + `fakeroot` (`make deb`, `uscan`)
- `lintian` (post-build verification)

## État actuel

- [x] Script principal multi-frontend (whiptail/dialog/zenity/kdialog/readline/noninteractive)
- [x] Honore `DEBIAN_FRONTEND` + `--frontend NAME`
- [x] Intégration NVM (install, remove, list-remote, list-packages, upgrade)
- [x] Intégration update-alternatives (list, set, auto, update)
- [x] Migration interactive des paquets globaux
- [x] Man page `update-node-alternative.8`
- [x] Makefile (install, uninstall, purge, check, deb, check-upstream, vendor-nvm)
- [x] Packaging Debian (control, copyright DEP-5, rules, watch, lintian-overrides)
- [x] NVM vendoré (0.40.4) + `Provides: bundled-nvm-X.Y.Z`
- [x] Surveillance upstream via `debian/watch` (uscan v4, composant `nvm`)
- [x] Licence GPL-2+ (SPDX headers)
- [x] Suppression de l'ancien `install-node-alternative.sh`
- [x] Renommage `--packages` → `--list-packages` (cohérence avec `--list*`)

## TODO / Pistes restantes

- [ ] Tests automatisés (bats-core ou tests fonctionnels)
- [ ] Templates debconf + `dpkg-reconfigure` (Niveau 3 : configuration
  
      persistante de la version par défaut au moment de `apt install`)
- [ ] `debian/postrm` : retirer les alternatives lors d'un `apt purge`
- [ ] Complétion bash/zsh (`/etc/bash_completion.d/`)
- [ ] Intégration `/etc/profile.d/` pour exposer le PATH des binaires npm
  
      globaux installés par utilisateur
- [ ] Nettoyage du cache NVM (`/usr/local/share/nvm/.cache/`)
- [ ] Publication paquet (Debian mentors, PPA Ubuntu, ou repo APT perso)
- [ ] CI (shellcheck + build deb + lintian)

## Environnement de développement (de référence)

- Debian sid (forky)
- Utilisateur : eric
- Pas de NVM per-user (supprimé) ; `/usr/local/share/nvm/` est seul
  utilisé en runtime
- whiptail, zenity, kdialog disponibles pour tester les frontends
