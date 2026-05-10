# update-node-alternatives

[English](../README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md) | **Italiano** | [Português (Brasil)](README.pt_BR.md)

Un gestore di versioni Node.js a livello di sistema per Debian, nello
spirito di
[`update-java-alternatives(8)`](https://manpages.debian.org/update-java-alternatives).

Combina l'infrastruttura [NVM](https://github.com/nvm-sh/nvm) (per
scaricare e memorizzare i binari Node.js) con il meccanismo
[`update-alternatives(1)`](https://manpages.debian.org/update-alternatives)
di Debian (per commutare il symlink `node` a livello di sistema — gli
slave come `npm`, `npx`, `corepack`, oltre a qualsiasi binario
depositato da `sudo npm install -g` per quella versione, sono
scoperti dinamicamente). Un frontend interattivo in stile debconf è
fornito tramite `whiptail` (con ripiego su `dialog` o readline
semplice).

## Funzionalità

- Installare, rimuovere ed elencare le versioni di Node.js tramite NVM
- Commutare la versione attiva a livello di sistema con
  `update-alternatives` (modalità manuale o automatica)
- `node` è il link master; gli slave sono scoperti dinamicamente
  scansionando `<version>/bin/`, in modo che i binari depositati da
  `sudo npm install -g` (`ng`, `tsc`, `pnpm`, ...) siano esposti
  sotto `/usr/local/bin/`
- Priorità calcolata automaticamente dalla versione di Node.js:
  `major * 100 + minor` (ad es. `v22.14.0` → `2214`)
- Migrazione interattiva dei pacchetti npm globali tra versioni
  (checklist)
- Promozione dei pacchetti `npm install -g` per-utente verso il
  livello di sistema (`--promote-user-globals`) e pulizia delle
  copie per-utente ridondanti (`--cleanup-user-globals`)
- Include `/etc/profile.d/update-node-alternatives.sh` in modo che un
  `npm i -g` lanciato da un utente normale atterri automaticamente
  in `~/.npm-global` e sovrascriva il binario di sistema tramite
  l'ordine di `PATH`
- Completamento bash sotto
  `/usr/share/bash-completion/completions/`
- Rispetta `DEBIAN_FRONTEND` (vedi
  [`debconf(7)`](https://manpages.debian.org/debconf.7)); supporta
  `dialog` (whiptail/dialog), `readline`, `gnome` (zenity), `kde`
  (kdialog) e `noninteractive`. Rilevato automaticamente se non
  definito.

## Avvio rapido

```bash
# Compilare e installare (dall'albero sorgente)
sudo make install   # installa script + pagina man + nvm incorporato sotto $PREFIX (default /usr/local)

# Installa l'ultima Node 22 e la registra
sudo update-node-alternatives --install 22

# Passa a quella versione
sudo update-node-alternatives --set v22.14.0

# Verifica lo stato
update-node-alternatives --list
```

Per un pacchetto Debian completo:

```bash
make deb
sudo apt install -y ../update-node-alternatives_*.deb
```

## Utilizzo

```
usage: update-node-alternatives [-v|--verbose] <action> [options]

Azioni NVM:
  -i, --install <version>            Installa una versione di Node.js
  -r, --remove <version>             Rimuove una versione installata
  -R, --list-remote [--lts]          Elenca le versioni disponibili per il download
  -p, --list-packages <version>      Elenca i pacchetti npm globali di una versione
  --upgrade <version> [--from <ver>] Installa, attiva e migra i pacchetti
  --reinstall-packages --from <ver> --to <ver>
                                     Migra i pacchetti globali tra due versioni

Azioni update-alternatives:
  -l, --list                         Elenca le versioni installate
  -s, --set <nodename>               Imposta la versione attiva (modalità manuale)
  -u, --update                       Ri-registra tutte le versioni in alternatives
                                       (rieseguire dopo `npm install -g <pkg>`
                                       per esporre <pkg> sotto /usr/local/bin)
  -a, --auto                         Passa in modalità automatica (priorità più alta)

Pacchetti npm -g per-utente:
  --promote-user-globals             [root] Promuove i pacchetti `npm i -g` di
                                       $SUDO_USER nel livello di sistema
  --cleanup-user-globals             [user] Elimina i pacchetti `npm i -g`
                                       per-utente già coperti a livello di sistema

Opzioni:
  -v, --verbose                      Output dettagliato
  --frontend <name>                  Forza il frontend: dialog, readline,
                                       gnome, kde, noninteractive
  --no-dialog                        Alias di --frontend=readline
  -h, --help                         Mostra la guida
```

Vedi [`update-node-alternatives(8)`](../update-node-alternatives.8) per il manuale completo.

## Esempi

```bash
# Installa l'ultima LTS tramite alias
sudo update-node-alternatives --install lts/jod

# Elenca le versioni LTS disponibili per il download
update-node-alternatives --list-remote --lts

# Mostra i pacchetti globali di una versione installata
update-node-alternatives --list-packages v22.14.0

# Aggiorna da v20 a v22 con migrazione interattiva dei pacchetti
sudo update-node-alternatives --upgrade 22 --from v20.18.1

# Migra i pacchetti globali tra due versioni già installate
sudo update-node-alternatives --reinstall-packages --from v20.18.1 --to v22.14.0

# Passa in modalità automatica (vince la priorità più alta)
sudo update-node-alternatives --auto

# Dopo un `npm install -g` a livello di sistema, espone <pkg> sotto /usr/local/bin
sudo npm install -g @angular/cli
sudo update-node-alternatives --update

# Promuove i pacchetti `npm i -g` per-utente di $SUDO_USER nel livello
# di sistema (e propone di ripulire le copie per-utente subito dopo)
sudo update-node-alternatives --promote-user-globals

# Elimina i pacchetti `npm i -g` per-utente già coperti a livello di
# sistema con la stessa versione o una più recente
update-node-alternatives --cleanup-user-globals
```

## Struttura

```
/usr/local/share/nvm/                 # NVM a livello di sistema
  nvm.sh, nvm-exec
  versions/node/vX.Y.Z/               # versioni di Node.js installate
  versions/node_binaries.info         # file di stato (unione + per-versione)
/usr/local/sbin/update-node-alternatives
/usr/local/bin/node                   # symlink master (update-alternatives)
/usr/local/bin/{npm,npx,corepack,...} # slave dinamici (anche ng, tsc, ...)
/usr/local/share/man/man8/update-node-alternatives.8
/etc/profile.d/update-node-alternatives.sh           # NPM_CONFIG_PREFIX + PATH
/usr/share/bash-completion/completions/update-node-alternatives
```

## Dipendenze

- `bash` ≥ 4.0 (array associativi)
- `whiptail` **oppure** `dialog` (opzionale — ripiego su readline)
- `curl` **oppure** `wget` (usato da NVM per scaricare Node.js)
- `update-alternatives` (fornito da `dpkg`)

## Build e sviluppo

```bash
make help           # elenca i target disponibili
make check          # esegue shellcheck
sudo make install   # installa in $PREFIX (default /usr/local)
sudo make uninstall # rimuove i file installati
sudo make purge     # uninstall + rimuove alternatives + /usr/local/share/nvm/
make man            # mostra la pagina man
```

### Migrazione da un nvm per-utente

Se in precedenza usavi `~/.nvm`, copia le versioni Node.js installate
nello store di sistema e ri-registrale con `update-alternatives`:

```bash
sudo mkdir -p /usr/local/share/nvm/versions/node
sudo cp -a ~/.nvm/versions/node/* /usr/local/share/nvm/versions/node/
sudo update-node-alternatives --update
```

### Pacchettizzazione Debian

```bash
make deb            # costruisce il .deb in ../ (avvolge dpkg-buildpackage -us -uc -b)
make deb-clean      # ripulisce gli artefatti di build Debian
lintian ../update-node-alternatives_*.changes
```

### nvm incorporato

Il pacchetto include una copia upstream di
[nvm](https://github.com/nvm-sh/nvm) sotto `vendor/nvm/` (installata
in `/usr/share/update-node-alternatives/nvm/`). La versione esatta è
registrata in `vendor/nvm/VERSION` e pubblicizzata dal pacchetto
binario tramite `Provides: bundled-nvm-<version>`.

```bash
make vendor-nvm-show               # mostra la versione di nvm attualmente incorporata
make check-upstream                # cerca nuove release (uscan + debian/watch)
make vendor-nvm NVM_VERSION=0.40.4 # aggiorna vendor/nvm/ a una versione data
```

`make vendor-nvm` esegue `debian/vendor-nvm.sh`, che scarica il
tarball upstream, sostituisce i file sotto `vendor/nvm/`, aggiorna
`vendor/nvm/VERSION` e incrementa `Provides: bundled-nvm-<version>`
in `debian/control`. Al termine, aggiungere una voce nel changelog
con `dch -i "Update bundled nvm to <version>."`, fare commit, poi
`make deb`.

## Licenza

GPL-2.0-or-later — vedi [LICENSE](../LICENSE).

## Autore

Eric Lemesre <eric.lemesre@gmail.com>
