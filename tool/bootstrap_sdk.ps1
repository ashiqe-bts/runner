$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$sdkDir = Join-Path $projectDir ".toolchain/flutter"
$expectedRevision = "d3b14c876900e553bc736ca19295fc09e3853e8e"

if (-not (Test-Path (Join-Path $sdkDir "bin/flutter.bat"))) {
  New-Item -ItemType Directory -Force (Split-Path -Parent $sdkDir) | Out-Null
  git clone --depth 1 --branch 3.47.2 https://github.com/flutter/flutter.git $sdkDir
  if ($LASTEXITCODE -ne 0) { throw "Unable to download Flutter 3.47.2." }
}

$revision = (git -C $sdkDir rev-parse HEAD).Trim()
if ($revision -ne $expectedRevision) {
  throw "Unexpected Flutter revision $revision. Expected 3.47.2 ($expectedRevision)."
}

& (Join-Path $sdkDir "bin/flutter.bat") --version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
