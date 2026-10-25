# update-node-alternatives

[English](../README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | **Español** | [Italiano](README.it.md) | [Português (Brasil)](README.pt_BR.md)

Un gestor de versiones de Node.js a nivel de sistema para Debian, en el
espíritu de
[`update-java-alternatives(8)`](https://manpages.debian.org/update-java-alternatives).

Combina la infraestructura [NVM](https://github.com/nvm-sh/nvm) (para
descargar y almacenar los binarios de Node.js) con el mecanismo
[`update-alternatives(1)`](https://manpages.debian.org/update-alternatives)
de Debian (para alternar el enlace simbólico `node` a nivel de
sistema — los esclavos como `npm`, `npx`, `corepack`, además de
cualquier binario depositado por `sudo npm install -g` para esa
versión, se descubren dinámicamente). Una interfaz interactiva
estilo debconf se proporciona mediante `whiptail` (con respaldo en
`dialog` o readline simple).

## Características

- Instalar, eliminar y listar versiones de Node.js mediante NVM
- Cambiar la versión activa a nivel de sistema con `update-alternatives`
  (modo manual o automático)
- `node` es el enlace maestro; los esclavos se descubren dinámicamente
  escaneando `<version>/bin/`, de modo que los binarios depositados
  por `sudo npm install -g` (`ng`, `tsc`, `pnpm`, ...) quedan
  expuestos bajo `/usr/local/bin/`
- Prioridad calculada automáticamente a partir de la versión de
  Node.js: `major * 1000000 + minor * 1000 + patch` (p. ej. `v22.14.0` → `22014000`)
- Migración interactiva de paquetes npm globales entre versiones
  (checklist)
- Promover los paquetes `npm install -g` por usuario a la capa de
  sistema (`--promote-user-globals`) y limpiar las copias por usuario
  redundantes (`--cleanup-user-globals`)
- Incluye `/etc/profile.d/update-node-alternatives.sh` para que un
  `npm i -g` ejecutado por un usuario normal aterrice automáticamente
  en `~/.npm-global` y sobrescriba el binario del sistema mediante el
  orden de `PATH`
- Autocompletado bash bajo `/usr/share/bash-completion/completions/`
- Respeta `DEBIAN_FRONTEND` (véase
  [`debconf(7)`](https://manpages.debian.org/debconf.7)); admite
  `dialog` (whiptail/dialog), `readline`, `gnome` (zenity), `kde`
  (kdialog) y `noninteractive`. Detección automática si no está
  definido.

## Inicio rápido

```bash
# Compilar e instalar (desde el árbol de fuentes)
sudo make install   # instala script + página de manual + nvm embebido bajo $PREFIX (por defecto /usr/local)

# Instalar la última Node 22 y registrarla
sudo update-node-alternatives --install 22

# Cambiar a ella
sudo update-node-alternatives --set v22.14.0

# Comprobar el estado
update-node-alternatives --list
```

Para un paquete Debian completo:

```bash
make deb
sudo apt install -y ../update-node-alternatives_*.deb
```

## Uso

```
usage: update-node-alternatives [-v|--verbose] <action> [options]

Acciones NVM:
  -i, --install <version>            Instalar una versión de Node.js
  -r, --remove <version>             Eliminar una versión instalada
  -R, --list-remote [--lts]          Listar versiones disponibles para descarga
  -p, --list-packages <version>      Listar paquetes npm globales de una versión
  --upgrade <version> [--from <ver>] Instalar, activar y migrar paquetes
  --reinstall-packages --from <ver> --to <ver>
                                     Migrar paquetes globales entre dos versiones
  --install-packages [--to <ver>]    Instalar en <ver> (por defecto: la activa) paquetes
                                       globales de las otras versiones, tras comprobar
                                       engines.node

Acciones update-alternatives:
  -l, --list                         Listar versiones instaladas
  -s, --set <nodename>               Establecer la versión activa (modo manual)
  -u, --update                       Re-registrar todas las versiones en alternatives
                                       (reejecutar tras `npm install -g <pkg>`
                                       para exponer <pkg> bajo /usr/local/bin)
  -a, --auto                         Cambiar a modo automático (máxima prioridad)

Paquetes npm -g por usuario:
  --promote-user-globals             [root] Promover los paquetes `npm i -g`
                                       de $SUDO_USER a la capa del sistema
  --cleanup-user-globals             [usuario] Eliminar los paquetes `npm i -g`
                                       por usuario ya cubiertos a nivel sistema

Opciones:
  -v, --verbose                      Salida detallada
  --frontend <name>                  Forzar el frontend: dialog, readline,
                                       gnome, kde, noninteractive
  --no-dialog                        Alias de --frontend=readline
  -h, --help                         Mostrar la ayuda
```

Véase [`update-node-alternatives(8)`](../update-node-alternatives.8) para el manual completo.

## Ejemplos

```bash
# Instalar la última LTS mediante un alias
sudo update-node-alternatives --install lts/jod

# Listar las versiones LTS disponibles para descarga
update-node-alternatives --list-remote --lts

# Mostrar los paquetes globales de una versión instalada
update-node-alternatives --list-packages v22.14.0

# Actualizar de v20 a v22 con migración interactiva de paquetes
sudo update-node-alternatives --upgrade 22 --from v20.18.1

# Migrar los paquetes globales entre dos versiones ya instaladas
sudo update-node-alternatives --reinstall-packages --from v20.18.1 --to v22.14.0

# Elegir paquetes globales de las otras versiones e instalarlos en la
# versión activa (los rangos engines.node incompatibles quedan desmarcados)
sudo update-node-alternatives --install-packages

# Pasar al modo automático (gana la prioridad más alta)
sudo update-node-alternatives --auto

# Tras un `npm install -g` a nivel de sistema, exponer <pkg> bajo /usr/local/bin
sudo npm install -g @angular/cli
sudo update-node-alternatives --update

# Promover los paquetes `npm i -g` por usuario de $SUDO_USER a la capa
# de sistema (y proponer limpiar las copias por usuario justo después)
sudo update-node-alternatives --promote-user-globals

# Eliminar los paquetes `npm i -g` por usuario ya cubiertos a nivel
# de sistema en la misma versión o una más reciente
update-node-alternatives --cleanup-user-globals
```

## Estructura

```
/usr/local/share/nvm/                 # NVM a nivel de sistema
  nvm.sh, nvm-exec
  versions/node/vX.Y.Z/               # versiones de Node.js instaladas
  versions/node_binaries.info         # fichero de estado (unión + por versión)
/usr/local/sbin/update-node-alternatives
/usr/local/bin/node                   # enlace maestro (update-alternatives)
/usr/local/bin/{npm,npx,corepack,...} # esclavos dinámicos (también ng, tsc, ...)
/usr/local/share/man/man8/update-node-alternatives.8
/etc/profile.d/update-node-alternatives.sh           # NPM_CONFIG_PREFIX + PATH
/usr/share/bash-completion/completions/update-node-alternatives
```

## Dependencias

- `bash` ≥ 4.0 (arrays asociativos)
- `whiptail` **o** `dialog` (opcional — repliegue a readline)
- `curl` **o** `wget` (usado por NVM para descargar Node.js)
- `update-alternatives` (proporcionado por `dpkg`)

## Compilación y desarrollo

```bash
make help           # listar los targets disponibles
make check          # ejecutar shellcheck
sudo make install   # instalar en $PREFIX (por defecto /usr/local)
sudo make uninstall # eliminar los ficheros instalados
sudo make purge     # uninstall + eliminar alternativas + /usr/local/share/nvm/
make man            # ver la página de manual
```

### Migrar desde un nvm por usuario

Si antes usabas `~/.nvm`, copia las versiones de Node.js instaladas al
almacén de sistema y vuelve a registrarlas con `update-alternatives`:

```bash
sudo mkdir -p /usr/local/share/nvm/versions/node
sudo cp -a ~/.nvm/versions/node/* /usr/local/share/nvm/versions/node/
sudo update-node-alternatives --update
```

### Empaquetado Debian

```bash
make deb            # construye el .deb en ../ (envuelve dpkg-buildpackage -us -uc -b)
make deb-clean      # limpia los artefactos del build Debian
lintian ../update-node-alternatives_*.changes
```

### nvm embebido

El paquete incluye una copia upstream de
[nvm](https://github.com/nvm-sh/nvm) bajo `vendor/nvm/` (instalada en
`/usr/share/update-node-alternatives/nvm/`). La versión exacta se
registra en `vendor/nvm/VERSION` y se anuncia desde el paquete
binario mediante `Provides: bundled-nvm-<version>`.

```bash
make vendor-nvm-show               # mostrar la versión nvm actualmente embebida
make check-upstream                # comprobar nuevas releases (uscan + debian/watch)
make vendor-nvm NVM_VERSION=0.40.4 # refrescar vendor/nvm/ a una versión dada
```

`make vendor-nvm` ejecuta `debian/vendor-nvm.sh`, que descarga el
tarball upstream, reemplaza los ficheros bajo `vendor/nvm/`,
actualiza `vendor/nvm/VERSION` e incrementa
`Provides: bundled-nvm-<version>` en `debian/control`. Tras la
ejecución, añadir una entrada de changelog con
`dch -i "Update bundled nvm to <version>."`, hacer commit y luego
`make deb`.

## Licencia

GPL-2.0-or-later — véase [LICENSE](../LICENSE).

## Autor

Eric Lemesre <eric.lemesre@gmail.com>
