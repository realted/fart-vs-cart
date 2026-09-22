param(
    [ValidateSet('cuda_sdl_demo','raytracer_cpu')]
    [string]$Target = 'cuda_sdl_demo',
    [switch]$Run,
    [string[]]$ProgramArgs = @()
)
$ErrorActionPreference = 'Stop'
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -version '[17.0,18.0)' -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
if (-not $vs) { throw 'Visual Studio 2022 C++ tools were not found.' }
$cmake = Join-Path $vs 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
if (-not (Test-Path $cmake)) {
    $cmake = (Get-Command cmake -ErrorAction Stop).Source
}
$build = Join-Path $PSScriptRoot 'build-cuda'
& $cmake -S $PSScriptRoot -B $build -G 'Visual Studio 17 2022' -A x64 -T 'cuda=12.6,version=14.39'
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }
& $cmake --build $build --config Release --target $Target
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
$exe = Join-Path $build "Release\$Target.exe"
Write-Host "Built $exe"
if ($Run) {
    Push-Location $PSScriptRoot
    try {
        & $exe @ProgramArgs
        if ($LASTEXITCODE -ne 0) { throw "Program exited with code $LASTEXITCODE" }
    } finally { Pop-Location }
}
