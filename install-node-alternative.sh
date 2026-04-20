#!/bin/bash
#
# install-node-alternative.sh
# Helper facultatif pour les installations hors-paquet et les migrations.
#
# Une fois le paquet Debian installe (apt install update-node-alternative),
# ce script n'est pas necessaire : le binaire, la man page et NVM sont deja
# fournis. Il reste utile pour :
#   - bootstrapper une installation depuis le code source (sans .deb)
#   - migrer les versions Node d'un ~/.nvm vers le NVM system-wide
#   - desinstaller proprement une installation hors-paquet (--uninstall)
#
# Usage:
#   sudo ./install-node-alternative.sh              # installation complete
#   sudo ./install-node-alternative.sh --migrate    # migrer ~/.nvm uniquement
#   sudo ./install-node-alternative.sh --uninstall  # tout nettoyer
#
# Copyright (C) 2026 Eric Lemesre <eric.lemesre@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later
#

set -euo pipefail

NVM_DIR="/usr/local/share/nvm"
SRC_DIR="$(dirname "$(readlink -f "$0")")"
SCRIPT_DST="/usr/local/sbin/update-node-alternative"
MAN_DST="/usr/local/share/man/man8/update-node-alternative.8"
PKG_NVM_DIR="/usr/local/share/update-node-alternative/nvm"

USER_NVM="${HOME:-}/.nvm"
if [ -n "${SUDO_USER:-}" ]; then
    USER_NVM="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.nvm"
fi

require_root()
{
    if [ "$(id -u)" -ne 0 ]; then
        echo >&2 "Ce script doit etre execute en tant que root (sudo)"
        exit 1
    fi
}

do_migrate()
{
    echo ":: Migration des versions depuis $USER_NVM/versions/node"
    if [ ! -d "$USER_NVM/versions/node" ]; then
        echo "  Aucun NVM per-user a $USER_NVM"
        return
    fi
    local has_any=
    for d in "$USER_NVM/versions/node"/*/; do
        [ -d "$d" ] || continue
        has_any=yes
        echo "  - $(basename "$d")"
    done
    if [ -z "$has_any" ]; then
        echo "  Aucune version a migrer."
        return
    fi
    echo
    read -rp "  Copier ces versions dans $NVM_DIR/versions/node ? [o/N] " answer
    if [[ "$answer" =~ ^[oOyY] ]]; then
        mkdir -p "$NVM_DIR/versions/node"
        cp -a "$USER_NVM/versions/node"/* "$NVM_DIR/versions/node/"
        echo "  -> Versions copiees. Executez: sudo update-node-alternative --update"
    else
        echo "  -> Ignore."
    fi
}

do_install()
{
    require_root
    echo "=== Installation hors-paquet de update-node-alternative ==="

    # Preferer l'installation via make install (si source disponible)
    if [ -f "$SRC_DIR/Makefile" ] && [ -f "$SRC_DIR/update-node-alternative" ]; then
        echo "[1/3] make install PREFIX=/usr/local"
        make -C "$SRC_DIR" install PREFIX=/usr/local
    else
        echo "  Sources introuvables dans $SRC_DIR (Makefile manquant)"
        echo "  Installez plutot via le paquet Debian: sudo dpkg -i update-node-alternative_*.deb"
        exit 1
    fi

    echo "[2/3] Creation de $NVM_DIR (stockage des versions Node.js)..."
    mkdir -p "$NVM_DIR"/{versions/node,alias,.cache}

    echo "[3/3] Migration des versions existantes (optionnelle)..."
    if [ -d "$USER_NVM/versions/node" ]; then
        do_migrate
    else
        echo "  Aucun NVM per-user detecte (pas de migration)."
    fi

    echo
    echo "=== Installation terminee ==="
    echo "  Installez une version:  sudo update-node-alternative --install 22"
    echo "  Listez les versions:    update-node-alternative --list"
}

do_uninstall()
{
    require_root
    echo "=== Desinstallation de update-node-alternative ==="

    if dpkg -s update-node-alternative &>/dev/null; then
        echo "  Le paquet Debian est installe."
        echo "  Utilisez plutot: sudo apt purge update-node-alternative"
        echo "  (ce script ne touche que les fichiers /usr/local/)"
        echo
    fi

    echo "[1/3] Retrait des alternatives..."
    for alt in node npm npx corepack; do
        update-alternatives --remove-all "$alt" 2>/dev/null || true
    done

    echo "[2/3] Suppression du script et de la man page (/usr/local)..."
    rm -f "$SCRIPT_DST" "$MAN_DST"
    rm -rf "$PKG_NVM_DIR"

    echo "[3/3] Suppression du stockage Node.js..."
    if [ -d "$NVM_DIR" ]; then
        read -rp "  Supprimer $NVM_DIR (contient toutes les versions Node) ? [o/N] " answer
        if [[ "$answer" =~ ^[oOyY] ]]; then
            rm -rf "$NVM_DIR"
            echo "  -> $NVM_DIR supprime"
        else
            echo "  -> $NVM_DIR conserve"
        fi
    fi

    echo
    echo "=== Desinstallation terminee ==="
}

case "${1:-install}" in
    install)   do_install ;;
    --migrate) require_root; do_migrate ;;
    --uninstall) do_uninstall ;;
    -h|--help)
        sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \?//'
        exit 0 ;;
    *)
        echo >&2 "$0: option inconnue: $1"
        echo >&2 "Usage: $0 [install|--migrate|--uninstall|--help]"
        exit 1 ;;
esac
