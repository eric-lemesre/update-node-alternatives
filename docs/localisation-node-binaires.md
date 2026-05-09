# Rapport — Localisation des bibliothèques Node et binaires dans `update-node-alternative`

> **Date** : 2026-05-09
> **Contexte** : analyse préalable aux phases d'évolution du packaging
> (rename `update-node-alternative` → `update-node-alternatives`, adoption
> debconf scénario 1.b, hook sur `npm -g`).

## 1. Vue d'ensemble — quatre couches superposées

```
┌─────────────────────────────────────────────────────────────────────┐
│  COUCHE 1 — paquet (sous /usr/, ou /usr/local/ via make install)    │
│  • Script wrapper, man page, nvm vendoré                            │
│  • Propriétaire: dpkg / Makefile                                    │
│  • Statique, immuable hors mise à jour de paquet                    │
├─────────────────────────────────────────────────────────────────────┤
│  COUCHE 2 — versions Node installées (NVM-driven)                   │
│  • /usr/local/share/nvm/versions/node/vX.Y.Z/                       │
│  • Propriétaire: NVM (invoqué par le wrapper)                       │
│  • Dynamique, créé par --install, supprimé par --remove             │
├─────────────────────────────────────────────────────────────────────┤
│  COUCHE 3 — alternatives Debian (update-alternatives)               │
│  • /etc/alternatives/{node,npm,npx,corepack}                        │
│  • Propriétaire: dpkg / update-alternatives                         │
│  • Bascule en pointant vers une vX.Y.Z de la couche 2               │
├─────────────────────────────────────────────────────────────────────┤
│  COUCHE 4 — paquets npm globaux + leurs binaires                    │
│  • lib/node_modules/<pkg>/  +  bin/<symlink>  dans chaque vX.Y.Z/   │
│  • Alimentée uniquement par `npm install -g` (pnpm/yarn → $HOME)    │
│  • ⚠ ANGLE MORT — non géré par update-alternatives                  │
└─────────────────────────────────────────────────────────────────────┘
```

## 2. Cartographie détaillée des chemins

### Couche 1 — fichiers fournis par le paquet

| Chemin (mode paquet) | Chemin (mode `make install`) | Origine | Quoi |
|---|---|---|---|
| `/usr/sbin/update-node-alternative` | `/usr/local/sbin/update-node-alternative` | `Makefile install` (PREFIX) | Script wrapper bash |
| `/usr/share/man/man8/update-node-alternative.8` | `/usr/local/share/man/man8/update-node-alternative.8` | idem | Man page (`.8` car wrapper sysadmin) |
| `/usr/share/update-node-alternative/nvm/nvm.sh` | `/usr/local/share/update-node-alternative/nvm/nvm.sh` | `vendor/nvm/` | NVM vendoré |
| `/usr/share/update-node-alternative/nvm/nvm-exec` | idem | idem | Helper NVM (exécutable) |
| `/usr/share/update-node-alternative/nvm/bash_completion` | idem | idem | **Présent mais inactif** — non sourcé |
| `/usr/share/update-node-alternative/nvm/{LICENSE.md,VERSION}` | idem | idem | Métadata vendor |

`load_nvm()` (`update-node-alternative:499‑532`) cherche `nvm.sh` dans cet ordre :

