# ToDo — Roadmap `update-node-alternative(s)`

> Décisions prises le **2026-05-09** sur la base du rapport
> [`docs/localisation-node-binaires.md`](docs/localisation-node-binaires.md).
> Ce document est l'export actionnable de la roadmap ; les détails de
> conception complets sont dans le rapport.

## Phase 1 — Alignement standards Debian + rename

### 1. Renommer le projet/paquet

`update-node-alternative` → `update-node-alternative**s**` (avec un S
final, par cohérence avec `update-alternatives`).

- **Pourquoi** : le binaire n'est qu'un wrapper autour de
  `update-alternatives(1)`, le nom doit refléter la parenté.
- **À faire** :
  - [ ] dépôt git (rename)
  - [ ] nom du paquet Debian (`debian/control` `Source:` + `Package:`)
  - [ ] binaire installé (`/usr/sbin/update-node-alternatives`)
  - [ ] man page (renommer `.8` → ajuster `Makefile`, `debian/manpages`)
  - [ ] URLs `Vcs-*`, `Homepage:` dans `debian/control`
  - [ ] `debian/watch` (composant + main upstream)
  - [ ] `README.md`, `README.fr.md`
  - [ ] `AGENTS.md`
  - [ ] **transitional package** `update-node-alternative` qui dépend du
        nouveau nom, pour ne pas casser les installations existantes

### 2. debconf scénario 1.b — proposer une version par défaut à l'install

- **Pourquoi** : vrai standard Debian d'interaction au packaging ;
  aligne avec le TODO « configuration persistante de la version par
  défaut ».
- **À faire** :
  - [ ] `debian/templates` (question : LTS / latest / aucune / version
        choisie)
  - [ ] `debian/config` (frontend debconf qui pose la question)
  - [ ] `debian/postinst` (sourcer `/usr/share/debconf/confmodule` ;
        déclenche `update-node-alternatives --install <ver>` selon la
        réponse)
  - [ ] `debian/po/` + `Build-Depends: po-debconf`
  - [ ] vérifier compatibilité `DEBIAN_FRONTEND=noninteractive` (mode
        sûr : ne rien installer)

### 3. Prendre en compte `update-alternatives` au niveau packaging

- **Pourquoi** : le wrapper n'est qu'une surcouche ; au niveau paquet,
  on devrait au minimum déclarer la sémantique correctement et
  clarifier le contrat avec le `postrm`.
- **À faire** :
  - [ ] évaluer `dh_installalternatives` (debhelper) pour les entrées
        prévisibles, ou rester en stratégie postrm-only (à documenter)
  - [ ] décider si `postrm purge` doit aussi nettoyer la couche 2
        (`/usr/local/share/nvm/`) ou la conserver (statu quo)
  - [ ] documenter le contrat d'installation/désinstallation dans
        `debian/README.Debian`

### 4. `debian/manpages`

- **Pourquoi** : confier à `dh_installman` la compression et les
  permissions standards.
- **À faire** :
  - [ ] créer `debian/manpages` (liste : `update-node-alternative.8`,
        ou `update-node-alternatives.8` après rename)
  - [ ] retirer la copie de la man page côté `debian/rules` (elle reste
        dans `Makefile install` pour le mode hors-paquet)

### 5. `debian/upstream/metadata`

- **Pourquoi** : bonne pratique moderne (lintian le suggère),
  gain gratuit.
- **À faire** :
  - [ ] créer `debian/upstream/metadata` (Repository, Bug-Database,
        etc.)

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
  - [ ] signaler les conflits de version

---

## Décisions tranchées

- ✓ **pnpm et yarn ne sont pas ciblés pour un usage system-wide via
  leurs gestionnaires propres**. Leurs paquets `-g` écrivent dans
  `$HOME` ; les forcer dans la couche 2 casserait le store CAS de pnpm
  et imposerait sudo systématique. Voir § 5.3 du rapport.
- ✓ **Mais** leurs paquets per-user *peuvent* être promus en
  system-wide via la sous-commande (f), qui réinstalle uniformément
  avec `npm install -g`.
