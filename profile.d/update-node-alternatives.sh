# shellcheck shell=sh
# update-node-alternatives: expose the per-user npm prefix in PATH so that
# `npm install -g <pkg>` without sudo can override the system-wide
# alternative for the same binary. update-node-alternatives(8) manages the
# system-wide layer; the resolution is left to PATH order.
#
# Default the per-user prefix to ~/.npm-global unless the user already
# configured one (NPM_CONFIG_PREFIX, ~/.npmrc prefix=...). This file is
# sourced under POSIX sh by /etc/profile.

[ -n "${HOME:-}" ] || return 0

if [ -z "${NPM_CONFIG_PREFIX:-}" ]; then
    NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export NPM_CONFIG_PREFIX
fi

case ":$PATH:" in
    *":$NPM_CONFIG_PREFIX/bin:"*) : ;;
    *) PATH="$NPM_CONFIG_PREFIX/bin:$PATH" ;;
esac
export PATH