1. `/usr/share/update-node-alternative/nvm/nvm.sh` *(paquet)*
2. `<dirname $0>/vendor/nvm/nvm.sh` *(exécution depuis sources)*
3. `$NVM_DIR/nvm.sh` = `/usr/local/share/nvm/nvm.sh` *(legacy / héritage de l'ancien `install-node-alternative.sh`)*

### Couche 2 — données runtime NVM (commun aux deux modes d'install)

`NVM_DIR=/usr/local/share/nvm` (codé en dur, `update-node-alternative:25`)

```
/usr/local/share/nvm/
├── alias/                    ← noms LTS résolus (lts/jod, lts/iron, …)
├── .cache/                   ← cache de téléchargements NVM (jamais purgé, TODO)
└── versions/
    ├── node_binaries.info    ← état: "Binaries=node npm npx corepack"
    └── node/
        └── vX.Y.Z/           ← UNE installation Node complète
            ├── bin/             ← node, npm, npx, corepack [+ binaires npm globaux]
            ├── lib/
            │   └── node_modules/   ← paquets npm globaux installés ici
            ├── include/         ← headers Node (node.h, …)
            ├── share/           ← man pages Node, doc
            └── CHANGELOG.md
```

**Sur la machine de référence** (Debian sid de l'auteur) :

```
/usr/local/share/nvm/versions/node/
  v18.20.8   v22.20.0   v22.22.1   v22.22.2   v24.14.0   v24.15.0
```

Permissions hétérogènes (mix `eric` et `root`) : héritage d'installations
antérieures faites avant l'adoption du paquet. Aucune incidence
fonctionnelle, mais ça illustre que la couche 2 a une **vie propre** — le
paquet la prend telle quelle.

### Couche 3 — alternatives Debian

| Chemin                                 | Type    | Pointé par                     | Pointe vers                                          |
|----------------------------------------|---------|--------------------------------|------------------------------------------------------|
| `/usr/local/bin/node`                  | symlink | utilisateur (`PATH`)           | `/etc/alternatives/node`                             |
| `/usr/local/bin/npm`                   | symlink | utilisateur (`PATH`)           | `/etc/alternatives/npm`                              |
| `/usr/local/bin/npx`                   | symlink | utilisateur (`PATH`)           | `/etc/alternatives/npx`                              |
| `/usr/local/bin/corepack`              | symlink | utilisateur (`PATH`)           | `/etc/alternatives/corepack`                         |
| `/etc/alternatives/node`               | symlink | `update-alternatives`          | `/usr/local/share/nvm/versions/node/vX.Y.Z/bin/node` |
| `/etc/alternatives/{npm,npx,corepack}` | symlink | `update-alternatives` (slaves) | `…/vX.Y.Z/bin/{npm,npx,corepack}`                    |
| `/var/lib/dpkg/alternatives/node`      | DB      | dpkg                           | priorités, slaves, mode auto/manual                  |

**Master** : `node`. **Slaves** : `npm`, `npx`, `corepack`
(`CORE_BINARIES`, `update-node-alternative:31`). Priorité :
`major*100 + minor` → v24.15.0 = 2415
(`update-node-alternative:536‑542`).

État vérifié sur la machine :

```
Status: manual    Best/Value: /usr/local/share/nvm/versions/node/v24.15.0/bin/node
6 alternatives enregistrées (v18.20.8 .. v24.15.0)
```

### Couche 4 — paquets npm globaux

C'est ici que se joue l'enjeu de la **phase 2** (hook sur `npm -g`).

> **Important** : seul `npm install -g` peuple cette couche. `pnpm` et
> `yarn` ont chacun leur propre store **per-user** dans `$HOME`
> (cf. encadré « Cas particulier » plus bas) ; ils ne contribuent ni à
> `…/vX.Y.Z/lib/node_modules/` ni à `…/vX.Y.Z/bin/`.

```
/usr/local/share/nvm/versions/node/vX.Y.Z/
├── bin/
│   ├── node, npm, npx, corepack       ← GÉRÉS par update-alternatives (slaves)
│   ├── ng, ngcc                       ← installés par `npm -g @angular/cli`
│   ├── pnpm, pnpx, yarn, yarnpkg      ← installés par `npm -g pnpm yarn`
│   │                                       (les binaires des installers
│   │                                        eux-mêmes — pas leurs paquets)
│   ├── tsc                            ← installés par `npm -g typescript`
│   └── …                              ← AUCUN n'est slave d'update-alternatives
└── lib/
    └── node_modules/
        ├── corepack/                  ← fourni par Node (exclu de la migration)
        ├── npm/                       ← fourni par Node (exclu de la migration)
        ├── @angular/                  ← scope, peut contenir N paquets
        │   └── cli/                       (binaires créés dans ../bin/)
        ├── codex-sdk-container/
        ├── pnpm/                      ← installer pnpm lui-même
        └── …
```

Confirmation factuelle sur la machine :

```
v22.20.0/lib/node_modules/   →  @angular  codex-sdk-container  corepack  npm
v22.20.0/bin/                →  corepack ng node npm npx pnpm pnpx yarn yarnpkg
                                         ^^                  ^^^^^^^^^^^^^^^^^^^^
                                         binaires "fantômes" — non slaves
```

`collect_global_packages()` (`update-node-alternative:579‑627`) **liste**
ces paquets pour les migrer entre versions, mais leurs binaires ne
deviennent **jamais** des entrées `update-alternatives`. Conséquence
directe : si l'utilisateur fait `npm i -g @angular/cli` sur v22.20.0,
`/usr/local/bin/ng` n'existe pas — l'utilisateur doit ajouter
`…/v22.20.0/bin/` à son `PATH`, ou le wrapper doit créer un slave.

#### Cas particulier — pnpm et yarn ont des stores per-user

Bien que `pnpm` et `yarn` soient présents dans `…/vX.Y.Z/bin/` (parce
qu'ils ont été installés via `npm -g pnpm yarn` ou par `corepack`), ils
**n'écrivent pas** dans la couche 2 quand on les utilise pour installer
globalement. Vérification factuelle (Debian sid, machine de référence) :

| Installateur            | Store des paquets globaux                              | Couche concernée    |
|-------------------------|--------------------------------------------------------|---------------------|
| `npm install -g …`      | `…/vX.Y.Z/lib/node_modules/` (suit le prefix de Node)  | **Couche 2**        |
| `pnpm add -g …`         | `~/.local/share/pnpm/global/<n>/node_modules`          | **Per-user**        |
| `yarn global add …` (1) | `~/.config/yarn/global` ; binaires `~/.yarn/bin`       | **Per-user**        |

Mesures prises :

```
$ /usr/local/bin/npm config get prefix
/usr/local/share/nvm/versions/node/v24.15.0
$ /usr/local/share/nvm/versions/node/v22.20.0/bin/pnpm root -g
/home/eric/.local/share/pnpm/global/5/node_modules
$ /usr/local/share/nvm/versions/node/v22.20.0/bin/yarn global dir
/home/eric/.config/yarn/global
```

**Implication** : seul `npm install -g` justifie un hook system-wide.
Les paquets installés par `pnpm` ou `yarn` sont déjà locaux à
l'utilisateur — leur visibilité dans le `PATH` est de la responsabilité
de l'utilisateur (via `~/.bashrc`, `~/.zshrc`, `corepack`, etc.), hors
champ d'`update-alternatives`.

## 3. Cycle de vie par chemin

| Chemin                                             | Création                                        | Modification                      | Suppression                                                 |
|----------------------------------------------------|-------------------------------------------------|-----------------------------------|-------------------------------------------------------------|
| `/usr/sbin/update-node-alternative`                | `dpkg -i`                                       | `dpkg --upgrade`                  | `apt remove`                                                |
| `/usr/share/update-node-alternative/nvm/*`         | `dpkg -i`                                       | `make vendor-nvm` + rebuild       | `apt remove`                                                |
| `/usr/local/share/nvm/{alias,.cache}`              | `load_nvm()` (`mkdir -p`)                       | NVM en interne                    | jamais (TODO: cache cleanup)                                |
| `/usr/local/share/nvm/versions/node/vX.Y.Z/`       | `--install` (NVM télécharge)                    | `npm i -g …` (ajoute des modules) | `--remove` (NVM uninstall)                                  |
| `/usr/local/share/nvm/versions/node_binaries.info` | `do_update()` (`update-node-alternative:915`)   | idem                              | jamais                                                      |
| `/etc/alternatives/{node,…}`                       | `do_update()` → `update-alternatives --install` | `--set` / `--auto`                | `--remove[-all]` (script `do_remove`) ou `postrm` sur purge |
| `/usr/local/bin/{node,…}`                          | gérés par `update-alternatives`                 | idem                              | idem                                                        |

**Postrm** (`debian/update-node-alternative.postrm`) : sur `purge`
uniquement, exécute `update-alternatives --remove-all` pour les 4
binaires. Le store NVM (`/usr/local/share/nvm/`) est **conservé** (choix
délibéré, documenté).

## 4. Tensions et angles morts

### 4.1 — Couche 2 prend tout `/usr/local/share/nvm/`, pas un sous-dossier propre au paquet

`NVM_DIR` est codé en dur dans le script. C'est cohérent avec le choix
« system-wide » (un seul store partagé), **mais** :

- Le paquet écrit dans `/usr/local/`, ce qui est **inhabituel** pour un
  paquet Debian (FHS recommande `/var/lib/<pkg>/` pour state runtime).
  C'est un choix assumé pour rester compatible avec
  `update-alternatives` → `/usr/local/bin/`.
- `apt purge` ne nettoie pas ce store (postrm le préserve). Une
  réinstallation reprend l'état précédent → **bonne ergonomie**, **mais**
  lintian ou les puristes pourraient pointer la non-FHS.

### 4.2 — Couche 4 (paquets npm globaux) hors radar des alternatives

C'est le **point névralgique** que cible la phase 2. Détails :

- Les binaires installés par `npm -g` (uniquement — pnpm/yarn écrivent
  dans `$HOME`, cf. § Couche 4) apparaissent dans `vX.Y.Z/bin/` mais ne
  sont pas déclarés comme slaves.
- Quand on bascule de v22 à v24, `/usr/local/bin/ng` n'existe pas (ou
  pire, pointe via `/etc/alternatives/ng` vers une version Node retirée
  si on l'avait ajouté à la main).
- `update-alternatives` n'a pas de mécanisme de **slaves dynamiques**
  (les slaves sont fixés au premier `--install`). Pour ajouter `ng` après
  coup, il faut **remove + reinstall** la même alternative avec la
  nouvelle liste de slaves → c'est ce que fait déjà `do_update()`
  (`update-node-alternative:872‑923`) en supprimant tout puis
  ré-enregistrant. Donc techniquement, ajouter des slaves à la volée est
  faisable, il « suffit » de :
  1. détecter post-`npm -g` les binaires nouvellement créés dans
     `…/vX.Y.Z/bin/` (diff vs `node_binaries.info`),
  2. relancer `do_update()` avec la liste élargie.

### 4.3 — `bash_completion` de NVM livré mais inactif

`/usr/share/update-node-alternative/nvm/bash_completion` est fourni mais
ce paquet expose `update-node-alternative`, **pas** `nvm` (il n'y a pas
de `nvm` dans le `PATH` utilisateur). Cette complétion n'a donc aucun
usage tel quel. Le paquet n'a **pas** de complétion pour
`update-node-alternative` lui-même → confirmé sujet de la phase 2.

### 4.4 — `/etc/alternatives/` invisible dans la doc et le script

Ce répertoire est pourtant **le** trait d'union entre `/usr/local/bin/node`
(vu par l'utilisateur) et `…/vX.Y.Z/bin/node` (le vrai binaire). Le
script ne le manipule jamais directement (`update-alternatives` s'en
charge), mais ni le `README` ni la man page ne le mentionnent. Pour un
wrapper d'`update-alternatives`, ça mériterait d'être tracé dans la man
page.

### 4.5 — Le « legacy fallback » de `load_nvm()`

Le 3ᵉ candidat dans `load_nvm()` (`$NVM_DIR/nvm.sh` =
`/usr/local/share/nvm/nvm.sh`) **est présent** sur cette machine
(139 220 octets). Vraisemblablement laissé par l'ancien
`install-node-alternative.sh`. Le candidat #1
(`/usr/share/update-node-alternative/nvm/nvm.sh`) gagne aujourd'hui via
le paquet. À long terme, ce 3ᵉ candidat est mort code — utile pour la
transition, à supprimer plus tard.

## 5. Implications pour la roadmap

### Pour la phase 1 (rename + debconf 1.b + alignement standards)

- Le **rename** `update-node-alternative` → `update-node-alternatives`
  impacte **uniquement la couche 1** (chemins du paquet). Les couches
  2-3-4 ont des chemins indépendants (`/usr/local/share/nvm/`,
  `/etc/alternatives/`) → **pas de migration de données utilisateur**, ce
  qui simplifie énormément la transition.
- Le **debconf 1.b** doit interagir avec la couche 2 : la question
  « quelle version Node installer maintenant ? » déclenche un `--install`
  qui peuple `…/versions/node/`. Penser à un mode `noninteractive` qui
  n'installe rien (sécurité buildd, conteneur).
- La **prise en compte d'`update-alternatives` au niveau packaging**
  signifie surtout : décider si le `postrm` doit aussi nettoyer la
  **couche 2** sur purge (ou rester comme aujourd'hui, où elle survit), et
  documenter ce contrat. `dh_installalternatives` n'aide pas ici puisque
  les entrées sont créées au runtime (master `node`, slaves dynamiques).

### Pour la phase 2 (complétion + hook npm `-g`)

- **Complétion** : à fournir dans
  `debian/update-node-alternative.bash-completion` (debhelper standard
  `dh_bashcomp`), installé dans
  `/usr/share/bash-completion/completions/update-node-alternative`. Pas
  de chevauchement avec couches 2-3-4.
- **Hook `npm -g`** : ciblage limité à `npm install -g` (pnpm/yarn ont
  des stores per-user, hors champ d'`update-alternatives` —
  cf. § Couche 4). Trois pistes techniquement viables :
  1. **Hook côté Node** via une variable d'environnement npm
     (`npm config set …`) : fragile, dépend de l'utilisateur.
  2. **Wrapper de `npm`** : remplacer `npm` dans `/usr/local/bin/` par un
     script qui appelle le vrai `npm` puis détecte les nouveaux binaires
     et fait `update-node-alternatives -u`. Conflit avec
     `update-alternatives` (qui possède déjà ce lien).
  3. **`dpkg-trigger`** : non, npm n'est pas dpkg.
  4. **`inotifywait` sur `lib/node_modules/`** (daemon) : lourd.

  La plus propre conceptuellement est **(2)** mais il faut
  ré-architecturer : `npm` master au lieu de `node` master ? Ou un slave
  `npm-real` + le master devient un wrapper ? À discuter quand la phase 2
  démarrera.

### 5.3 — Stratégie system-wide + fallback per-user (cas `ng`, `tsc`, …)

**Question** : peut-on rendre `ng` (Angular CLI) et autres outils
installés via `npm -g` system-wide, tout en autorisant un override
per-user ?

**Réponse** : oui, et le « fallback per-user » est **gratuit** — il est
géré par la sémantique standard du `PATH` Unix, sans aucune logique à
ajouter dans le wrapper.

#### Mécanique

```
Utilisateur tape `ng` dans son shell
  │
  ├─→ recherche dans $PATH, dans l'ordre
  │     1. $HOME/.npm-global/bin/ng    ← per-user (gagne s'il existe)
  │     2. /usr/local/bin/ng           ← system-wide (slave update-alternatives)
  │     3. /usr/bin/ng                 ← jamais (pas de paquet Debian `ng`)
  │
  └─→ premier trouvé = exécuté
```

#### Côté admin (system-wide)

```
sudo update-node-alternatives -i 22
sudo npm install -g @angular/cli       # → …/v22.X.Y/bin/ng
sudo update-node-alternatives -u       # do_update() élargi → /usr/local/bin/ng
```

→ Phase 2, slaves dynamiques dans `do_update()` (cf. § 4.2).

#### Côté utilisateur (per-user) — déjà supporté nativement par npm

```
# une fois (~/.bashrc ou via /etc/profile.d/, cf. infra)
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

# puis sans sudo
npm install -g @angular/cli            # → ~/.npm-global/bin/ng
```

`~/.npm-global/bin` étant **avant** `/usr/local/bin` dans le `PATH`, la
version per-user gagne quand elle existe ; sinon, l'utilisateur retombe
naturellement sur le `ng` exposé par l'admin.

#### Le chaînon manquant — `/etc/profile.d/update-node-alternatives.sh`

C'est le TODO déjà inscrit dans `CLAUDE.md` (« Intégration
`/etc/profile.d/` pour exposer le PATH des binaires npm globaux installés
par utilisateur »). Le paquet pourrait livrer un fichier du type :

```sh
# /etc/profile.d/update-node-alternatives.sh
# Expose le prefix npm per-user dans le PATH pour permettre
# le fallback automatique sur les binaires installés par l'utilisateur.
if [ -n "$BASH_VERSION" ] || [ -n "$ZSH_VERSION" ]; then
    : "${NPM_CONFIG_PREFIX:=$HOME/.npm-global}"
    export NPM_CONFIG_PREFIX
    case ":$PATH:" in
        *":$NPM_CONFIG_PREFIX/bin:"*) ;;
        *) PATH="$NPM_CONFIG_PREFIX/bin:$PATH" ;;
    esac
fi
```

#### Synthèse

| Composante                                    | Effet                                                            | Effort      |
|-----------------------------------------------|------------------------------------------------------------------|-------------|
| Slaves dynamiques dans `do_update()`          | rend `ng`/`pnpm`/`yarn`/`tsc`/… system-wide quand admin installe | ~15 lignes  |
| `/etc/profile.d/update-node-alternatives.sh`  | active le fallback per-user automatiquement                      | ~10 lignes  |
| Doc man page (workflow admin/user)            | clarifie les deux modes                                          | rédaction   |

**Aucune logique de fallback** n'est nécessaire dans le wrapper. Le
`PATH` Unix arbitre tout dès lors que les deux composantes ci-dessus
sont en place.

### 5.4 — Promotion per-user → system-wide (et nettoyage du `$HOME`)

**Idée** : factoriser les paquets globaux disséminés dans les `$HOME`
des utilisateurs en les promouvant dans la couche 2, sans que l'admin
ait à connaître chaque paquet à la main. Et symétriquement, permettre
à chaque utilisateur de nettoyer son `$HOME` une fois la promotion
faite.

#### Conformité Debian

**Verdict** : conforme aux conventions, à condition de **séparer les
deux moitiés en fonction des privilèges** (cf. § « Architecture
deux-niveaux » ci-dessous).

| Convention                                            | Respect | Comment                                                            |
|-------------------------------------------------------|---------|--------------------------------------------------------------------|
| Policy 9.1.1 — pas de modification de `$HOME`         | oui     | Le script en root lit `$HOME` mais n'y écrit jamais                |
| Privileges minimaux                                   | oui     | Lecture `$HOME` via `$SUDO_USER` ; install system-wide via root    |
| `DEBIAN_FRONTEND=noninteractive`                      | oui     | En non-interactive : rapport seul, aucune action                   |
| Pas d'effet de bord destructif                        | oui     | Le per-user reste en place après promotion ; suppression déléguée  |
| Idempotence                                           | oui     | Skip si paquet déjà présent system-wide avec même version          |

Précédents Debian comparables : `update-grub`, `update-initramfs`,
`update-mime-database` — tous lisent un état dispersé pour le réagencer
côté système.

#### Architecture deux-niveaux

Pour respecter strictement la séparation root/user, **deux
sous-commandes distinctes** plutôt qu'une seule monolithique :

```
update-node-alternatives --promote-user-globals     [root]
update-node-alternatives --cleanup-user-globals     [user — sans sudo]
```

| Sous-commande                | Privilèges    | Domaine de modification        | Ce qu'elle fait                                                                        |
|------------------------------|---------------|--------------------------------|----------------------------------------------------------------------------------------|
| `--promote-user-globals`     | root          | couches 2 + 3 (system-wide)    | Lit `$SUDO_USER`'s `$HOME` ; installe via `npm i -g` dans la couche 2 ; rafraîchit alt |
| `--cleanup-user-globals`     | user (no sudo)| `$HOME` de l'invoquant         | Liste les paquets per-user **aussi** présents system-wide ; désinstalle au choix       |

**Pourquoi deux commandes** : aucune ne franchit la frontière
root/user. Le premier touche à `/usr/local/`, le second à `~/`. Aucun
besoin de `drop privileges`, ni de manipuler `$SUDO_USER` pour faire de
l'écriture cross-user.

`--cleanup-user-globals` rejoint la liste `NO_ROOT_ACTIONS` (déjà
présente, `update-node-alternative:1050`) avec `list`, `list_remote`,
`list_packages`.

#### Flux complet

```
┌──── ÉTAPE 1 : promotion (root) ──────────────────────────────────┐
│                                                                  │
│  $ sudo update-node-alternatives --promote-user-globals          │
│                                                                  │
│  :: Scan des paquets npm globaux per-user pour 'eric'            │
│     (lit /home/eric/.npm-global/, ~/.local/share/pnpm/global/,   │
│      ~/.config/yarn/global/)                                     │
│                                                                  │
│  Trouvé per-user (non encore system-wide) :                      │
│    @angular/cli@18.2.1   [npm]                                   │
│    eslint@9.7.0          [pnpm]                                  │
│  Déjà system-wide (ignorés) :                                    │
│    typescript@5.5.3                                              │
│                                                                  │
│  [Checklist dialog/zenity/kdialog/readline]                      │
│    ☑ @angular/cli       ☑ eslint                                 │
│                                                                  │
│  :: Installation via npm dans v24.15.0…                          │
│  :: Réenregistrement des alternatives (slaves dynamiques)…       │
│  ✓ 2 paquet(s) promu(s) en system-wide.                          │
│                                                                  │
│  ➜ Pour libérer l'espace dans /home/eric/, relance sans sudo :   │
│       update-node-alternatives --cleanup-user-globals            │
│  ➜ Lancer maintenant ? [o/N]                                     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                                ↓ si « oui », `exec sudo -u $SUDO_USER …`
┌──── ÉTAPE 2 : nettoyage (user, no sudo) ─────────────────────────┐
│                                                                  │
│  $ update-node-alternatives --cleanup-user-globals               │
│                                                                  │
│  :: Comparaison per-user vs system-wide                          │
│                                                                  │
│  Paquets per-user redondants avec system-wide :                  │
│                                                                  │
│  [Checklist dialog/zenity/kdialog/readline]                      │
│    ☑ @angular/cli  18.2.1  (système: 18.2.1) → npm uninstall -g  │
│    ☑ eslint        9.7.0   (système: 9.7.0)  → pnpm uninstall -g │
│    ☐ ts-node       10.9.1  (système: ABSENT) [ne pas désinstaller]
│                                                                  │
│  :: Désinstallation per-user via les gestionnaires d'origine…    │
│  ✓ 2 paquet(s) nettoyé(s) de /home/eric/.                        │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Note importante sur l'étape 2** : seuls les paquets *à la fois*
per-user *et* system-wide sont proposés à la désinstallation. Les
paquets per-user uniques (`ts-node` dans l'exemple) sont listés mais
**non cochables** — supprimer leur version per-user retirerait
l'outil de l'utilisateur.

Chaque désinstallation utilise le **gestionnaire d'origine** :

| Origine               | Désinstallation                                           |
|-----------------------|-----------------------------------------------------------|
| `~/.npm-global/`      | `npm uninstall -g --prefix=$HOME/.npm-global <pkg>`       |
| `~/.local/share/pnpm/`| `pnpm uninstall -g <pkg>`                                 |
| `~/.config/yarn/`     | `yarn global remove <pkg>`                                |

→ respecte hooks `preuninstall`/`postuninstall` et la cohérence des
métadonnées (`package-lock`, store CAS pnpm, etc.).

#### Garde-fous indispensables

```bash
# 1. Promotion : doit s'exécuter via sudo (sinon pas d'écriture couche 2)
target_user="${SUDO_USER:-$USER}"
[ -n "$target_user" ] && [ "$target_user" != root ] || {
    echo >&2 "$prog: --promote-user-globals doit être invoqué via sudo"
    exit 1
}
target_home=$(getent passwd "$target_user" | cut -d: -f6)

# 2. Cleanup : DOIT être lancé sans sudo (refus net si root)
[ "$(id -u)" -ne 0 ] || {
    echo >&2 "$prog: --cleanup-user-globals ne s'exécute pas en root"
    echo >&2 "  Relancez en tant qu'utilisateur normal (sans sudo)."
    exit 1
}

# 3. Découverte dynamique des prefixes (ne pas coder en dur ~/.npm-global)
user_npm_prefix=$(sudo -u "$target_user" npm config get prefix --userconfig)
user_pnpm_dir=$(sudo -u "$target_user" pnpm root -g 2>/dev/null)
user_yarn_dir=$(sudo -u "$target_user" yarn global dir 2>/dev/null)

# 4. Lecture seule des configs $HOME : ne PAS réutiliser registry/tokens
#    de l'utilisateur quand on installe en root. `npm install -g`
#    s'exécute avec la config root (registry public par défaut).

# 5. Idempotence : skip si version system-wide ≥ version per-user

# 6. noninteractive : rapport seul, aucune install ni uninstall
```

#### Pivotement automatique étape 1 → étape 2

Pour offrir l'UX continue souhaitée, la fin de
`--promote-user-globals` (en root) propose à l'utilisateur de relancer
immédiatement `--cleanup-user-globals`. L'implémentation drop les
privilèges proprement :

```bash
if dialog_yesno "Nettoyer le \$HOME ?" \
    "Lancer maintenant le nettoyage en tant que $target_user ?"; then
    # Exec en mode user — le script ré-entre dans NO_ROOT_ACTIONS
    exec sudo -u "$target_user" \
        DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-}" \
        DISPLAY="${DISPLAY:-}" \
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
        "$0" --cleanup-user-globals
fi
```

→ `exec` remplace le processus root par un processus user, garantissant
qu'**aucune** opération sur `$HOME` ne se fait avec des privilèges root.

#### Cas particuliers à anticiper

1. **Conflit de versions** : per-user `@angular/cli@17` + system-wide
   `@angular/cli@18` → la promotion crée une divergence. Avertir
   explicitement (« la version per-user 17.x sera occultée par
   system-wide 18.x dans ton PATH »).
2. **Multi-utilisateurs** : Alice promeut, Bob retombe sur la version
   d'Alice. Comportement attendu, à documenter.
3. **Modules natifs** : la réinstallation via `npm i -g` recompile pour
   l'arch de l'admin (potentiellement différente de l'utilisateur si
   installation via container). En pratique non-bloquant sur Debian
   classique.
4. **Paquet per-user installé manuellement** (sans gestionnaire) : pas
   de désinstallation propre possible. Le scan le détecte mais ne le
   propose pas pour cleanup automatique.

#### Bénéfices côté UX

- L'utilisateur garde sa main sur son `$HOME` (sa machine, son rythme).
- L'admin n'a pas à inventorier chaque paquet — le scan fait le tour.
- Le nettoyage est facultatif : le user peut accepter la promotion mais
  refuser de toucher à son `$HOME`, et inversement (`--cleanup-user-globals`
  fonctionne aussi en autonome, sans avoir fait de promotion).

#### Lien avec la phase 2

Cette fonctionnalité **dépend** des slaves dynamiques (sous-point a) :
sans eux, promouvoir `@angular/cli` ne crée pas `/usr/local/bin/ng`,
donc la promotion serait incomplète. À implémenter **après** les slaves
dynamiques, comme sous-point f de la phase 2.

---

**TL;DR** — Le paquet vit dans 4 zones indépendantes : son install
(couche 1, sous `/usr/`), le store NVM (couche 2, sous
`/usr/local/share/nvm/`), les liens `update-alternatives` (couche 3,
`/etc/alternatives` + `/usr/local/bin`), et les paquets `npm -g`
(couche 4, **non gérés**). Le rename et debconf n'affectent que la
couche 1. La couche 4 est l'angle mort que vise correctement la
phase 2 — l'enrichir nécessite soit des slaves dynamiques via
`do_update()` (faisable, réenregistrement complet déjà implémenté), soit
un wrapper sur `npm`. À noter : `pnpm` et `yarn` n'écrivent pas dans la
couche 2 (stores per-user dans `$HOME`), donc le hook ne concerne que
`npm install -g`.
