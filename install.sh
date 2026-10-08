#!/bin/sh
# Install cc-shim: a release unpacked under ~/.local/share/cc-shim/releases/<version>,
# then `cc-shim.mjs install` from it — the `claude` wrapper first on PATH, your shell
# rc files wired. POSIX (macOS, Linux); on Windows run `node cc-shim.mjs install`
# from an unpacked release.
#
#   sh install.sh [--version X.Y.Z]     a release from GitHub (default: the latest)
#   sh install.sh --from FILE.tar.gz    a tarball on disk (its .sha256 beside it is checked)
#   sh install.sh --uninstall           `cc-shim uninstall`, then the releases; never conf.d
#
# A release comes through `gh` when it is logged in (the repo may be private),
# else through curl. XDG_DATA_HOME moves the install.
set -eu

REPO=teocns/cc-shim
NODE_MIN=22.13

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

version=""
from=""
uninstall=0
while [ $# -gt 0 ]; do
  case "$1" in
    --version) [ $# -ge 2 ] || die "--version needs X.Y.Z"; version=${2#v}; shift 2 ;;
    --from) [ $# -ge 2 ] || die "--from needs a .tar.gz"; from=$2; shift 2 ;;
    --uninstall) uninstall=1; shift ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument $1 (--help lists them)" ;;
  esac
done

releases="${XDG_DATA_HOME:-$HOME/.local/share}/cc-shim/releases"

command -v node >/dev/null 2>&1 || die "node is not on PATH — cc-shim needs node ≥ $NODE_MIN"
node_ok=$(node -e 'const [a, b] = process.versions.node.split(".").map(Number); const [x, y] = process.argv[1].split(".").map(Number); console.log(a > x || (a === x && b >= y) ? "yes" : "no")' "$NODE_MIN")
[ "$node_ok" = yes ] || die "node $(node -v) is too old — cc-shim needs node ≥ $NODE_MIN"

if [ "$uninstall" = 1 ]; then
  if [ -f "$releases/current/cc-shim.mjs" ]; then
    node "$releases/current/cc-shim.mjs" uninstall
  else
    say "no release at $releases/current — nothing for cc-shim to uninstall"
  fi
  if [ -d "$releases" ]; then
    rm -rf "$releases"
    say "removed   $releases"
  fi
  say "kept      your conf.d fragments and system prompt"
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# ---- the tarball: on disk, through gh, or through curl
if [ -n "$from" ]; then
  [ -f "$from" ] || die "no file at $from"
  tarball=$from
  sumfile="$from.sha256"
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  if [ -n "$version" ]; then wanted="v$version"; else wanted=latest; fi
  say "download  $REPO $wanted (gh)"
  if [ -n "$version" ]; then
    gh release download "v$version" -R "$REPO" -p 'cc-shim-*.tar.gz*' -D "$work" || die "gh could not download v$version from $REPO"
  else
    gh release download -R "$REPO" -p 'cc-shim-*.tar.gz*' -D "$work" || die "gh could not download the latest release from $REPO"
  fi
  tarball=""
  for f in "$work"/cc-shim-*.tar.gz; do if [ -f "$f" ]; then tarball=$f; fi; done
  [ -n "$tarball" ] || die "the release has no cc-shim-*.tar.gz"
  sumfile="$tarball.sha256"
else
  command -v curl >/dev/null 2>&1 || die "neither gh (logged in) nor curl is available to download a release"
  if [ -z "$version" ]; then
    latest=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") || die "could not reach github.com/$REPO — a private repo needs \`gh auth login\`"
    version=${latest##*/v}
    case "$version" in ''|*/*) die "could not tell the latest version from $latest" ;; esac
  fi
  url="https://github.com/$REPO/releases/download/v$version/cc-shim-$version.tar.gz"
  say "download  $url"
  tarball="$work/cc-shim-$version.tar.gz"
  curl -fsSL -o "$tarball" "$url" || die "could not download $url"
  sumfile="$tarball.sha256"
  curl -fsSL -o "$sumfile" "$url.sha256" 2>/dev/null || rm -f "$sumfile"
fi

# ---- the checksum, when the release has one
if [ -f "$sumfile" ]; then
  want=$(cut -d ' ' -f 1 <"$sumfile")
  if command -v sha256sum >/dev/null 2>&1; then got=$(sha256sum "$tarball"); else got=$(shasum -a 256 "$tarball"); fi
  got=${got%% *}
  [ "$want" = "$got" ] || die "checksum mismatch for $tarball — expected $want, got $got"
  say "verified  sha256 $got"
else
  say "unverified no .sha256 beside $tarball"
fi

# ---- unpack: <releases>/<version>, then `current` points at it
top=$(tar -tzf "$tarball" | head -n 1)
top=${top%%/*}
case "$top" in cc-shim-*) ;; *) die "$tarball is not a cc-shim release (its top folder is \"$top\")" ;; esac
ver=${top#cc-shim-}
[ -z "$version" ] || [ "$version" = "$ver" ] || die "asked for $version, the tarball holds $ver"

mkdir -p "$releases"
staging="$releases/.$ver.partial"
rm -rf "$staging"
mkdir -p "$staging"
tar -xzf "$tarball" -C "$staging" --strip-components=1
[ -f "$staging/cc-shim.mjs" ] || die "$tarball has no cc-shim.mjs"
rm -rf "${releases:?}/$ver"
mv "$staging" "$releases/$ver"
ln -sfn "$ver" "$releases/current"
say "unpacked  $releases/$ver (current)"

# ---- the shim installs itself from that release (a copy: the release may go, the shim stays)
CC_SHIM_SRC="$releases/$ver" node "$releases/$ver/cc-shim.mjs" install
