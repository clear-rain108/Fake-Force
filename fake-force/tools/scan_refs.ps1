# 扫描脚本引用：找出未被任何场景/代码引用的 .gd 脚本
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File tools/scan_refs.ps1
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$scripts = Get-ChildItem -Path (Join-Path $root "scripts") -Filter *.gd -Name
$searchFiles = @()
$searchFiles += Get-ChildItem -Path $root -Recurse -Include *.tscn, *.gd, *.cfg, *.godot -File -ErrorAction SilentlyContinue

Write-Output "=== 每个脚本的引用计数 ==="
foreach ($s in $scripts) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($s)
    $count = 0
    $refs = @()
    foreach ($f in $searchFiles) {
        $content = Get-Content -LiteralPath $f.FullName -Encoding UTF8 -Raw -ErrorAction SilentlyContinue
        if ($content -and $content.Contains($s)) {
            $count++
            $refs += $f.Name
        }
    }
    if ($count -eq 0) {
        Write-Output ("[未引用] " + $s)
    } elseif ($count -le 2) {
        Write-Output ("[少引用] " + $s + " x" + $count + " <- " + ($refs -join ","))
    }
}
