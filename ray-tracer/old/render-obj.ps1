param(
    [string]$Obj = 'models/cube.obj',
    [int]$Width = 640,
    [int]$Samples = 64,
    [double]$Scale = 0.35,
    [double]$X = 1.0,
    [double]$Y = -0.15,
    [double]$Z = -1.2
)
$ErrorActionPreference='Stop'
$path=if([IO.Path]::IsPathRooted($Obj)){$Obj}else{Join-Path $PSScriptRoot $Obj}
if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "OBJ not found: $path"}
$culture=[Globalization.CultureInfo]::InvariantCulture
$arguments=@("$Width","$Samples",'--obj',$path,'--scale',$Scale.ToString($culture),'--position',$X.ToString($culture),$Y.ToString($culture),$Z.ToString($culture))
& (Join-Path $PSScriptRoot 'build-sdl.ps1') -Source src/SDL.cpp -Run -ProgramArgs $arguments
