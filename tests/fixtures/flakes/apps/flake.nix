# Apps for flake-apps on x86_64-linux: root succeeds only from the root of
# the checkout with the token of the job, fails always fails. A file copied
# into the store keeps its executable bit, so the apps need no nixpkgs.
{
  outputs = _: {
    apps.x86_64-linux = {
      root = {
        type = "app";
        program = "${./root.sh}";
      };
      fails = {
        type = "app";
        program = "${./fails.sh}";
      };
    };
  };
}
