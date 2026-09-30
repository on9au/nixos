{pkgs, ...}: {
  home.packages = with pkgs; [
    claude-code
  ];

  # Claude Code drops to 256 colours whenever $TMUX is set unless this is;
  # tmux.conf already passes RGB through to the outer terminal.
  home.sessionVariables.CLAUDE_CODE_TMUX_TRUECOLOR = "1";
}
