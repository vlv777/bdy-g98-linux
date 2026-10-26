param(
  [string]$ArmbianImage = "Armbian_bdy-g98_bookworm_6.18.48.img",
  [string]$P1Image = "p1_armbian_boot.img",
  [string]$RootfsImage = "deepin-rootfs.img",
  [string]$Output = "G98-Deepin25-arm64.img"
)
$ErrorActionPreference = 'Stop'
function Log($m){ Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] " + $m) }
if (-not (Test-Path $ArmbianImage)) { throw "缺少 Armbian 镜像: $ArmbianImage" }
if (-not (Test-Path $P1Image)) { throw "缺少 p1 镜像: $P1Image" }
if (-not (Test-Path $RootfsImage)) { throw "缺少 rootfs 镜像: $RootfsImage" }
$p2off = [long]553648128
$total = $p2off + (Get-Item $RootfsImage).Length
Log ("输出镜像: " + $Output + "  总大小 " + [math]::Round($total/1GB,2) + " GB")
$fs = [System.IO.File]::Open($Output, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
try {
  $fs.SetLength($total)
  $buf = New-Object byte[] (16*1024*1024)
  $a = [System.IO.File]::Open($ArmbianImage, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  try { [void]$a.Read($buf,0,$buf.Length) } finally { $a.Close() }
  $fs.Position = 0; $fs.Write($buf,0,$buf.Length); $fs.Flush()
  Log "写入 16MiB 引导区"
  $p = [System.IO.File]::Open($P1Image, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  try {
    $fs.Position = 16*1024*1024
    $b2 = New-Object byte[] (4*1024*1024); [long]$w=0
    while (($n=$p.Read($b2,0,$b2.Length)) -gt 0) { $fs.Write($b2,0,$n); $w+=$n }
    $fs.Flush(); Log ("写入 p1: " + $w + " bytes")
  } finally { $p.Close() }
  $r = [System.IO.File]::Open($RootfsImage, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  try {
    $fs.Position = $p2off
    $b3 = New-Object byte[] (8*1024*1024); [long]$w=0; $last=[DateTime]::Now
    while (($n=$r.Read($b3,0,$b3.Length)) -gt 0) {
      $fs.Write($b3,0,$n); $w+=$n
      if (((Get-Date)-$last).TotalSeconds -ge 5) { Log ("rootfs 进度 " + [math]::Round($w/1GB,1) + " GB"); $last=Get-Date }
    }
    $fs.Flush(); Log ("写入 rootfs: " + $w + " bytes")
  } finally { $r.Close() }
} finally { $fs.Close() }
Log "完成。分区表由 flash-g98.ps1 在刷写时按实际 eMMC 大小生成"
