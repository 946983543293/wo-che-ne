<#
.SYNOPSIS
  WoCheNe ("我车呢") Flutter command wrapper for Windows / PowerShell.

.DESCRIPTION
  Environment trap found during T02:
  The host process (WorkBuddy desktop) intermittently injects a LOCAL http proxy into
  child shells, e.g.:
      HTTP_PROXY / HTTPS_PROXY / http_proxy / https_proxy = http://127.0.0.1:<port>
  It is injected only sometimes, so the symptom looks flaky: `flutter test` connects to
  the flutter_tester process via a WebSocket to the loopback VM Service. If that loopback
  connection is routed through the injected proxy it fails with:
      Unable to connect to flutter_tester process:
      WebSocketException: Invalid WebSocket upgrade request
  (`flutter run` shows the same error while attaching to the VM Service.)

  Fix: add the loopback addresses to NO_PROXY so they bypass the proxy. This wrapper sets
  NO_PROXY on every invocation, making `flutter test` / `flutter analyze` / `flutter build`
  reliable regardless of the host environment.

.NOTES
  Arguments are forwarded verbatim via the automatic `$args` variable (there is NO param
  block and NO [CmdletBinding()] on purpose). A param block with [CmdletBinding()] adds
  PowerShell common parameters, which would intercept flags like `--debug` (bound to the
  built-in `-Debug`) and silently drop them before they reach flutter.

  This file is intentionally ASCII-only: Windows PowerShell 5.1 reads .ps1 files using the
  system ANSI codepage unless a UTF-8 BOM is present, so keeping it ASCII avoids mojibake.

.EXAMPLE
  .\tool\flutter.ps1 pub get
  .\tool\flutter.ps1 analyze
  .\tool\flutter.ps1 test
  .\tool\flutter.ps1 build apk --debug
#>

# Keep native-command stderr writes (e.g. flutter's mirror/analytics notices) from being
# turned into terminating errors: under Windows PowerShell 5.1 the combination of
# `$ErrorActionPreference = 'Stop'` and a native exe writing to stderr raises
# NativeCommandError and aborts the run ("flutter analyze" never finishes). 'Continue'
# lets the wrapper behave identically on 5.1 and 7.x. Exit code is propagated below.
$ErrorActionPreference = 'Continue'

# 1) Make loopback bypass any injected proxy (both cases for toolchain compatibility).
$env:NO_PROXY = 'localhost,127.0.0.1,::1'
$env:no_proxy = 'localhost,127.0.0.1,::1'

# 2) Locate the flutter executable: PATH -> FLUTTER_ROOT -> common install dirs.
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter -and $env:FLUTTER_ROOT) {
  $candidate = Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'
  if (Test-Path $candidate) { $flutter = $candidate }
}
if (-not $flutter) {
  foreach ($c in @('C:\flutter\bin\flutter.bat', 'C:\src\flutter\bin\flutter.bat')) {
    if (Test-Path $c) { $flutter = $c; break }
  }
}
if (-not $flutter) {
  throw 'flutter executable not found: add flutter to PATH or set FLUTTER_ROOT.'
}

Write-Host "[tool/flutter.ps1] flutter = $flutter" -ForegroundColor DarkGray
Write-Host "[tool/flutter.ps1] NO_PROXY = $env:NO_PROXY" -ForegroundColor DarkGray
Write-Host "[tool/flutter.ps1] args = $($args -join ' ')" -ForegroundColor DarkGray

& $flutter @args
exit $LASTEXITCODE
