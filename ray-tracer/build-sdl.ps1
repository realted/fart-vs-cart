param(
    [string]$Source = 'src/test.cpp',
    [switch]$Run,
    [string[]]$ProgramArgs = @()
)
$ErrorActionPreference = 'Stop'
$compiler = 'C:\msys64\ucrt64\bin\g++.exe'
$sdk = Join-Path $PSScriptRoot 'sdl2-sdk'
$sourcePath = if ([IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $PSScriptRoot $Source }
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Source not found: $sourcePath" }
$buildDir = Join-Path $PSScriptRoot 'sdl-support/bin'
New-Item -ItemType Directory -Force $buildDir | Out-Null
$exe = Join-Path $buildDir ([IO.Path]::GetFileNameWithoutExtension($sourcePath) + '.exe')
& $compiler -std=c++17 -O2 -Wall -Wextra -Wpedantic "-I$sdk/include" "-I$sdk/include/SDL2" $sourcePath "-L$sdk/lib" -lmingw32 -lSDL2main -lSDL2 -o $exe
if ($LASTEXITCODE -ne 0) { throw 'SDL build failed.' }
Copy-Item -LiteralPath "$sdk/bin/SDL2.dll" -Destination $buildDir -Force
Write-Host "Built $exe"
if ($Run) {
    $previousPath = $env:PATH
    try {
        $env:PATH = "C:\msys64\ucrt64\bin;$previousPath"
        & $exe @ProgramArgs
        if ($LASTEXITCODE -ne 0) { throw "Program exited with code $LASTEXITCODE" }
    } finally { $env:PATH = $previousPath }
}
