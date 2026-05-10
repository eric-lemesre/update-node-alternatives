# update-node-alternatives

[English](../README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Italiano](README.it.md) | **Português (Brasil)**

Um gerenciador de versões do Node.js para todo o sistema no Debian,
no estilo de
[`update-java-alternatives(8)`](https://manpages.debian.org/update-java-alternatives).

Combina a infraestrutura [NVM](https://github.com/nvm-sh/nvm) (para
baixar e armazenar os binários do Node.js) com o mecanismo
[`update-alternatives(1)`](https://manpages.debian.org/update-alternatives)
do Debian (para alternar o symlink `node` em todo o sistema — os
slaves como `npm`, `npx`, `corepack`, além de qualquer binário
depositado por `sudo npm install -g` para aquela versão, são
descobertos dinamicamente). Uma interface interativa estilo debconf
é fornecida via `whiptail` (com fallback para `dialog` ou readline
simples).

## Recursos

- Instalar, remover e listar versões do Node.js via NVM
- Alternar a versão ativa em todo o sistema com `update-alternatives`
  (modo manual ou automático)
- `node` é o link mestre; os slaves são descobertos dinamicamente
  ao escanear `<version>/bin/`, de modo que os binários depositados
  por `sudo npm install -g` (`ng`, `tsc`, `pnpm`, ...) são expostos
  sob `/usr/local/bin/`
- Prioridade calculada automaticamente a partir da versão do
  Node.js: `major * 100 + minor` (ex.: `v22.14.0` → `2214`)
- Migração interativa de pacotes npm globais entre versões
  (checklist)
- Promover pacotes `npm install -g` por usuário para a camada de
  sistema (`--promote-user-globals`) e limpar as cópias por usuário
  redundantes (`--cleanup-user-globals`)
- Inclui `/etc/profile.d/update-node-alternatives.sh` para que um
  `npm i -g` de um usuário comum aterrisse automaticamente em
  `~/.npm-global` e sobrescreva o binário do sistema via a ordem
  do `PATH`
- Autocompletar bash sob `/usr/share/bash-completion/completions/`
- Respeita `DEBIAN_FRONTEND` (veja
  [`debconf(7)`](https://manpages.debian.org/debconf.7)); suporta
  `dialog` (whiptail/dialog), `readline`, `gnome` (zenity), `kde`
  (kdialog) e `noninteractive`. Detectado automaticamente quando
  não definido.

## Início rápido

```bash
# Compilar e instalar (a partir da árvore de fontes)
sudo make install   # instala script + página man + nvm embutido sob $PREFIX (padrão /usr/local)

# Instalar a Node 22 mais recente e registrá-la
sudo update-node-alternatives --install 22

# Alternar para ela
sudo update-node-alternatives --set v22.14.0

# Verificar o status
update-node-alternatives --list
```

Para um pacote Debian completo:

```bash
make deb
sudo apt install -y ../update-node-alternatives_*.deb
```

## Uso

```
usage: update-node-alternatives [-v|--verbose] <action> [options]

Ações NVM:
  -i, --install <version>            Instalar uma versão do Node.js
  -r, --remove <version>             Remover uma versão instalada
  -R, --list-remote [--lts]          Listar versões disponíveis para download
  -p, --list-packages <version>      Listar os pacotes npm globais de uma versão
  --upgrade <version> [--from <ver>] Instalar, ativar e migrar pacotes
  --reinstall-packages --from <ver> --to <ver>
                                     Migrar os pacotes globais entre duas versões

Ações update-alternatives:
  -l, --list                         Listar as versões instaladas
  -s, --set <nodename>               Definir a versão ativa (modo manual)
  -u, --update                       Re-registrar todas as versões em alternatives
                                       (re-executar após `npm install -g <pkg>`
                                       para expor <pkg> sob /usr/local/bin)
  -a, --auto                         Alternar para o modo automático (maior prioridade)

Pacotes npm -g por usuário:
  --promote-user-globals             [root] Promover os pacotes `npm i -g` de
                                       $SUDO_USER para a camada de sistema
  --cleanup-user-globals             [user] Remover os pacotes `npm i -g`
                                       por usuário já cobertos pelo sistema

Opções:
  -v, --verbose                      Saída detalhada
  --frontend <name>                  Forçar o frontend: dialog, readline,
                                       gnome, kde, noninteractive
  --no-dialog                        Alias para --frontend=readline
  -h, --help                         Exibir a ajuda
```

Consulte [`update-node-alternatives(8)`](../update-node-alternatives.8) para o manual completo.

## Exemplos

```bash
# Instalar a última LTS pelo alias
sudo update-node-alternatives --install lts/jod

# Listar as versões LTS disponíveis para download
update-node-alternatives --list-remote --lts

# Mostrar os pacotes globais de uma versão instalada
update-node-alternatives --list-packages v22.14.0

# Atualizar de v20 para v22 com migração interativa de pacotes
sudo update-node-alternatives --upgrade 22 --from v20.18.1

# Migrar os pacotes globais entre duas versões já instaladas
sudo update-node-alternatives --reinstall-packages --from v20.18.1 --to v22.14.0

# Alternar para o modo automático (a maior prioridade vence)
sudo update-node-alternatives --auto

# Após um `npm install -g` no sistema, expor <pkg> sob /usr/local/bin
sudo npm install -g @angular/cli
sudo update-node-alternatives --update

# Promover os pacotes `npm i -g` por usuário de $SUDO_USER para a
# camada de sistema (e oferecer limpar as cópias por usuário logo após)
sudo update-node-alternatives --promote-user-globals

# Remover os pacotes `npm i -g` por usuário já cobertos no sistema
# na mesma versão ou em uma versão mais recente
update-node-alternatives --cleanup-user-globals
```

## Estrutura

```
/usr/local/share/nvm/                 # NVM no sistema
  nvm.sh, nvm-exec
  versions/node/vX.Y.Z/               # versões do Node.js instaladas
  versions/node_binaries.info         # arquivo de estado (união + por versão)
/usr/local/sbin/update-node-alternatives
/usr/local/bin/node                   # symlink mestre (update-alternatives)
/usr/local/bin/{npm,npx,corepack,...} # slaves dinâmicos (também ng, tsc, ...)
/usr/local/share/man/man8/update-node-alternatives.8
/etc/profile.d/update-node-alternatives.sh           # NPM_CONFIG_PREFIX + PATH
/usr/share/bash-completion/completions/update-node-alternatives
```

## Dependências

- `bash` ≥ 4.0 (arrays associativos)
- `whiptail` **ou** `dialog` (opcional — fallback para readline)
- `curl` **ou** `wget` (usados pelo NVM para baixar o Node.js)
- `update-alternatives` (fornecido pelo `dpkg`)

## Build e desenvolvimento

```bash
make help           # listar os targets disponíveis
make check          # executar shellcheck
sudo make install   # instalar em $PREFIX (padrão /usr/local)
sudo make uninstall # remover os arquivos instalados
sudo make purge     # uninstall + remover alternatives + /usr/local/share/nvm/
make man            # visualizar a página man
```

### Migrar de um nvm por usuário

Se você usava `~/.nvm` antes, copie as versões do Node.js instaladas
para o armazenamento do sistema e registre-as novamente com
`update-alternatives`:

```bash
sudo mkdir -p /usr/local/share/nvm/versions/node
sudo cp -a ~/.nvm/versions/node/* /usr/local/share/nvm/versions/node/
sudo update-node-alternatives --update
```

### Empacotamento Debian

```bash
make deb            # constrói o .deb em ../ (envolve dpkg-buildpackage -us -uc -b)
make deb-clean      # limpa os artefatos de build Debian
lintian ../update-node-alternatives_*.changes
```

### nvm embutido

O pacote inclui uma cópia upstream de
[nvm](https://github.com/nvm-sh/nvm) sob `vendor/nvm/` (instalada em
`/usr/share/update-node-alternatives/nvm/`). A versão exata é
registrada em `vendor/nvm/VERSION` e anunciada pelo pacote binário
via `Provides: bundled-nvm-<version>`.

```bash
make vendor-nvm-show               # mostrar a versão do nvm atualmente embutida
make check-upstream                # buscar novos releases (uscan + debian/watch)
make vendor-nvm NVM_VERSION=0.40.4 # atualizar vendor/nvm/ para uma versão dada
```

`make vendor-nvm` executa `debian/vendor-nvm.sh`, que baixa o
tarball upstream, substitui os arquivos sob `vendor/nvm/`, atualiza
`vendor/nvm/VERSION` e incrementa `Provides: bundled-nvm-<version>`
em `debian/control`. Após a execução, adicione uma entrada de
changelog com `dch -i "Update bundled nvm to <version>."`, faça
commit e em seguida `make deb`.

## Licença

GPL-2.0-or-later — veja [LICENSE](../LICENSE).

## Autor

Eric Lemesre <eric.lemesre@gmail.com>
