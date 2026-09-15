{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    bitwarden-desktop # password manager; handles bitwarden:// links (mimeapps.list)
    brave # Chromium browser, for sites that only work properly in Chrome
    cinny-desktop # Matrix chat
    libreoffice-stable # opening and editing Office documents
    meld # side-by-side diffs and merge conflicts
    mpv # default video player (mimeapps.list)
    obsidian # Markdown notes
    vlc # fallback for videos and discs mpv won't play
    vscode # GUI editor for projects that want its debuggers/extensions
  ];
}
