[CmdletBinding()]
param(
  [string]$Emsdk = $env:EMSDK,
  [string]$VcpkgRoot = $env:VCPKG_ROOT,
  [string]$WasiStub = $env:WASI_STUB,
  [string]$Typst = $env:TYPST,
  [switch]$SkipTests
)
$ErrorActionPreference = 'Stop'
foreach ($item in @(@('Emsdk', $Emsdk), @('VcpkgRoot', $VcpkgRoot), @('WasiStub', $WasiStub))) {
  if (-not $item[1] -or -not (Test-Path -LiteralPath $item[1])) {
    throw "Provide -$($item[0]) or the corresponding environment variable."
  }
}
$env:EMSDK = (Resolve-Path -LiteralPath $Emsdk).Path
$env:EMSCRIPTEN_ROOT = Join-Path $env:EMSDK 'upstream/emscripten'
$env:VCPKG_ROOT = (Resolve-Path -LiteralPath $VcpkgRoot).Path
$env:WASI_STUB = (Resolve-Path -LiteralPath $WasiStub).Path
# Emsdk keeps versioned Python and Node installs. Read its active configuration
# instead of embedding version-specific directories in this repository.
$config = Get-Content -LiteralPath (Join-Path $env:EMSDK '.emscripten')
foreach ($entry in @(@('PYTHON', 'EMSDK_PYTHON'), @('NODE_JS', 'EMSDK_NODE'))) {
  $line = $config | Where-Object { $_ -match ('^' + $entry[0] + '\s*=') } | Select-Object -First 1
  if (-not $line -or $line -notmatch '=\s*[''"]([^''"]+)[''"]') {
    throw "Cannot read $($entry[0]) from emsdk/.emscripten."
  }
  $tool = $Matches[1].Replace('$CFGDIR', $env:EMSDK.Replace('\', '/'))
  if (-not (Test-Path -LiteralPath $tool)) { throw "Missing SDK executable: $tool" }
  [Environment]::SetEnvironmentVariable($entry[1], $tool, 'Process')
}
if ($Typst) {
  $env:TYPST = (Resolve-Path -LiteralPath $Typst).Path
} else {
  $command = Get-Command typst -ErrorAction SilentlyContinue
  if ($command) { $env:TYPST = $command.Source } else { $env:TYPST = '' }
}
if (-not $SkipTests -and -not $env:TYPST) { throw 'Provide -Typst for integration tests, or explicitly use -SkipTests.' }
$repo = Split-Path -Parent $PSScriptRoot
Push-Location $repo
try {
  cmake --preset wasm-release
  if ($LASTEXITCODE -ne 0) { throw 'CMake configure failed.' }
  cmake --build --preset wasm-release
  if ($LASTEXITCODE -ne 0) { throw 'WASM build failed.' }
  if (-not $SkipTests) {
    ctest --preset wasm-release
    if ($LASTEXITCODE -ne 0) { throw 'Typst integration tests failed.' }
  }
} finally { Pop-Location }
