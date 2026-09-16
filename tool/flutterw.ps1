$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if ($env:SKYWAY_FLUTTER_SDK) {
  $sdkDir = $env:SKYWAY_FLUTTER_SDK
} else {
  $sdkDir = Join-Path $projectDir ".toolchain/flutter"
}
$flutter = Join-Path $sdkDir "bin/flutter.bat"
if (-not (Test-Path $flutter)) {
  throw "Flutter 3.47.2 is required. Run .\tool\bootstrap_sdk.ps1 first."
}
$env:Path = "$(Join-Path $sdkDir 'bin');$env:Path"
& $flutter @args
exit $LASTEXITCODE
