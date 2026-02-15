[CmdletBinding()]
param
(
  [switch]$Rebuild
)

if(-not $(Get-Command docker -ErrorAction SilentlyContinue))
{
  throw "The command [docker] not found cannot continue program"
}

Set-Location $PSScriptRoot

if($Rebuild -or ((docker images nv | Select-Object -Skip 1)) -match 'nv')
{
  docker build -t nv .
}

docker run --rm -it -v .:/test -v .luarocks:/root/.luarocks nv bash -c 'luarocks test --local'
