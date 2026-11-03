# tests/run.sh passes: the unit tests of the actions with the stubs of
# tests/bin, and the static tests of the workflows. The tests run the actions
# also in a locale whose ranges match letters beyond ASCII.
{
  perSystem =
    { pkgs, sources, ... }:
    let
      locales = pkgs.glibcLocales.override {
        allLocales = false;
        locales = [ "en_US.UTF-8/UTF-8" ];
      };
    in
    {
      checks.unit =
        pkgs.runCommand "unit"
          {
            nativeBuildInputs = with pkgs; [
              bash
              coreutils
              findutils
              gnugrep
              gnused
              jq
              yq-go
            ];
            LOCALE_ARCHIVE = "${locales}/lib/locale/locale-archive";
          }
          ''
            # The sandbox has no /usr/bin/env.
            cp -r ${sources}/. source
            chmod -R u+w source
            patchShebangs source
            bash source/tests/run.sh
            touch $out
          '';
    };
}
