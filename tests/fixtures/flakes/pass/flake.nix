# Checks that build on both systems of the default runners.
{
  outputs =
    _:
    let
      check =
        system:
        derivation {
          name = "ok";
          inherit system;
          builder = "/bin/sh";
          args = [
            "-c"
            "echo ok >$out"
          ];
        };
    in
    {
      checks.x86_64-linux.ok = check "x86_64-linux";
      checks.aarch64-linux.ok = check "aarch64-linux";
    };
}
