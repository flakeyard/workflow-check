# Checks that evaluate only when the input dep is overridden with a flake that
# has checks, such as the fixture pass; the committed dep has none.
{
  inputs.dep.url = "path:./dep";

  outputs =
    { dep, ... }:
    let
      check =
        system:
        assert dep ? checks;
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
