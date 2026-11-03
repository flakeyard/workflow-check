# A check that does not evaluate.
{
  outputs = _: {
    checks.x86_64-linux.broken = throw "this check does not evaluate";
    checks.aarch64-linux.broken = throw "this check does not evaluate";
  };
}
