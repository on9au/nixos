{...}: {
  programs.git.settings.user = {
    email = "151502370+on9au@users.noreply.github.com";
    name = "on9au";
  };

  # Coursework pushes to git.infotech under the student account, not the GitHub
  # one. Case-insensitive because the Mac's APFS is: ~/monash and ~/Monash are
  # the same directory there, but git matches this pattern as a literal string.
  programs.git.includes = [
    {
      condition = "gitdir/i:~/Monash/";
      contents.user = {
        email = "djon0031@student.monash.edu";
        name = "djon0031";
      };
    }
  ];
}
