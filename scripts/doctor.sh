#!/usr/bin/env bash
# Read-only health check of what install.sh sets up. Prints OK/WARN/FAIL/SKIP
# per item and exits 1 if anything fails. Changes nothing and needs no sudo.
#   DOTFILES_SKIP="aur gpu system services"  skip the same steps as install.sh
#   DOTFILES=<path>                          repo to check (default: this repo)
# WARN never fails the run: it is used for AUR packages, which are best effort
# (AUR builds break upstream, packages get renamed or move to the official repos).

DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
fails=0
warns=0

ok() { printf '  OK    %s\n' "$1"; }
skip() { printf '  SKIP  %s (%s)\n' "$1" "$2"; }
# Paths are shown with ~ so pasted output does not reveal the user name
warn() {
    printf '  WARN  %s: %s\n' "$1" "${2//"$HOME"/\~}"
    warns=$((warns + 1))
}
fail() {
    printf '  FAIL  %s: %s\n' "$1" "${2//"$HOME"/\~}"
    fails=$((fails + 1))
}
has() { command -v "$1" &>/dev/null; }
skip_step() { [[ " ${DOTFILES_SKIP:-} " == *" $1 "* ]]; }
parse_packages() { grep -v '^#' "$1" | grep -v '^$' | tr -d ' '; }

echo "=== dotfiles doctor (${DOTFILES/#$HOME/~}) ==="
if [[ ! -f "$DOTFILES/install.sh" || ! -d "$DOTFILES/stow" ]]; then
    fail "dotfiles repo" "$DOTFILES has no install.sh or stow/ (set DOTFILES)"
    exit 1
fi

# ── Packages ─────────────────────────────────────
echo "[packages]"
if ! has pacman; then
    fail "pacman" "not found (this branch is for Arch Linux)"
else
    if pacman-conf --repo-list 2>/dev/null | grep -qx multilib; then
        ok "multilib repository"
    else
        fail "multilib repository" "not enabled in /etc/pacman.conf"
    fi
    # pacman -T prints the entries not satisfied (it also accepts providers)
    check_list() { # <label> <file> <ok|warn|fail on missing>
        local missing count
        missing=$(parse_packages "$2" | xargs pacman -T 2>/dev/null | tr '\n' ' ')
        count=$(parse_packages "$2" | wc -l)
        if [[ -z "$missing" ]]; then
            ok "$1 ($count installed)"
        else
            "$3" "$1" "missing: $missing"
        fi
    }
    check_list "packages/official.txt" "$DOTFILES/packages/official.txt" fail
    if skip_step gpu; then
        skip "packages/amd-gpu.txt" "DOTFILES_SKIP"
    else
        check_list "packages/amd-gpu.txt" "$DOTFILES/packages/amd-gpu.txt" fail
    fi
    if skip_step aur; then
        skip "yay and packages/aur.txt" "DOTFILES_SKIP"
    elif ! has yay; then
        fail "yay" "not installed"
    else
        ok "yay"
        check_list "packages/aur.txt" "$DOTFILES/packages/aur.txt" warn
    fi
fi

# ── Stow ─────────────────────────────────────────
# Every file in stow/<pkg>/ must resolve to the repo copy from $HOME, either
# as its own link or through a folded directory link (what stow creates).
echo "[stow]"
for pkg_dir in "$DOTFILES"/stow/*/; do
    pkg=$(basename "$pkg_dir")
    total=0
    bad=()
    while IFS= read -r -d '' src; do
        rel=${src#"$pkg_dir"}
        total=$((total + 1))
        if [[ "$(realpath -m "$HOME/$rel" 2>/dev/null)" != "$(realpath -m "$src" 2>/dev/null)" ]]; then
            bad+=("$HOME/$rel")
        fi
    done < <(find "$pkg_dir" \( -type f -o -type l \) -print0)
    if [[ ${#bad[@]} -eq 0 ]]; then
        ok "$pkg ($total files)"
    else
        fail "$pkg" "${#bad[@]}/$total not linked, e.g. ${bad[0]} (run scripts/stow.sh)"
    fi
done

# ── Shell ────────────────────────────────────────
echo "[shell]"
login_shell=$(getent passwd "$(id -un)" | cut -d: -f7)
if [[ "$login_shell" == */zsh ]]; then
    ok "login shell is zsh"
