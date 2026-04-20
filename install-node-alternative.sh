#!/bin/bash
#
# install-node-alternative.sh
# Installe l'infrastructure NVM system-wide + le script update-node-alternative
#
# Usage: sudo ./install-node-alternative.sh
#

set -euo pipefail

NVM_DIR="/usr/local/share/nvm"
SCRIPT_SRC="$(dirname "$(readlink -f "$0")")/update-node-alternative"
SCRIPT_DST="/usr/local/sbin/update-node-alternative"
USER_NVM="$HOME/.nvm"

# Detecter NVM source (utiliser celui du user qui a lance sudo si possible)
if [ -n "${SUDO_USER:-}" ]; then
    USER_NVM="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.nvm"
fi

echo "=== Installation de l'infrastructure update-node-alternative ==="
echo

# 1. Creer l'arborescence NVM system-wide
echo "[1/4] Creation de $NVM_DIR..."
mkdir -p "$NVM_DIR"/{versions/node,alias,.cache}

# 2. Copier les fichiers NVM essentiels
echo "[2/4] Copie de l'infrastructure NVM..."
if [ -f "$USER_NVM/nvm.sh" ]; then
    cp "$USER_NVM/nvm.sh" "$NVM_DIR/nvm.sh"
    cp "$USER_NVM/nvm-exec" "$NVM_DIR/nvm-exec"
    [ -f "$USER_NVM/bash_completion" ] && cp "$USER_NVM/bash_completion" "$NVM_DIR/bash_completion"
    chmod 644 "$NVM_DIR/nvm.sh" "$NVM_DIR/bash_completion" 2>/dev/null || true
    chmod 755 "$NVM_DIR/nvm-exec"
    echo "  -> NVM copie depuis $USER_NVM"
else
    echo "  ERREUR: NVM introuvable dans $USER_NVM"
    echo "  Installez NVM d'abord: https://github.com/nvm-sh/nvm"
    exit 1
fi

# 3. Installer le script update-node-alternative
echo "[3/4] Installation de $SCRIPT_DST..."
if [ -f "$SCRIPT_SRC" ]; then
    cp "$SCRIPT_SRC" "$SCRIPT_DST"
    chmod 755 "$SCRIPT_DST"
    echo "  -> $SCRIPT_DST installe"
else
    echo "  ERREUR: $SCRIPT_SRC introuvable"
    exit 1
fi

# 4. Proposer de copier les versions existantes
echo "[4/4] Migration des versions existantes..."
if [ -d "$USER_NVM/versions/node" ] && [ -n "$(ls -A "$USER_NVM/versions/node" 2>/dev/null)" ]; then
    echo "  Versions trouvees dans $USER_NVM/versions/node:"
    for d in "$USER_NVM/versions/node"/*/; do
        [ -d "$d" ] || continue
        printf '    %s\n' "$(basename "$d")"
    done
    echo
    read -rp "  Copier ces versions dans $NVM_DIR/versions/node ? [o/N] " answer
    if [[ "$answer" =~ ^[oOyY] ]]; then
        cp -a "$USER_NVM/versions/node"/* "$NVM_DIR/versions/node/"
        echo "  -> Versions copiees"
    else
        echo "  -> Ignore (vous pourrez installer des versions avec: NVM_DIR=$NVM_DIR nvm install <version>)"
    fi
else
    echo "  Aucune version existante a migrer."
fi

echo
echo "=== Installation terminee ==="
echo
echo "Utilisation:"
echo "  # Installer une version node dans le NVM system-wide:"
echo "  sudo bash -c 'export NVM_DIR=$NVM_DIR && . \$NVM_DIR/nvm.sh && nvm install 22'"
echo
echo "  # Enregistrer toutes les versions dans update-alternatives:"
echo "  sudo update-node-alternative --update"
echo
echo "  # Basculer sur une version specifique:"
echo "  sudo update-node-alternative --set v22.14.0"
echo
echo "  # Mode automatique (plus recente):"
echo "  sudo update-node-alternative --auto"
echo
echo "  # Lister les versions:"
echo "  update-node-alternative --list"
