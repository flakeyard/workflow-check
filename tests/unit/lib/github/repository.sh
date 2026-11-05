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

for list in '["../x"]' '"owner/repo"' '[1]' ''; do
  setup
  run_lib "repository: $list is not a list of owner/repo" fail "$lib" is_repository_list "$list"
  finish
done

setup
run_lib "repository: a list has a repository whatever its case" ok "$lib" \
  lists_repository '["a/b","Owner/Repo"]' owner/REPO
finish

setup
run_lib "repository: a list without the repository" fail "$lib" lists_repository '["owner/repo-fork"]' owner/repo
finish
