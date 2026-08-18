# Generic grep helper: search patterns in .gd/.tscn files (findstr is unreliable with UTF-8)
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools\grep.ps1 "<pattern>"
param([string]$Pattern = "")
$Pattern = $Pattern.Trim('"')   # 工具会把外层引号原样传入，先剥离
if ($Pattern -eq "") { Write-Output "provide a pattern"; exit 1 }

$root = Split-Path -Parent $PSScriptRoot
$files = @(Get-ChildItem -Path (Join-Path $root "scripts") -Recurse -Include *.gd -File)
$files += @(Get-ChildItem -Path (Join-Path $root "levels"), (Join-Path $root "scenes") -Include *.tscn -File -ErrorAction SilentlyContinue)
$files += @(Get-ChildItem -Path $root -Include *.md -File -ErrorAction SilentlyContinue)
Write-Output ("[grep] files=" + $files.Count + " pattern=" + $Pattern)

foreach ($f in $files) {
    $content = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    for ($i = 0; $i -lt $content.Count; $i++) {
        if ($content[$i] -match $Pattern) {
            Write-Output ($f.Name + ":" + ($i + 1) + ": " + $content[$i].Trim())
        }
    }
}
