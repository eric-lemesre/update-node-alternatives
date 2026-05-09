# ToDo — Roadmap `update-node-alternative(s)`

> Décisions prises le **2026-05-09** sur la base du rapport
> [`docs/localisation-node-binaires.md`](docs/localisation-node-binaires.md).
> Ce document est l'export actionnable de la roadmap ; les détails de
> conception complets sont dans le rapport.

## Phase 1 — Alignement standards Debian + rename ✅

Implémentée le 2026-05-09 dans le changelog `0.3.0~UNRELEASED`.

### 1. Renommer le projet/paquet ✅

`update-node-alternative` → `update-node-alternatives` (avec un S final,
par cohérence avec `update-alternatives`).

- [x] dépôt git (rename local — pas de remote, pas de transitional)
- [x] nom du paquet Debian (`debian/control` `Source:` + `Package:`)
- [x] binaire installé (`/usr/sbin/update-node-alternatives`)
- [x] man page (renommée `.8` + `debian/manpages`)
- [x] URLs `Vcs-*`, `Homepage:` dans `debian/control`
- [x] `debian/watch` (composant + main upstream)
- [x] `README.md`, `README.fr.md`
- [x] `AGENTS.md`

### 2. debconf scénario 1.b ✅

- [x] `debian/templates` (default-version : `latest LTS` / `latest` /
      `none` (défaut) / `custom` ; et `purge-nvm-store`)
- [x] `debian/config` (frontend debconf qui pose les questions)
- [x] `debian/postinst` (déclenche `update-node-alternatives --install
      <ver>` selon la réponse)
- [x] `debian/po/` + `Build-Depends: po-debconf` + `Pre-Depends: debconf`
- [x] compat `DEBIAN_FRONTEND=noninteractive` : default `none` ⇒ aucun
      téléchargement silencieux

### 3. `update-alternatives` au niveau packaging ✅

