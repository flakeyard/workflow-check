# Changelog

## [0.1.2](https://github.com/flakeyard/workflow-check/compare/v0.1.1...v0.1.2) (2026-11-04)


### Bug Fixes

* encode file names in paths of the contents API ([#21](https://github.com/flakeyard/workflow-check/issues/21)) ([ce4eb48](https://github.com/flakeyard/workflow-check/commit/ce4eb48906e2bb5bb30d806592a5e9ac5f4086a6))
* fail on a skipped job that is missing from needs ([#17](https://github.com/flakeyard/workflow-check/issues/17)) ([20b96d1](https://github.com/flakeyard/workflow-check/commit/20b96d1968fe8bb0b5f990e9256c7f842b49ae19))
* keep flake.lock as committed in the flake checks ([#16](https://github.com/flakeyard/workflow-check/issues/16)) ([88944db](https://github.com/flakeyard/workflow-check/commit/88944db97fb231efe66b9053b9df67a99448c539))
* match names in ASCII whatever the locale ([#20](https://github.com/flakeyard/workflow-check/issues/20)) ([f4255ca](https://github.com/flakeyard/workflow-check/commit/f4255ca2b08364a709f05b82cf2b43acb597ffa8))
* reject repository names of dots only ([#19](https://github.com/flakeyard/workflow-check/issues/19)) ([9870a57](https://github.com/flakeyard/workflow-check/commit/9870a57cf25b525c2e1ec87753c87756d0a8a030))
* retry GitHub API requests that fail transiently ([#25](https://github.com/flakeyard/workflow-check/issues/25)) ([0a8f83a](https://github.com/flakeyard/workflow-check/commit/0a8f83ac401e20181e944f898ee6a21e957253e1))
* tell the jobs of the check workflow by their ids ([#18](https://github.com/flakeyard/workflow-check/issues/18)) ([b2017f4](https://github.com/flakeyard/workflow-check/commit/b2017f4e21f42b81d413f22064616fe7f5ffb86b))

## [0.1.1](https://github.com/flakeyard/workflow-check/compare/v0.1.0...v0.1.1) (2026-11-03)


### Bug Fixes

* name flake jobs after the matrix ([#13](https://github.com/flakeyard/workflow-check/issues/13)) ([9febad0](https://github.com/flakeyard/workflow-check/commit/9febad013845b9b254479bef4568e1932f13feec))

## 0.1.0 (2026-11-03)


### Features

* check workflow with the status protocol ([#4](https://github.com/flakeyard/workflow-check/issues/4)) ([b009c72](https://github.com/flakeyard/workflow-check/commit/b009c7273acfa08a9522186f75674b264000fbb7))
* context and commit-status actions ([#2](https://github.com/flakeyard/workflow-check/issues/2)) ([6c78d85](https://github.com/flakeyard/workflow-check/commit/6c78d8521db0def28ad763c8b5fddcbc192525c5))
* flake checks on every declared system ([#8](https://github.com/flakeyard/workflow-check/issues/8)) ([ea349af](https://github.com/flakeyard/workflow-check/commit/ea349afd64a8475d21b9d937d78b616577817a32))
* immutable release check of preset and template tags ([#7](https://github.com/flakeyard/workflow-check/issues/7)) ([25c8112](https://github.com/flakeyard/workflow-check/commit/25c8112de2aa3468df5393533a8ab5fbbd561bfc))
* pull request title check ([#5](https://github.com/flakeyard/workflow-check/issues/5)) ([8d1997e](https://github.com/flakeyard/workflow-check/commit/8d1997ecfcb3ee9307cd614daf79834b90af4737))
* renovate.json check through the contents API ([#6](https://github.com/flakeyard/workflow-check/issues/6)) ([c58515f](https://github.com/flakeyard/workflow-check/commit/c58515f92a4b7f1c266047c17bbcdbec63849d8e))
* required verdict with the jobs cross-check ([#3](https://github.com/flakeyard/workflow-check/issues/3)) ([908f314](https://github.com/flakeyard/workflow-check/commit/908f31450f70adf40855dcd8ac65c88cc26bc85b))
