param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $GraphifyArgs
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$localDeps = Join-Path $repoRoot ".graphify-deps"
$networkxPackage = Join-Path $localDeps "networkx"

if (-not (Test-Path $networkxPackage)) {
    Write-Error "Missing .graphify-deps\networkx. Run: C:\Python314\python.exe -m pip install networkx --target .graphify-deps"
    exit 1
}

$pythonPaths = @()
$pythonPaths += (Resolve-Path $localDeps).Path
if ($env:PYTHONPATH) {
    $pythonPaths += $env:PYTHONPATH
}

$env:PYTHONPATH = ($pythonPaths | Where-Object { $_ } | Select-Object -Unique) -join [IO.Path]::PathSeparator

$graphify = Get-Command graphify.exe -ErrorAction Stop
& $graphify.Source @GraphifyArgs
exit $LASTEXITCODE
