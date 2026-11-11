# The actions and tests of the repository as one source for the checks.
{
  perSystem =
    { pkgs, ... }:
    {
      _module.args.sources = pkgs.lib.fileset.toSource {
        root = ../.;
        fileset = pkgs.lib.fileset.unions [
          ../.github
          ../tests
        ];
      };
    };
}
