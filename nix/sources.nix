# The scripts, actions and tests of the repository, and the files the tests
# compare, as one source for the checks.
{
  perSystem =
    { pkgs, ... }:
    {
      _module.args.sources = pkgs.lib.fileset.toSource {
        root = ../.;
        fileset = pkgs.lib.fileset.unions [
          ../.github
          ../scripts
          ../tests
          ../flake.lock
          ../nixpkgs-eol
        ];
      };
    };
}
