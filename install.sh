#!/usr/bin/env bash
#
# install.sh - install the mkcd and cdmk scripts and wire them into your shell.
#
#   curl -fsSL https://raw.githubusercontent.com/Apothic-AI/mkcd/main/install.sh | bash
#
# The scripts are installed into a bin directory and the shell rc file gets
# a small managed block that sources them, so that mkcd and cdmk change the
# directory of the shell you are sitting in.

set -euo pipefail

REPO="${MKCD_REPO:-Apothic-AI/mkcd}"
REF="${MKCD_REF:-main}"
BASE_URL="${MKCD_BASE_URL:-https://raw.githubusercontent.com/${REPO}/${REF}}"

BLOCK_START='# >>> mkcd >>>'
BLOCK_END='# <<< mkcd <<<'

requested_prefix=''
do_uninstall=0
do_rc=1

usage() {
    cat <<'EOF'
Usage: install.sh [options]

Install mkcd and cdmk, and add them to your shell.

Options:
  --prefix DIR    install into DIR (default: /usr/local, or ~/.local when
                  /usr/local cannot be written to)
  --uninstall     remove a previous installation
  --no-rc         leave the shell rc file untouched
  -h, --help      show this help

Environment:
  MKCD_REPO       repository to install from (default: Apothic-AI/mkcd)
  MKCD_REF        branch or tag to install (default: main)
  MKCD_BASE_URL   base URL to download from, overrides REPO and REF
EOF
}

die() {
    printf 'install.sh: %s\n' "$1" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)
            [ "$#" -ge 2 ] || die '--prefix needs a directory'
            requested_prefix="$2"
            shift
            ;;
        --prefix=*)
            requested_prefix="${1#--prefix=}"
            ;;
        --uninstall)
            do_uninstall=1
            ;;
        --no-rc)
            do_rc=0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'install.sh: unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

dir_is_writable() {
    [ -d "$1" ] && [ -w "$1" ]
}

can_sudo() {
    command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1
}

# Where the scripts end up.
if [ -n "$requested_prefix" ]; then
    prefix="$requested_prefix"
elif dir_is_writable /usr/local || can_sudo; then
    prefix=/usr/local
else
    prefix="$HOME/.local"
fi

bindir="$prefix/bin"

# Do we need root to write there?  A missing bin directory can be created by
# whoever owns its parent, so look one level up in that case.
if dir_is_writable "$bindir"; then
    need_sudo=0
elif [ -d "$prefix" ]; then
    if dir_is_writable "$prefix"; then
        need_sudo=0
    elif can_sudo; then
        need_sudo=1
    else
        die "cannot write to $bindir and sudo is not available; use --prefix"
    fi
else
    parent="$(dirname -- "$prefix")"
    if dir_is_writable "$parent"; then
        need_sudo=0
    elif can_sudo; then
        need_sudo=1
    else
        die "cannot write to $prefix and sudo is not available; use --prefix"
    fi
fi

as_root() {
    if [ "$need_sudo" -eq 1 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

# The shell rc files that may hold the managed block.
rc_bash="$HOME/.bashrc"
rc_zsh="$HOME/.zshrc"

rc_file="$rc_bash"
shell_name="$(basename "${SHELL:-bash}")"
if [ "$shell_name" = "zsh" ]; then
    rc_file="$rc_zsh"
fi

strip_block() {
    # Print the file without the managed block, including the blank line
    # that sits inside it.
    awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
        $0 == start { skip = 1; next }
        skip        { if ($0 == end) skip = 0; next }
        { print }
    ' "$1"
}

write_block() {
    rc="$1"
    tmp="$(mktemp)"

    if [ -f "$rc" ]; then
        strip_block "$rc" > "$tmp"
    fi

    # The file has to end on a newline before the block is appended.
    if [ -s "$tmp" ] && [ "$(tail -c 1 "$tmp" | wc -l)" -eq 0 ]; then
        printf '\n' >> "$tmp"
    fi

    {
        printf '%s\n' "$BLOCK_START"
        printf '\n'
        printf 'source "%s/mkcd"\n' "$bindir"
        printf 'source "%s/cdmk"\n' "$bindir"
        printf '%s\n' "$BLOCK_END"
    } >> "$tmp"

    cat "$tmp" > "$rc"
    rm -f "$tmp"
}

remove_block() {
    rc="$1"
    [ -f "$rc" ] || return 0
    tmp="$(mktemp)"
    strip_block "$rc" > "$tmp"
    cat "$tmp" > "$rc"
    rm -f "$tmp"
}

download() {
    url="$1"
    dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    else
        die 'need curl or wget to download the scripts'
    fi

    [ -s "$dest" ] || die "downloaded an empty file from $url"
    head -n 1 "$dest" | grep -q '^#!' || die "the file downloaded from $url does not look like a script"
}

if [ "$do_uninstall" -eq 1 ]; then
    as_root rm -f "$bindir/mkcd" "$bindir/cdmk"
    if [ "$do_rc" -eq 1 ]; then
        remove_block "$rc_bash"
        remove_block "$rc_zsh"
    fi
    printf 'mkcd removed from %s\n' "$bindir"
    printf 'shell block removed from %s and %s\n' "$rc_bash" "$rc_zsh"
    exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

download "$BASE_URL/mkcd" "$tmpdir/mkcd"
download "$BASE_URL/cdmk" "$tmpdir/cdmk"

as_root mkdir -p "$bindir"
as_root cp "$tmpdir/mkcd" "$bindir/mkcd"
as_root cp "$tmpdir/cdmk" "$bindir/cdmk"
as_root chmod 0755 "$bindir/mkcd" "$bindir/cdmk"

if [ "$do_rc" -eq 1 ]; then
    write_block "$rc_file"
fi

printf 'mkcd installed:\n'
printf '  %s\n' "$bindir/mkcd"
printf '  %s\n' "$bindir/cdmk"
if [ "$do_rc" -eq 1 ]; then
    printf '  %s (updated)\n' "$rc_file"
fi
printf '\n'
printf 'Restart your shell, or run: source %s\n' "$rc_file"
printf 'Then try: mkcd ~/projects/some-new-dir\n'
