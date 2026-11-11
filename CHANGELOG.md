# Changelog

## [0.3.2](https://github.com/flakeyard/workflow-check/compare/v0.3.1...v0.3.2) (2026-11-11)


### Bug Fixes

* **deps:** update flakeyard/action-setup-nix action to v0.1.4 ([#45](https://github.com/flakeyard/workflow-check/issues/45)) ([acb3a35](https://github.com/flakeyard/workflow-check/commit/acb3a350c8b6aa43799b203c195885665ea0398f))

## [0.3.1](https://github.com/flakeyard/workflow-check/compare/v0.3.0...v0.3.1) (2026-11-11)


### Bug Fixes

* **deps:** update flakeyard/action-shell-lib action to v0.1.3 ([#54](https://github.com/flakeyard/workflow-check/issues/54)) ([1b991f7](https://github.com/flakeyard/workflow-check/commit/1b991f7ee0c8f1a49d4b1ff3753f2e96c4a7c16b))

## [0.3.0](https://github.com/flakeyard/workflow-check/compare/v0.2.0...v0.3.0) (2026-11-10)


### Features

* check the end of life of nixpkgs with action-flake-lock ([#48](https://github.com/flakeyard/workflow-check/issues/48)) ([2d27d8c](https://github.com/flakeyard/workflow-check/commit/2d27d8c8f119187807da4278e302b8d7850c0b26))


### Bug Fixes

* call the shell library once in every job ([#49](https://github.com/flakeyard/workflow-check/issues/49)) ([b3df11b](https://github.com/flakeyard/workflow-check/commit/b3df11b69714fdab290d871cc7aedd9877ebc23e))
* **deps:** update flakeyard/action-flake-lock action to v0.2.0 ([#46](https://github.com/flakeyard/workflow-check/issues/46)) ([c6ef272](https://github.com/flakeyard/workflow-check/commit/c6ef272554d1c28a50ed5030ad5514069ee1f5f1))
* source report, API, contents and forms from the shell library ([#50](https://github.com/flakeyard/workflow-check/issues/50)) ([7c7ac98](https://github.com/flakeyard/workflow-check/commit/7c7ac98721eaca4dc26ef3f960f92903f17bb37e))

## [0.2.0](https://github.com/flakeyard/workflow-check/compare/v0.1.2...v0.2.0) (2026-11-10)


### Features

* check flake.lock with action-flake-lock ([#35](https://github.com/flakeyard/workflow-check/issues/35)) ([05f794b](https://github.com/flakeyard/workflow-check/commit/05f794b47932af054a9183d0dfafe0e9d3e39c9a))


### Bug Fixes

* **deps:** update flakeyard/action-setup-nix action to v0.1.2 ([#34](https://github.com/flakeyard/workflow-check/issues/34)) ([b42f2e1](https://github.com/flakeyard/workflow-check/commit/b42f2e10d8dfabf35feadd42df02b2e45830ff3a))

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
