# A check that fails to build next to one that builds.
{
  outputs =
    _:
    let
      check =
        system: name: script:
        derivation {
          inherit name system;
          builder = "/bin/sh";
          args = [
            "-c"
            script
          ];
        };
    in
    {
      checks.x86_64-linux = {
        ok = check "x86_64-linux" "ok" "echo ok >$out";
        broken = check "x86_64-linux" "broken" "echo broken >&2; exit 1";
      };
      checks.aarch64-linux.ok = check "aarch64-linux" "ok" "echo ok >$out";
    };
}
