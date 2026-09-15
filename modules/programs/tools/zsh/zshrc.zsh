# Appended to ~/.zshrc by programs.zsh in home.nix, which handles
# compinit, history, plugins and starship. Needs a rebuild after editing.

setopt INC_APPEND_HISTORY
setopt HIST_REDUCE_BLANKS

# zsh-vi-mode hijacks keymaps on init, clobbering fzf-tab and
# history-substring-search bindings. Re-apply them after vi-mode finishes.
zvm_after_init() {
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
}

# ssh-agent
# OpenSSH's agent, not gcr-ssh-agent: only this one can use the YubiKey FIDO2
# keys. The socket unit exports nothing, so the path has to be named here --
# same value as systemd.user.sessionVariables in programs/services/ssh-agent, which
# covers the graphical session; this line covers shells, including SSH logins
# into this machine, where the user manager's environment is never read.
#
# Two names, because the agent is not packaged the same everywhere: Arch's
# ssh-agent.socket listens on $XDG_RUNTIME_DIR/ssh-agent.socket, while NixOS's
# programs.ssh.startAgent runs the agent on $XDG_RUNTIME_DIR/ssh-agent. The
# one that is actually there wins.
#
# Guarded on the socket existing at all: WSL and the Mac run no such agent,
# and pointing SSH_AUTH_SOCK at a socket with nothing behind it is worse than
# leaving it unset.
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  for _sock in "$XDG_RUNTIME_DIR/ssh-agent.socket" "$XDG_RUNTIME_DIR/ssh-agent"; do
    if [ -S "$_sock" ]; then
      export SSH_AUTH_SOCK="$_sock"
      break
    fi
  done
  unset _sock
fi

# kitty ssh
[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"

# ---- User configuration ----

GPG_TTY=$(tty)

export CDGIT_ROOT="$HOME/Projects"
export WINAPPS_SRC_DIR="$HOME/.local/bin/winapps-src"

# cg command which sets cwd to the output of `cdgit` if `cdgit` is present
if command -v cdgit >/dev/null 2>&1; then
  cg() {
    local target_dir
    target_dir=$(cdgit "$@")
    if [ -n "$target_dir" ]; then
      cd "$target_dir" || return 1
    else
      echo "cdgit: No matching git repository found." >&2
      return 1
    fi
  }
fi

# allow `#` to be used in shell
setopt interactive_comments

# fnm
FNM_PATH="$HOME/.local/share/fnm"
[ -d "$FNM_PATH" ] && export PATH="$FNM_PATH:$PATH"
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --shell zsh)"
fi

# PATH additions, appended once each.
#
# This was one line -- PATH="$PATH:$(go env GOBIN):$(go env GOPATH)/bin:..." --
# and it had two problems. `go env GOBIN` is empty unless it has been set
# explicitly (it is not set on a fresh machine), and an empty element in PATH
# means *the current directory*: every directory you cd into got a vote on
# what `ls` resolves to. And nothing here was guarded, so each nested
# interactive shell -- a tmux pane, a subshell -- appended the whole lot
# again; PATH here had four copies of ~/go/bin by mid-afternoon.
#
# Also guarded on `go` existing at all: this file is shared with machines
# that have no Go toolchain, where the old line printed "command not found:
# go" twice on every prompt.
_path_append() {
  [ -n "$1" ] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$PATH:$1" ;;
  esac
}

if command -v go >/dev/null 2>&1; then
  _gobin=$(go env GOBIN)
  _gopath=$(go env GOPATH)
  _path_append "$_gobin"
  [ -n "$_gopath" ] && _path_append "$_gopath/bin"
  unset _gobin _gopath
fi

_path_append "$HOME/.local/bin"

unset -f _path_append
export PATH

# pnpm
# PNPM_HOME is set unconditionally -- `pnpm add -g` reads it to decide where to
# install, and creates the directory itself. The PATH entry is guarded on that
# directory existing, like every other addition above: nothing is installed
# globally on most of these machines, and an entry pointing at a directory that
# is not there is just noise in PATH.
export PNPM_HOME="$HOME/.local/share/pnpm"
if [ -d "$PNPM_HOME/bin" ]; then
  case ":$PATH:" in
    *":$PNPM_HOME/bin:"*) ;;
    *) export PATH="$PNPM_HOME/bin:$PATH" ;;
  esac
fi
# pnpm end

# flatpak
# Wrappers in exports/bin let flatpak apps be launched by name (the command is
# the app id, e.g. org.vinegarhq.Sober); XDG_DATA_DIRS makes their .desktop
# entries and icons visible. Guarded on existence since the dirs only appear
# once something is installed (and never on WSL).
#
# The flatpak login hook handles the XDG_DATA_DIRS half at login, so that part
# only does work in a shell that started before the first install, which is
# exactly when flatpak prints its "not in the search path" warning. The PATH
# half is not redundant: `flatpak --print-updated-env` emits XDG_DATA_DIRS alone.
for _flatpak_dir in "$HOME/.local/share/flatpak" /var/lib/flatpak; do
  if [ -d "$_flatpak_dir/exports/bin" ]; then
    case ":$PATH:" in
      *":$_flatpak_dir/exports/bin:"*) ;;
      *) export PATH="$PATH:$_flatpak_dir/exports/bin" ;;
    esac
  fi
  if [ -d "$_flatpak_dir/exports/share" ]; then
    case ":${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:" in
      *":$_flatpak_dir/exports/share:"*) ;;
      *) export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:$_flatpak_dir/exports/share" ;;
    esac
  fi
done
unset _flatpak_dir
# flatpak end

# editor
if command -v nvim >/dev/null 2>&1; then
    export EDITOR='nvim'
else
    export EDITOR='vim'
fi
export VISUAL="$EDITOR"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