else
    fail "login shell" "is '${login_shell:-unknown}', expected zsh (run scripts/shell.sh)"
fi
zinit_home="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ -f "$zinit_home/zinit.zsh" ]]; then
    ok "zinit"
else
    fail "zinit" "$zinit_home/zinit.zsh not found"
fi

# ── Git ──────────────────────────────────────────
echo "[git]"
# Values are not printed: CI logs of this repo are public
for key in user.name user.email; do
    if [[ -n "$(git config --file "$HOME/.gitconfig_local" --get "$key" 2>/dev/null)" ]]; then
        ok ".gitconfig_local $key"
    else
        fail ".gitconfig_local $key" "not set"
    fi
done
hooks=$(git -C "$DOTFILES" config --get core.hooksPath)
if [[ "$hooks" != ".githooks" ]]; then
    fail "gitleaks pre-commit hook" "core.hooksPath is '${hooks:-unset}', expected .githooks"
elif [[ ! -x "$DOTFILES/.githooks/pre-commit" ]]; then
    fail "gitleaks pre-commit hook" ".githooks/pre-commit is not executable"
elif ! has gitleaks; then
    fail "gitleaks pre-commit hook" "gitleaks not installed"
else
    ok "gitleaks pre-commit hook"
fi

# ── Claude ───────────────────────────────────────
# Only the statusline lives here; Claude settings come from another repo.
echo "[claude]"
statusline="$HOME/.config/claude-code/claude-statusline.sh"
if [[ "$(realpath -m "$statusline" 2>/dev/null)" != "$(realpath -m "$DOTFILES/stow/claude/.config/claude-code/claude-statusline.sh")" ]]; then
    fail "statusline" "$statusline does not point into the repo"
elif [[ ! -x "$statusline" ]]; then
    fail "statusline" "$statusline is not executable"
else
    ok "statusline linked and executable"
fi

# ── System (scripts/system.sh) ───────────────────
echo "[system]"
if skip_step system; then
    skip "system configuration" "DOTFILES_SKIP"
else
    file_has() { # <label> <file> [pattern]
        if [[ ! -f "$2" ]]; then
            fail "$1" "$2 not found"
        elif [[ -n "${3:-}" ]] && ! grep -q "$3" "$2"; then
            fail "$1" "$2 has no '$3'"
        else
            ok "$1"
        fi
    }
    file_has "sysctl hardening" /etc/sysctl.d/99-dotfiles.conf
    file_has "greetd (tuigreet)" /etc/greetd/config.toml tuigreet
    file_has "gnome-keyring PAM for greetd" /etc/pam.d/greetd pam_gnome_keyring
    file_has "zram swap" /etc/systemd/zram-generator.conf
    if id -nG | grep -qw docker; then
        ok "user in docker group"
    else
        fail "docker group" "user is not a member (re-login after install?)"
    fi
fi

# ── Services (scripts/services.sh) ───────────────
# Unit names are read from the arrays in services.sh, so the list never drifts.
echo "[services]"
if skip_step services; then
    skip "systemd units" "DOTFILES_SKIP"
elif [[ ! -d /run/systemd/system ]]; then
    skip "systemd units" "systemd is not running"
else
    user_bus=1
    systemctl --user show-environment &>/dev/null || user_bus=0
    while read -r scope unit; do
        if [[ "$scope" == user ]]; then
            if [[ "$user_bus" == 0 ]]; then
                skip "$unit (user)" "no user systemd session"
            elif systemctl --user is-enabled -q "$unit" 2>/dev/null; then
                ok "$unit (user)"
            else
                fail "$unit (user)" "not enabled"
            fi
        elif systemctl is-enabled -q "$unit" 2>/dev/null; then
            ok "$unit"
        else
            fail "$unit" "not enabled"
        fi
    done < <(awk '
        /^declare -a system_services=\(/ { scope = "system"; next }
        /^declare -a user_services=\(/   { scope = "user"; next }
        /^\)/                            { scope = ""; next }
        scope && $0 !~ /^[[:space:]]*#/ && match($0, /"[^"]+"/) {
            print scope, substr($0, RSTART + 1, RLENGTH - 2)
        }' "$DOTFILES/scripts/services.sh")
fi

echo ""
if [[ "$fails" -gt 0 ]]; then
    echo "=== $fails check(s) failed, $warns warning(s) ==="
    exit 1
fi
echo "=== All checks passed ($warns warning(s)) ==="
