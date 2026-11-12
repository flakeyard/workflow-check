# The actions and tests of the repository as one source for the checks.
{
  perSystem =
    { pkgs, root, ... }:
    {
      _module.args.sources = pkgs.lib.fileset.toSource {
        inherit root;
        fileset = pkgs.lib.fileset.unions [
          (root + "/.github")
          (root + "/tests")
        ];
      };
    };
}
