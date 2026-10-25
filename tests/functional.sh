#!/bin/bash
#
# Tests fonctionnels de update-node-alternatives, sans root ni reseau.
#
# Le script teste est copie dans un repertoire temporaire et pointe sur un
# NVM_DIR et un ALTBIN_DIR jetables ; update-alternatives est enveloppe pour
# utiliser un --altdir/--admindir jetable. Les versions de Node sont fausses :
# leur 'node' est un script bash qui journalise les appels a npm. Le PATH
# reproduit un secure_path de sudo sans /usr/local/bin.
#
# Usage: tests/functional.sh [script]   (defaut: ./update-node-alternatives)
#
# Copyright (C) 2026 Eric Lemesre <eric.lemesre@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

# Les conditions passees a check() sont evaluees plus tard par eval, d'ou les
# simples quotes (SC2016) et des variables lues seulement dans eval (SC2034).
# shellcheck disable=SC2016,SC2034

set -u

SRC=$(readlink -f "${1:-$(dirname "$0")/../update-node-alternatives}")
SB=$(mktemp -d "${TMPDIR:-/tmp}/una-test.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$SB"' EXIT
mkdir -p "$SB"/{alt,admin,bin,localbin,nvm/versions/node}
LOG="$SB/npm.log"
UA="$SB/bin/update-alternatives"

failures=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

# Un vrai node et un module semver servent a la verification engines.node ;
# sans eux (build minimal), les tests correspondants sont sautes.
REAL_NODE=$(command -v node || command -v nodejs || true)
SEMVER=
for c in /usr/share/nodejs/semver \
         "$(dirname "$(readlink -f "${REAL_NODE:-/nonexistent}")")/../lib/node_modules/npm/node_modules/semver"; do
    [ -f "$c/package.json" ] && { SEMVER=$(readlink -f "$c"); break; }
done
have_engines=
[ -n "$REAL_NODE" ] && [ -n "$SEMVER" ] && have_engines=yes
check_engines() { if [ -n "$have_engines" ]; then check "$@"; else echo "skip - $1 (pas de node/semver)"; fi; }

cat > "$UA" <<EOF
#!/bin/bash
exec /usr/bin/update-alternatives --altdir "$SB/alt" --admindir "$SB/admin" "\$@"
EOF
chmod +x "$UA"

# mkver <vX.Y.Z> "<paquet>[:<engines.node>] ..."
mkver()
{
    local v=$1 pkgs=$2 d="$SB/nvm/versions/node/$1" p name range
    mkdir -p "$d/bin" "$d/lib/node_modules/npm/node_modules" "$d/lib/node_modules/corepack"
    [ -z "$SEMVER" ] || ln -s "$SEMVER" "$d/lib/node_modules/npm/node_modules/semver"
    cat > "$d/bin/node" <<EOF
#!/bin/bash
if [ "\${1:-}" = --version ]; then echo $v; exit 0; fi
if [ "\${1:-}" = -e ]; then [ -n "$REAL_NODE" ] || exit 1; exec "$REAL_NODE" "\$@"; fi
script=\$1; shift
case "\$script" in
    */npm) [ "\${1:-}" = --version ] && { echo npm-of-$v; exit 0; }
           echo "node=$v npm=\$script args=\$*" >> "$LOG" ;;
esac
EOF
    printf '#!/usr/bin/env node\n' > "$d/bin/npm"
    chmod +x "$d/bin/node" "$d/bin/npm"
    for p in $pkgs; do
        name=${p%%:*} range=
        [ "$name" = "$p" ] || range=${p#*:}
        mkdir -p "$d/lib/node_modules/$name"
        {
            printf '{\n  "version": "1.0.0",\n  "description": "fake %s"' "$name"
            [ -z "$range" ] || printf ',\n  "engines": { "node": "%s" }' "$range"
            printf '\n}\n'
        } > "$d/lib/node_modules/$name/package.json"
    done
}
mkver v20.1.0 ""
mkver v22.2.0 ""
mkver v24.3.0 "pkg-a:>=24 pkg-b @scope/pkg-c:>=18 pkg-d"

sed -e "s|^readonly NVM_DIR=.*|readonly NVM_DIR=\"$SB/nvm\"|" \
    -e "s|^readonly ALTBIN_DIR=.*|readonly ALTBIN_DIR=\"$SB/localbin\"|" \
    -e 's|if \[ "\$(id -u)" -ne 0 \]; then|if false; then|' \
    "$SRC" > "$SB/una"
chmod +x "$SB/una"
una() { "$SB/una" --frontend readline "$@" 2>&1; }

export PATH="$SB/bin:/usr/sbin:/usr/bin:/sbin:/bin"
status() { "$UA" --query node | awk '/^Status:/{print $2}'; }
active() { "$UA" --query node | awk '/^Value:/{print $2}' | grep -oP 'v[\d.]+'; }

una --update >/dev/null
check "--update enregistre les 3 versions" '[ "$("$UA" --list node | wc -l)" -eq 3 ]'
check "--update sans choix manuel : auto sur la plus haute" \
    '[ "$(status)" = auto ] && [ "$(active)" = v24.3.0 ]'

out=$(una --set v22.2.0 <<< "n")
check "--set v22.2.0 active v22.2.0 en manuel" \
    '[ "$(status)" = manual ] && [ "$(active)" = v22.2.0 ]'
check "--set : npm --version marche sans /usr/local/bin dans le PATH" \
    'grep -q "npm:  npm-of-v22.2.0" <<< "$out"'

una --update >/dev/null
check "--update conserve le choix manuel" \
    '[ "$(status)" = manual ] && [ "$(active)" = v22.2.0 ]'

out=$(una --set v20.1.0 <<< "a")
check "--set : migration depuis la version remplacee (v22.2.0, vide)" \
    'grep -q "Aucun paquet global a migrer depuis v22.2.0" <<< "$out"'
check "--set : pas de paquets de la plus haute version proposes" \
    '! grep -q pkg-a <<< "$out"'

: > "$LOG"
out=$(una --reinstall-packages --from v24.3.0 --to v20.1.0 <<< "a")
check "--reinstall-packages reussit" 'grep -q "4 paquet(s) installe(s)" <<< "$out"'
check "--reinstall-packages : npm de v20.1.0 lance par node v20.1.0, en --engine-strict" \
    '[ "$(grep -c "^node=v20.1.0 npm=.*/v20.1.0/bin/npm args=install -g --engine-strict " "$LOG")" -eq 4 ]'
check_engines "--reinstall-packages : pkg-a (node >=24) signale incompatible avec v20.1.0" \
    'grep -qE "\[ \] [0-9]+\) pkg-a .*INCOMPATIBLE: node >=24" <<< "$out"'

rm -rf "$SB/nvm/versions/node/v20.1.0"
out=$(una --update)
check "--update : version manuelle disparue -> retour en auto avec message" \
    '[ "$(status)" = auto ] && grep -q "retour en mode auto" <<< "$out"'

mkver v24.3.9 "pkg-b"
mkver v24.3.10 ""
out=$(una --list)
check "priorite : le patch compte (v24.3.10 -> 24003010)" \
    'grep -qE "v24\.3\.10 +24003010 " <<< "$out"'
una --auto >/dev/null
check "--auto : v24.3.10 l'emporte sur v24.3.9 et v24.3.0" '[ "$(active)" = v24.3.10 ]'

# --install-packages : recensement de toutes les versions vers la cible
mkdir -p "$SB/nvm/versions/node/v22.2.0/lib/node_modules/pkg-d"
printf '{\n  "version": "0.9.0"\n}\n' > "$SB/nvm/versions/node/v22.2.0/lib/node_modules/pkg-d/package.json"
: > "$LOG"
out=$(una --install-packages --to v22.2.0 <<< "1 3")
[ -z "${KEEP:-}" ] || printf "%s\n" "$out" > "$SB/install-packages.out"
check "--install-packages : paquets regroupes par nom, plus haute version de node d'abord" \
    'grep -qE "\) pkg-b +1\.0\.0@v24\.3\.9 1\.0\.0@v24\.3\.0" <<< "$out"'
check "--install-packages : paquet deja present dans la cible decoche" \
    'grep -qE "\[ \] [0-9]+\) pkg-d .*deja installe: 0\.9\.0" <<< "$out"'
check "--install-packages : paquet sans engines.node coche, marque non verifie" \
    'grep -qE "\[\*\] [0-9]+\) pkg-b .*non verifie" <<< "$out"'
check_engines "--install-packages : pkg-a (node >=24) decoche pour v22.2.0" \
    'grep -qE "\[ \] [0-9]+\) pkg-a .*INCOMPATIBLE: node >=24" <<< "$out"'
check_engines "--install-packages : @scope/pkg-c (node >=18) coche et compatible" \
    'grep -qE "\[\*\] 1\) @scope/pkg-c .*compatible: node >=18" <<< "$out"'
check "--install-packages : selection installee par le npm/node de v22.2.0" \
    'grep -q "^node=v22.2.0 .*args=install -g --engine-strict @scope/pkg-c$" "$LOG" &&
     grep -q "^node=v22.2.0 .*args=install -g --engine-strict pkg-b$" "$LOG" &&
     [ "$(wc -l < "$LOG")" -eq 2 ]'
out=$(una --install-packages <<< "n")
check "--install-packages sans --to : cible = version active (v24.3.10)" \
    'grep -q "installables dans v24.3.10" <<< "$out"'

echo
if [ "$failures" -eq 0 ]; then
    echo "Tous les tests passent."
else
    echo "$failures test(s) en echec."
    exit 1
fi
