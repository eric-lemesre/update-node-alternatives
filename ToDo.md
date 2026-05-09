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

## Phase 1bis — Traductions debconf

Suite directe de la phase 1 (debconf 1.b) : fournir des `.po` pour les
templates dans les langues les plus actives de Debian.

- **Pourquoi** : les `_Description:` sont déjà préparés pour po-debconf
  (`debian/po/templates.pot` est généré). Une bonne couverture
  linguistique est attendue pour un paquet qui pose des questions
  debconf à l'install.
- **Cibles** (top ~10 par activité de traduction sur
  [i18n.debian.org](https://www.debian.org/international/l10n/po-debconf/rank))
  — brouillons générés le 2026-05-09 via `command-r:latest` (Ollama
  local, 32B), sortie JSON contrainte, validés `msgfmt -c` :
  - [x] `fr.po` — français (relu par `magistral:latest`, prêt)
  - [x] `de.po` — allemand (brouillon, attente relecture native)
  - [x] `es.po` — espagnol (brouillon, attente relecture native)
  - [x] `it.po` — italien (brouillon, attente relecture native)
  - [x] `pt_BR.po` — portugais brésilien (brouillon, attente relecture native)
  - [x] `nl.po` — néerlandais (brouillon, attente relecture native)
  - [x] `ru.po` — russe (brouillon, attente relecture native)
  - [x] `ja.po` — japonais (brouillon, attente relecture native)
  - [x] `cs.po` — tchèque (brouillon, attente relecture native)
  - [x] `sv.po` — suédois (brouillon, attente relecture native)
- **Méthode** :
  - [x] `cd debian/po && msginit --no-translator --no-wrap -i templates.pot -o <lang>.po -l <lang>`
        (forcer `LANG=<lang>.UTF-8` pour `pt_BR` afin d'éviter un
        squelette ISO-8859-1)
  - [x] traduction LLM : `command-r:latest` via Ollama, prompt JSON
        strict (préserve `\n`, `\"`, valeurs Choices intouchées,
        identifiants techniques intouchés)
  - [x] `debconf-updatepo` après chaque modification du
        `debian/templates`
  - [ ] vérification interactive par langue :
        `podebconf-display-po debian/po/<lang>.po`
  - [ ] appels à traduction sur les listes `debian-l10n-<lang>`
        après publication, pour relecture native
- **Notes** :
  - `fr.po` est relu et prêt ; les 9 autres restent des brouillons
    automatiques utiles comme base pour les listes `debian-l10n-*`
  - lintian signale `package-needs-versioned-debconf-dependency` ou
    `unknown-locale-code` si une langue n'est pas reconnue ; choisir
    des codes ISO standard

---

## Phase 2 — Hook `npm -g`, complétion, promotion per-user ✅

Implémentée le 2026-05-09 dans le changelog `0.4.0~UNRELEASED`.

### a. Slaves dynamiques dans `do_update()` ✅

- [x] `CORE_BINARIES` figé retiré ; `scan_slaves()` énumère
      `$NODEBIN_DIR/*` (exécutable, hors `node`, hors dotfiles, hors
      répertoires) à chaque `do_update()`
- [x] `update-alternatives --install` reçoit la liste de slaves propre
      à chaque version (autorisé par `update-alternatives`)
- [x] `node_binaries.info` v2 : `Binaries=…` (union, compat 0.3) +
      `Binaries.vX.Y.Z=…` par version
- [x] `postrm` lit l'union depuis `node_binaries.info` pour purger
      proprement les slaves dynamiques (`ng`, `tsc`, …) au lieu de
      cabler `node npm npx corepack`

### b. `/etc/profile.d/update-node-alternatives.sh` ✅

- [x] script POSIX sh idempotent qui exporte
      `NPM_CONFIG_PREFIX="$HOME/.npm-global"` si non défini
- [x] préfixe `$NPM_CONFIG_PREFIX/bin` au `PATH`
- [x] livré sous `/etc/profile.d/` (sourcé par bash, sh, et zsh quand
      celui-ci hérite de `/etc/profile`)
- [x] Makefile : nouvelle variable `PROFILED` (absolue, hors `PREFIX`)

### c. Complétion `update-node-alternatives` ✅

- [x] `bash-completion/update-node-alternatives` complète options
      longues/courtes, versions installées (`--remove`, `--set`,
      `--list-packages`, `--from`, `--to`), frontends valides, et
      hint d'alias LTS pour `--install`/`--upgrade`
- [x] Makefile install vers
      `$(PREFIX)/share/bash-completion/completions/`
- [x] indépendant des points (a) et (b)

### d. Hook automatique post-`npm -g` ✅ (option 3)

- [x] **décision** : ne rien automatiser. Documenter
      `update-node-alternatives --update` comme point de re-sync
      explicite après `sudo npm install -g <pkg>`
- [x] piste 1 (wrapper `npm`) : rejetée — invasif, casse l'écosystème
      npm
- [x] piste 2 (`inotifywait` daemon) : rejetée — coûteux pour le
      besoin
- [x] piste 3 retenue, mention explicite dans `update-node-alternatives(8)`

### e. Doc man page ✅

- [x] sous-section *Per-user override* (profile.d + arbitrage par PATH)
- [x] sous-section *Per-user globals* (workflow promote/cleanup,
      modèle de privilèges, ségrégation `.npmrc`, idempotence)
- [x] EXAMPLES pour `npm i -g` + `--update`,
      `--promote-user-globals`, `--cleanup-user-globals`
- [x] FILES : `/etc/profile.d/`, completion, schéma `node_binaries.info`
- [x] ENVIRONMENT : `NPM_CONFIG_PREFIX`, `SUDO_USER`
- [x] PRIVILEGES réécrit pour mentionner cleanup (refuse root) et
      promote (exige `$SUDO_USER`)
- [x] README.md / README.fr.md mis à jour côté Features et Usage

### f. Promotion per-user → system-wide + nettoyage `$HOME` ✅

- [x] `--promote-user-globals` (root via sudo) :
  - [x] refuse sans `$SUDO_USER`
  - [x] découverte du prefix npm utilisateur via
        `sudo -u $SUDO_USER -H npm config get prefix` puis repli
        `~/.npm-global`
  - [x] liste les paquets per-user non couverts system-wide (ou avec
        version per-user > system)
  - [x] checklist interactive (réutilise `dialog_checklist`)
  - [x] installation system-wide via `HOME=/root npm install -g …`
        — **jamais** d'héritage du `.npmrc` utilisateur (registry,
        tokens privés)
  - [x] `do_update()` final pour exposer les nouveaux slaves
- [x] `--cleanup-user-globals` (user, refuse sudo) :
  - [x] ajouté à `NO_ROOT_ACTIONS`
  - [x] refus net si `id -u == 0`
  - [x] ne propose cochable que `system >= user` (idempotence)
  - [x] désinstallation via `npm uninstall -g <pkg>`
- [x] pivotement étape 1 → 2 :
  - [x] `dialog_yesno` à la fin de `--promote-user-globals`
  - [x] si oui : `exec sudo -u "$SUDO_USER" -H -- "$0"
        --cleanup-user-globals`
- [x] garde-fous :
  - [x] lecture seule de `$HOME` côté root (jamais d'écriture)
  - [x] `HOME=/root` à l'install root
  - [x] `DEBIAN_FRONTEND=noninteractive` ⇒ rapport seul
  - [x] idempotence par comparaison `dpkg --compare-versions`
- [ ] **différé** : signaler les conflits de version Node entre
      paquet per-user et version system active (point listé dans le
      rapport § 5.4 mais non bloquant pour la première version)
- [ ] **différé** : support natif pnpm/yarn (`pnpm root -g`,
      `yarn global dir`) — l'implémentation actuelle s'appuie
      uniquement sur npm car les binaires per-user pnpm/yarn finissent
      sous `~/.npm-global` quand l'utilisateur les installe via npm

---

## Décisions tranchées

- ✓ **pnpm et yarn ne sont pas ciblés pour un usage system-wide via
  leurs gestionnaires propres**. Leurs paquets `-g` écrivent dans
  `$HOME` ; les forcer dans la couche 2 casserait le store CAS de pnpm
  et imposerait sudo systématique. Voir § 5.3 du rapport.
- ✓ **Mais** leurs paquets per-user *peuvent* être promus en
  system-wide via la sous-commande (f), qui réinstalle uniformément
  avec `npm install -g`.
