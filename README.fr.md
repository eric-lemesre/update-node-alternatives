# update-node-alternatives

**Français** | [English](README.md)

Un gestionnaire de versions Node.js system-wide pour Debian, dans l'esprit de
[`update-java-alternatives(8)`](https://manpages.debian.org/update-java-alternatives).

Il combine l'infrastructure [NVM](https://github.com/nvm-sh/nvm)
(téléchargement et stockage des binaires Node.js) avec le mécanisme
[`update-alternatives(1)`](https://manpages.debian.org/update-alternatives)
de Debian (bascule des liens `/usr/local/bin/{node,npm,npx,corepack}`).
L'interface interactive utilise `whiptail` (avec un repli sur `dialog` ou
sur readline classique).

## Fonctionnalités

- Installer, supprimer et lister les versions Node.js via NVM
- Basculer la version active system-wide avec `update-alternatives` (mode manuel ou automatique)
- `node` est le lien maître ; les esclaves sont découverts dynamiquement
  en scannant `<version>/bin/`, ce qui permet d'exposer sous
  `/usr/local/bin/` les binaires déposés par `sudo npm install -g`
  (`ng`, `tsc`, `pnpm`, ...)
- Priorité calculée automatiquement depuis la version : `majeur * 100 + mineur`
  (ex. `v22.14.0` → `2214`)
- Migration interactive des paquets npm globaux entre versions (checklist)
- Promotion des paquets `npm install -g` per-user vers la couche
  system-wide (`--promote-user-globals`) et nettoyage des copies
  per-user redondantes (`--cleanup-user-globals`)
- Livre `/etc/profile.d/update-node-alternatives.sh` pour qu'un
  `npm i -g` utilisateur atterrisse dans `~/.npm-global` et écrase le
  binaire system-wide via l'ordre de `PATH`
- Complétion bash sous `/usr/share/bash-completion/completions/`
- Honore `DEBIAN_FRONTEND` (cf. [`debconf(7)`](https://manpages.debian.org/debconf.7))&nbsp;:
  supporte `dialog` (whiptail/dialog), `readline`, `gnome` (zenity), `kde`
  (kdialog) et `noninteractive`. Auto-détecté si non défini.

## Démarrage rapide

```bash
# Construire et installer (depuis les sources)
sudo make install   # installe le script + la man page + le nvm embarqué sous $PREFIX (défaut /usr/local)

# Installer la dernière Node 22 et l'enregistrer
sudo update-node-alternatives --install 22

# Basculer dessus
sudo update-node-alternatives --set v22.14.0

# Vérifier
update-node-alternatives --list
```

Pour un vrai paquet Debian :

```bash
make deb
sudo apt install -y ../update-node-alternatives_*.deb
```

## Utilisation

```
usage: update-node-alternatives [-v|--verbose] <action> [options]

Actions NVM :
  -i, --install <version>            Installer une version Node.js
  -r, --remove <version>             Supprimer une version installée
  -R, --list-remote [--lts]          Lister les versions disponibles au téléchargement
  -p, --list-packages <version>      Lister les paquets npm globaux d'une version
  --upgrade <version> [--from <ver>] Installer, activer et migrer les paquets
  --reinstall-packages --from <ver> --to <ver>
                                     Migrer les paquets globaux entre deux versions

Actions alternatives :
  -l, --list                         Lister les versions installées
  -s, --set <nodename>               Définir la version active (mode manuel)
  -u, --update                       Ré-enregistrer toutes les versions
                                       (rejouer après `npm install -g <pkg>`
                                       pour exposer <pkg> sous /usr/local/bin)
  -a, --auto                         Basculer en mode automatique (plus haute priorité)

Paquets npm -g per-user :
  --promote-user-globals             [root] Promouvoir les paquets `npm i -g`
                                       de $SUDO_USER vers la couche system-wide
  --cleanup-user-globals             [user] Supprimer les paquets per-user
                                       déjà couverts system-wide

Options :
  -v, --verbose                      Affichage détaillé
  --frontend <name>                  Forcer un frontend : dialog, readline,
                                       gnome, kde, noninteractive
  --no-dialog                        Alias de --frontend=readline
  -h, --help                         Afficher l'aide
```

Voir [`update-node-alternatives(8)`](update-node-alternatives.8) pour le manuel complet.

## Exemples

```bash
# Installer la dernière LTS par alias
sudo update-node-alternatives --install lts/jod

# Lister les LTS disponibles au téléchargement
update-node-alternatives --list-remote --lts

# Voir les paquets globaux d'une version installée
update-node-alternatives --list-packages v22.14.0

# Upgrader de v20 vers v22 avec migration interactive des paquets
sudo update-node-alternatives --upgrade 22 --from v20.18.1

# Migrer les paquets globaux entre deux versions déjà installées
sudo update-node-alternatives --reinstall-packages --from v20.18.1 --to v22.14.0

# Passer en mode auto (plus haute priorité active)
sudo update-node-alternatives --auto
```

## Arborescence

```
/usr/local/share/nvm/                 # NVM system-wide
  nvm.sh, nvm-exec
  versions/node/vX.Y.Z/               # versions Node.js installées
  versions/node_binaries.info         # fichier d'état
/usr/local/sbin/update-node-alternatives
/usr/local/bin/{node,npm,npx,corepack}   # liens gérés par update-alternatives
/usr/local/share/man/man8/update-node-alternatives.8
```

## Dépendances

- `bash` ≥ 4.0 (tableaux associatifs)
- `whiptail` **ou** `dialog` (optionnel — repli sur readline)
- `curl` **ou** `wget` (utilisé par NVM pour télécharger Node.js)
- `update-alternatives` (fourni par `dpkg`)

## Build & développement

```bash
make help           # lister les cibles disponibles
make check          # lancer shellcheck
sudo make install   # installer dans $PREFIX (par défaut /usr/local)
sudo make uninstall # supprimer les fichiers installés
sudo make purge     # uninstall + retire les alternatives + /usr/local/share/nvm/
make man            # afficher la man page
```

### Migrer depuis un nvm utilisateur

Si vous utilisiez `~/.nvm`, copiez les versions Node.js installées dans le
stockage système puis ré-enregistrez-les auprès de `update-alternatives` :

```bash
sudo mkdir -p /usr/local/share/nvm/versions/node
sudo cp -a ~/.nvm/versions/node/* /usr/local/share/nvm/versions/node/
sudo update-node-alternatives --update
```

### Packaging Debian

```bash
make deb            # construit le .deb dans ../ (wraps dpkg-buildpackage -us -uc -b)
make deb-clean      # nettoie les artefacts de build Debian
lintian ../update-node-alternatives_*.changes
```

### NVM embarqué

Le paquet embarque une copie upstream de [nvm](https://github.com/nvm-sh/nvm)
sous `vendor/nvm/` (installée dans `/usr/share/update-node-alternatives/nvm/`).
La version exacte est enregistrée dans `vendor/nvm/VERSION` et exposée par le
paquet binaire via `Provides: bundled-nvm-<version>`.

```bash
make vendor-nvm-show               # afficher la version NVM embarquée
make check-upstream                # détecter les nouvelles versions (uscan + debian/watch)
make vendor-nvm NVM_VERSION=0.40.4 # rafraîchir vendor/nvm/ vers une version donnée
```

`make vendor-nvm` lance `debian/vendor-nvm.sh`, qui télécharge le tarball
upstream, remplace les fichiers de `vendor/nvm/`, met à jour
`vendor/nvm/VERSION` et bumpe `Provides: bundled-nvm-<version>` dans
`debian/control`. Après exécution, ajouter une entrée changelog avec
`dch -i "Update bundled nvm to <version>."`, committer, puis `make deb`.

## Licence

GPL-2.0-or-later — voir [LICENSE](LICENSE).

## Auteur

Eric Lemesre <eric.lemesre@gmail.com>
