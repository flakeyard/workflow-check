# A flake that declares a system without a runner.
{
  outputs = _: {
    formatter.x86_64-darwin = derivation {
      name = "formatter";
      system = "x86_64-darwin";
      builder = "/bin/sh";
    };
    checks.x86_64-linux = { };
    checks.aarch64-linux = { };
  };
}
