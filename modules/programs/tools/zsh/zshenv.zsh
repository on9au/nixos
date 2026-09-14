# Homebrew. /opt/homebrew is Apple Silicon, /usr/local is Intel Mac and
# Linuxbrew uses /home/linuxbrew/.linuxbrew -- brew shellenv sets PATH,
# MANPATH and INFOPATH, so it has to run before anything below that expects
# brew-installed tools on PATH. Guarded on existence: this file is shared
# with machines that have no brew at all.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [ -x "$_brew" ]; then
    eval "$("$_brew" shellenv)"
    break
  fi
done
unset _brew

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
