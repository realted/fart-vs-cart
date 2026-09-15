param([switch]$Render, [int]$Width = 640, [int]$Samples = 32)
$ErrorActionPreference = 'Stop'
$compiler = Get-Command g++ -ErrorAction SilentlyContinue
if (-not $compiler) { throw 'g++ is required. Add your MSYS2 UCRT64 bin folder to PATH.' }
$buildDir = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force $buildDir | Out-Null
$executable = Join-Path $buildDir 'raytracer.exe'
& $compiler.Source -std=c++17 -O2 -Wall -Wextra -Wpedantic (Join-Path $PSScriptRoot 'src/test.cpp') -o $executable
if ($LASTEXITCODE -ne 0) { throw 'C++ compilation failed.' }
Write-Host "Built $executable"
if ($Render) {
    & $executable (Join-Path $PSScriptRoot 'render.bmp') $Width $Samples
    if ($LASTEXITCODE -ne 0) { throw 'Rendering failed.' }
}
