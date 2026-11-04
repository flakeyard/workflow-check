# shellcheck shell=bash
# Tests of lib/github/repository.sh.

lib=github/repository.sh

# is_repository NAME: NAME matches REPOSITORY_FORM.
is_repository() {
  [[ $1 =~ $REPOSITORY_FORM ]]
}

for name in flakeyard/renovate-config owner/.github owner/a.b owner/_x; do
  setup
  run_lib "repository: accepts $name" ok "$lib" is_repository "$name"
  finish
done

for name in owner/.. owner/. owner/... ../x owner owner/a/b "owner/a b" o_x/a; do
  setup
  run_lib "repository: rejects $name" fail "$lib" is_repository "$name"
  finish
done
