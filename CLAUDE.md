# update-node-alternative - Contexte de projet

## Description

Outil de gestion system-wide de Node.js pour Debian, inspiré de `update-java-alternatives`.
Combine l'infrastructure NVM (téléchargement/gestion des versions) avec le système
`update-alternatives` de Debian pour le basculement entre versions.
Interface interactive via `whiptail` (frontend debconf standard Debian).

## Architecture

```
update-node-alternative          # Script principal (bash)
debian/vendor-nvm.sh             # Helper de mise à jour du nvm vendoré
```

### Chemins système

- `/usr/local/share/nvm/` — Infrastructure NVM system-wide (nvm.sh, nvm-exec, cache)
- `/usr/local/share/nvm/versions/node/` — Versions Node installées (vX.Y.Z/)
- `/usr/local/share/nvm/versions/node_binaries.info` — État des binaires enregistrés
- `/usr/local/sbin/update-node-alternative` — Script installé
- `/usr/local/bin/node`, `/usr/local/bin/npm`, etc. — Liens gérés par update-alternatives

### Mécanisme

1. NVM télécharge les binaires Node dans `/usr/local/share/nvm/versions/node/vX.Y.Z/`
2. `update-alternatives` gère les liens `/usr/local/bin/{node,npm,npx,corepack}`
3. node = master, npm/npx/corepack = slaves
4. Priorité calculée: major*100 + minor (v22.14.0 → 2214)
5. Interface interactive via whiptail avec fallback readline (`--no-dialog`)

## Commandes implémentées

### Actions NVM
- `--install <version>` — Télécharge via NVM + enregistre dans alternatives
- `--remove <version>` — Supprime (alternatives + fichiers NVM)
- `--list-remote [--lts]` — Versions disponibles au téléchargement
- `--list-packages <version>` — Liste les paquets npm globaux d'une version
- `--upgrade <version> [--from <ver>]` — Install + set + migration paquets
- `--reinstall-packages --from <ver> --to <ver>` — Migration seule des paquets

### Actions alternatives (Debian)
- `--list` — Versions installées localement
- `--set <nodename>` — Activer une version (mode manuel) + propose migration
- `--update` — Re-enregistrer toutes les versions
- `--auto` — Mode automatique (plus haute priorité)

### Options
- `-v, --verbose` — Affichage détaillé
- `--no-dialog` — Désactiver whiptail, mode readline
- `--lts` — Filtrer LTS uniquement (avec --list-remote)

## Fonctionnalités clés

### Interface debconf (whiptail)
- `dialog_yesno` — Confirmation oui/non
- `dialog_checklist` — Sélection multiple (migration paquets)
- `dialog_menu` — Sélection unique
- `dialog_msgbox` — Message d'information
- Détection auto: whiptail > dialog > readline fallback

### Migration des paquets globaux
- Déclenchée automatiquement lors d'un `--set` ou `--upgrade`
- Détecte les paquets dans `lib/node_modules/` (scoped et non-scoped)
- Exclut npm et corepack (fournis avec node)
- Checklist whiptail pour sélectionner interactivement les paquets à migrer

## État actuel

- [x] Script principal fonctionnel (syntaxe validée)
- [x] Script d'installation
- [x] Intégration NVM (install, remove, list-remote, packages)
- [x] Intégration update-alternatives (set, auto, update, list)
- [x] Interface whiptail/debconf
- [x] Migration interactive des paquets globaux
- [x] Dépôt git initialisé

## TODO / Pistes pour contribution Debian

- [ ] Ajouter une man page (`update-node-alternative.8`)
- [ ] Créer un `Makefile` (install, uninstall, man)
- [ ] Packaging Debian (`debian/` directory: control, rules, changelog, copyright)
- [ ] Tests automatisés (bats-core ou shellcheck + tests fonctionnels)
- [ ] Gestion des dépendances Debian (Depends: whiptail, curl | wget)
- [ ] Support de `DEBIAN_FRONTEND=noninteractive` (comme debconf)
- [ ] Intégration avec `/etc/profile.d/` pour PATH des binaires globaux npm
- [ ] Logrotate ou nettoyage du cache NVM
- [ ] Hook apt (trigger post-install si on veut intégrer avec dpkg)
- [ ] Complétion bash/zsh (`/etc/bash_completion.d/`)
- [ ] Licence (GPL-2+ pour cohérence Debian)

## Dépendances

- bash >= 4.0 (associative arrays)
- whiptail (paquet: whiptail) ou dialog — pour l'interface interactive
- curl ou wget — pour NVM (téléchargement des versions node)
- coreutils, grep, sed — outils standard

## Environnement de développement

- Debian sid (forky)
- NVM per-user existant dans ~/.nvm (v24.14.0)
- whiptail disponible (/usr/bin/whiptail)
- Utilisateur: eric
