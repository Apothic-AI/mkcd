#!/usr/bin/env bash
#
# tests/test.sh - behavioural tests for mkcd and cdmk.
#
#   ./tests/test.sh
#
# Runs the scripts from the repository, so it never touches an installed
# copy.  Exits non-zero when a test fails.

set -u

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
mkcd_script="$repo_dir/mkcd"
cdmk_script="$repo_dir/cdmk"

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    printf 'ok   %s\n' "$1"
}

no() {
    fail=$((fail + 1))
    printf 'FAIL %s\n' "$1"
    printf '       expected: %s\n' "$2"
    printf '       actual:   %s\n' "$3"
}

check() {
    if [ "$2" = "$3" ]; then
        ok "$1"
    else
        no "$1" "$2" "$3"
    fi
}

check_contains() {
    case "$3" in
        *"$2"*) ok "$1" ;;
        *) no "$1" "output containing '$2'" "$3" ;;
    esac
}

check_lacks() {
    case "$3" in
        *"$2"*) no "$1" "output without '$2'" "$3" ;;
        *) ok "$1" ;;
    esac
}

# The scripts print the directory they landed in, and the tests often print
# it again with pwd, so compare against the last line.
last_line() {
    printf '%s\n' "$1" | tail -n 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

home="$work/home"
mkdir -p "$home"

# --- executed as a program -------------------------------------------------

out="$(cd "$work" && "$mkcd_script" one/two/three 2>"$work/err")"
status=$?
check 'creates a missing directory tree' '0' "$status"
if [ -d "$work/one/two/three" ]; then
    ok 'the directory tree exists afterwards'
else
    no 'the directory tree exists afterwards' 'directory' 'missing'
fi
check 'prints the new directory' "$work/one/two/three" "$(last_line "$out")"
check_contains 'warns that the parent shell is unaffected' 'does not affect the calling shell' "$(cat "$work/err")"
check_contains 'says that it created the directory' 'created' "$(cat "$work/err")"

out="$(cd "$work" && "$mkcd_script" one/two/three 2>"$work/err2")"
check 'enters an existing directory' "$work/one/two/three" "$(last_line "$out")"
check_lacks 'says nothing when it only enters' 'created' "$(cat "$work/err2")"

: > "$work/afile"
out="$(cd "$work" && "$mkcd_script" afile 2>"$work/err")"
status=$?
check 'refuses a path that is a file' '1' "$status"
check_contains 'explains that it is not a directory' 'not a directory' "$(cat "$work/err")"

out="$(cd "$work" && "$mkcd_script" 2>"$work/err")"
status=$?
check 'needs an argument' '2' "$status"
check_contains 'shows usage without an argument' 'Usage: mkcd' "$(cat "$work/err")"

out="$(cd "$work" && "$mkcd_script" --nope 2>"$work/err")"
status=$?
check 'rejects an unknown option' '2' "$status"
check_contains 'explains the unknown option' 'unknown option' "$(cat "$work/err")"

out="$("$mkcd_script" --help 2>/dev/null)"
check 'prints help' '0' "$?"
check_contains 'help mentions the usage' 'Usage: mkcd' "$out"

out="$("$mkcd_script" --version 2>/dev/null)"
check_contains 'prints the version' 'mkcd ' "$out"

out="$(cd "$work" && HOME="$home" "$mkcd_script" '~/tilde/case' 2>/dev/null)"
check 'expands a leading tilde' "$home/tilde/case" "$(last_line "$out")"

out="$(cd "$work" && "$mkcd_script" -- 2>/dev/null)"
check 'treats -- as an empty path' '2' "$?"

out="$(cd "$work" && "$mkcd_script" first second 2>/dev/null)"
check 'enters the last path given' "$work/second" "$(last_line "$out")"
if [ -d "$work/first" ] && [ -d "$work/second" ]; then
    ok 'both directories exist'
else
    no 'both directories exist' 'two directories' 'missing'
fi

# --- sourced into a shell --------------------------------------------------

out="$(cd "$work" && source "$mkcd_script" && mkcd sourced/dir && pwd)"
check 'the sourced function changes the directory of the shell' "$work/sourced/dir" "$(last_line "$out")"

out="$(cd "$work" && source "$mkcd_script" sourced/with/args && pwd)"
check 'sourcing with arguments changes the directory' "$work/sourced/with/args" "$(last_line "$out")"

out="$(cd "$work" && source "$mkcd_script" && mkcd sourced/dir 2>&1 >/dev/null)"
check_lacks 'the sourced function stays quiet' 'does not affect the calling shell' "$out"

out="$(cd "$work" && source "$mkcd_script" && pwd)"
check 'sourcing without arguments does nothing' "$work" "$(last_line "$out")"

out="$(cd "$work" && source "$cdmk_script" && cdmk aliased/dir && pwd)"
check 'cdmk behaves like mkcd' "$work/aliased/dir" "$(last_line "$out")"

out="$(cd "$work" && source "$cdmk_script" && mkcd after/cdmk && pwd)"
check 'cdmk also provides mkcd' "$work/after/cdmk" "$(last_line "$out")"

out="$(cd "$work" && source "$cdmk_script" cdmk/with/args && pwd)"
check 'sourcing cdmk with arguments changes the directory' "$work/cdmk/with/args" "$(last_line "$out")"

out="$(cd "$work" && "$cdmk_script" cdmk/program 2>"$work/err")"
status=$?
check 'cdmk runs as a program too' '0' "$status"
if [ -d "$work/cdmk/program" ]; then
    ok 'cdmk creates the directory when run as a program'
else
    no 'cdmk creates the directory when run as a program' 'directory' 'missing'
fi
check_contains 'cdmk warns about the parent shell as well' 'does not affect the calling shell' "$(cat "$work/err")"

# --- zsh -------------------------------------------------------------------

if command -v zsh >/dev/null 2>&1; then
    out="$(cd "$work" && zsh -c "source '$mkcd_script'; mkcd zsh/dir; pwd" 2>/dev/null)"
    check 'works in zsh' "$work/zsh/dir" "$(last_line "$out")"

    out="$(cd "$work" && zsh -c "source '$cdmk_script'; cdmk zsh/aliased; pwd" 2>/dev/null)"
    check 'cdmk works in zsh' "$work/zsh/aliased" "$(last_line "$out")"

    out="$(cd "$work" && zsh -c "source '$mkcd_script'; mkcd zsh/dir 2>&1 >/dev/null")"
    check_lacks 'the zsh function stays quiet' 'does not affect the calling shell' "$out"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
