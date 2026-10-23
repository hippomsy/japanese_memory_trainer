# ==========================================================================
#  파일   소스백업.ps1
#  역할   혈당콕 소스만 골라 압축한다. 빌드 찌꺼기와 예전 백업은 빼고.
# --------------------------------------------------------------------------
#  쓰는 법
#    파일 탐색기에서 이 파일을 오른쪽 눌러 "PowerShell에서 실행"
#    또는 PowerShell 을 열고   .\소스백업.ps1
#
#  왜 4기가가 되었나
#    · build, .dart_tool, .gradle 은 빌드할 때마다 새로 만들어지는 찌꺼기다.
#      합치면 몇 기가가 된다. 지워도 flutter pub get 한 번이면 되돌아온다.
#    · 프로젝트 폴더 안에 예전 백업(.zip, .egg)이 그대로 들어 있었다.
#      백업을 압축하면 그 안의 백업까지 다시 압축된다. 눈덩이처럼 불어난다.
#    · apk 폴더의 AAB 한 벌이 77메가다.
#
#  2026-09-12 : 소스만 골라 담는 자리를 두었다.
# ==========================================================================

$ErrorActionPreference = 'Stop'

# 이 스크립트가 놓인 자리를 프로젝트로 본다.
$src = $PSScriptRoot
$name = Split-Path $src -Leaf
$stamp = Get-Date -Format 'yyyyMMdd_HHmm'

# 백업을 둘 자리. 프로젝트 밖에 두어야 다음 백업에 딸려 들어가지 않는다.
$dest = Split-Path $src -Parent
$out  = Join-Path $dest "${name}_소스_$stamp.zip"
$work = Join-Path $env:TEMP "srcbak_$stamp"

Write-Host ''
Write-Host "  소스   $src"
Write-Host "  결과   $out"
Write-Host ''

# 빌드 찌꺼기를 먼저 털어낸다. 없으면 그냥 지나간다.
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host '  빌드 찌꺼기를 털어내는 중...'
    Push-Location $src
    flutter clean | Out-Null
    Pop-Location
}

# 담지 않을 폴더.
$skipDirs = @(
    'build', '.dart_tool', '.gradle', '.idea', '.vscode',
    'Pods', 'ephemeral', '.symlinks',
    'apk', 'node_modules', '_to_delete'
)

# 담지 않을 파일. 예전 백업과 빌드 결과물이다.
$skipFiles = @('*.zip', '*.egg', '*.apk', '*.aab', '*.lock.bak')

Write-Host '  소스만 골라 담는 중...'
robocopy $src $work /E /XD $skipDirs /XF $skipFiles /NFL /NDL /NJH /NJS /NP | Out-Null

if (-not (Test-Path $work)) {
    Write-Host '  담을 것을 찾지 못했습니다.' -ForegroundColor Red
    exit 1
}

if (Test-Path $out) { Remove-Item $out -Force }

Write-Host '  압축하는 중...'
Compress-Archive -Path (Join-Path $work '*') -DestinationPath $out -CompressionLevel Optimal

Remove-Item $work -Recurse -Force

$mb = [math]::Round((Get-Item $out).Length / 1MB, 1)
Write-Host ''
Write-Host "  끝났습니다.  $mb MB" -ForegroundColor Green
Write-Host "  $out"
Write-Host ''
Write-Host '  ※ 서명 키(.jks / key.properties)는 이 묶음에 함께 들어 있습니다.'
Write-Host '     이 파일을 남에게 보내거나 공개된 곳에 올리지 마세요.'
Write-Host ''