- [x] choix de stratégie : **postrm-only** (les targets vivent sous
      `/usr/local/share/nvm/versions/node/vX.Y.Z/` et n'existent pas à
      l'install ⇒ `dh_installalternatives` inadapté)
- [x] `postrm purge` nettoie `/usr/local/share/nvm/` selon la
      préférence stockée à l'install via debconf
      (`update-node-alternatives/purge-nvm-store`), reposée et
      reconfirmée au purge
- [x] contrat d'install/désinstall documenté dans `debian/README.Debian`

### 4. `debian/manpages` ✅

- [x] créer `debian/manpages` (liste `update-node-alternatives.8`)
- [x] flag Makefile `INSTALL_MAN` (default 1) ; `debian/rules` passe
      `INSTALL_MAN=0` à `dh_auto_install` ⇒ `dh_installman` prend la
      main pour la compression et les permissions

### 5. `debian/upstream/metadata` ✅

- [x] créé (Repository, Repository-Browse, Bug-Database, Bug-Submit)

---

## Phase 2 — Hook `npm -g`, complétion, promotion per-user

> À démarrer **après** la phase 1 (rename + debconf).

### a. Slaves dynamiques dans `do_update()`

Rend system-wide les binaires installés via `npm -g` (`ng`, `pnpm`,
`yarn`, `tsc`, …).

- **Pourquoi** : la couche 4 (paquets `npm -g`) est l'angle mort
  actuel. Les binaires apparaissent dans `…/vX.Y.Z/bin/` mais ne sont
  pas slaves de l'alternative `node`, donc invisibles dans
  `/usr/local/bin/`.
- **À faire** :
  - [ ] remplacer `CORE_BINARIES` figé par un scan de `$NODEBIN_DIR/*`
        au moment du `update-alternatives --install`
  - [ ] gérer les slaves différents entre versions (autorisé par
        `update-alternatives`)
  - [ ] adapter `node_binaries.info` : état par-version au lieu de
        global (clés `Binaries.vX.Y.Z=…`)
  - [ ] ciblage explicite : **`npm -g` uniquement** — pnpm/yarn écrivent
        dans `$HOME`, hors champ

### b. `/etc/profile.d/update-node-alternatives.sh`

Active le fallback per-user automatiquement.

- **Pourquoi** : combiné à (a), permet à un utilisateur d'overrider le
  binaire system-wide en faisant son propre `npm install -g …` sans
  sudo. Le PATH Unix arbitre seul (per-user prioritaire), aucune
  logique custom dans le wrapper. Couvre le TODO existant
  « Intégration `/etc/profile.d/` » de `AGENTS.md`.
- **À faire** :
  - [ ] livrer un script qui exporte
        `NPM_CONFIG_PREFIX="$HOME/.npm-global"` (sauf si déjà défini)
  - [ ] préfixer `$NPM_CONFIG_PREFIX/bin` au `PATH`
  - [ ] bash + zsh

### c. Complétion `update-node-alternatives`

- **Pourquoi** : ergonomie ; aujourd'hui aucun complétion live.
- **À faire** :
  - [ ] `debian/update-node-alternatives.bash-completion`
        (via `dh_bashcomp`)
  - [ ] installée dans
        `/usr/share/bash-completion/completions/update-node-alternatives`
  - [ ] indépendant des points (a) et (b)

### d. Hook automatique post-`npm -g`

- **Pourquoi** : éviter à l'utilisateur de penser à
  `update-node-alternatives -u` après chaque `npm i -g`.
- **Pistes** (à trancher au démarrage de la phase 2) :
  - [ ] piste 1 : wrapper sur `npm` — nécessite ré-architecture
        master/slave (`npm` master au lieu de `node` ?)
  - [ ] piste 2 : `inotifywait` daemon sur `lib/node_modules/` — lourd
  - [ ] piste 3 : ne rien automatiser, documenter
        `update-node-alternatives -u` (option de moindre effort)

### e. Doc man page

- **À faire** :
  - [ ] décrire le workflow admin (sudo + system-wide) vs user (PATH
        per-user)
  - [ ] décrire la complémentarité (a) + (b)
  - [ ] décrire le mécanisme de fallback per-user via `PATH`

### f. Promotion per-user → system-wide + nettoyage `$HOME`

Deux sous-commandes séparées par privilèges
(cf. rapport [§ 5.4](docs/localisation-node-binaires.md)).

- **Pourquoi** : factoriser les paquets globaux disséminés dans les
  `$HOME` sans que l'admin ait à les inventorier ; permettre à chaque
  utilisateur de nettoyer son `$HOME` quand il le souhaite. Conforme
  aux conventions Debian si la séparation root/user est stricte.
- **Dépendance** : nécessite (a) — les slaves dynamiques. Sans eux, la
  promotion crée `lib/node_modules/@angular/cli` mais pas
  `/usr/local/bin/ng`.
- **À faire** :
  - [ ] `--promote-user-globals` (root via sudo) :
    - [ ] détecter `$SUDO_USER` ; refuser si invocation sans sudo
    - [ ] lire les prefixes user dynamiquement
          (`npm config get prefix --userconfig`, `pnpm root -g`,
          `yarn global dir`)
    - [ ] lister les paquets per-user non encore system-wide
    - [ ] checklist interactive (`dialog_checklist`, frontend déjà en
          place)
    - [ ] réinstaller via `npm i -g` dans la couche 2
    - [ ] appeler `do_update()` pour rafraîchir les slaves
  - [ ] `--cleanup-user-globals` (user, refuse sudo) :
    - [ ] ajouter à `NO_ROOT_ACTIONS`
    - [ ] refuser net si `id -u == 0`
    - [ ] comparer per-user vs system-wide
    - [ ] ne proposer cochables que les paquets présents des deux côtés
    - [ ] désinstaller via le gestionnaire d'origine
          (`npm uninstall -g --prefix=…`, `pnpm uninstall -g`,
          `yarn global remove`)
  - [ ] pivotement étape 1 → 2 :
    - [ ] à la fin de `--promote-user-globals`, `dialog_yesno`
    - [ ] si oui : `exec sudo -u "$SUDO_USER" "$0" --cleanup-user-globals`
          (drop privileges propre)
- **Garde-fous** :
  - [ ] lecture seule de `$HOME` côté root
  - [ ] ne jamais réutiliser registry/tokens du `.npmrc` user pour
        l'install root
  - [ ] `DEBIAN_FRONTEND=noninteractive` ⇒ rapport seul, aucune action
  - [ ] idempotence : skip si version system-wide ≥ version per-user
  - [ ] signaler les conflits de version ou proposer l'installation de la version de node du paquet per-user pour le rendre system-wide

---

## Décisions tranchées

- ✓ **pnpm et yarn ne sont pas ciblés pour un usage system-wide via
  leurs gestionnaires propres**. Leurs paquets `-g` écrivent dans
  `$HOME` ; les forcer dans la couche 2 casserait le store CAS de pnpm
  et imposerait sudo systématique. Voir § 5.3 du rapport.
- ✓ **Mais** leurs paquets per-user *peuvent* être promus en
  system-wide via la sous-commande (f), qui réinstalle uniformément
  avec `npm install -g`.
