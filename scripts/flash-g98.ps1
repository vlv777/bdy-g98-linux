param([string]$Image = (Join-Path $PSScriptRoot "G98-Deepin25-arm64.img"),[string]$Port = "",[int]$Baud = 1500000,[int]$WaitUmsSec = 90)
$ErrorActionPreference = 'Stop'
function Log($m){ Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] " + $m) }
$script:crcTable = New-Object 'uint32[]' 256
for ($i=0; $i -lt 256; $i++) {
  [uint32]$c = $i
  for ($k=0; $k -lt 8; $k++) { if (($c -band 1) -ne 0) { $c = [uint32](0xEDB88320 -bxor ($c -shr 1)) } else { $c = [uint32]($c -shr 1) } }
  $script:crcTable[$i] = $c
}
function Get-Crc32([byte[]]$data) {
  [uint32]$c = 0xFFFFFFFF
  foreach ($x in $data) { $c = [uint32]($script:crcTable[(($c -bxor $x) -band 0xFF)] -bxor ($c -shr 8)) }
  return [uint32]($c -bxor 0xFFFFFFFF)
}
$DISK_GUID  = [byte[]](0x8a,0x57,0x71,0xbf,0xe5,0x4c,0x4d,0x1d,0x98,0xdf,0xa9,0x0d,0x40,0xd6,0x59,0x66)
$TYPE_LINUX = [byte[]](0x0f,0xc6,0x3d,0xaf,0x84,0x83,0x47,0x72,0x8e,0x79,0x3d,0x69,0xd8,0x47,0x7d,0xe4)
$P1_GUID    = [byte[]](0x6a,0x25,0x57,0x5c,0x83,0x7b,0x4a,0x49,0xb5,0x13,0xcd,0x0c,0x78,0x87,0x39,0x98)
$P2_GUID    = [byte[]](0xc3,0x97,0x0a,0xdb,0x7c,0x77,0xd4,0x4d,0x87,0x2b,0x4e,0x34,0x20,0x9c,0x14,0xf4)
function U32([uint32]$v){ return [BitConverter]::GetBytes($v) }
function U64([uint64]$v){ return [BitConverter]::GetBytes($v) }
function New-GptEntry([byte[]]$tg,[byte[]]$ug,[uint64]$first,[uint64]$last,[string]$name){
  $e = New-Object byte[] 128
  [Array]::Copy($tg,0,$e,0,16); [Array]::Copy($ug,0,$e,16,16)
  [Array]::Copy((U64 $first),0,$e,32,8); [Array]::Copy((U64 $last),0,$e,40,8)
  $nm = [System.Text.Encoding]::Unicode.GetBytes($name); [Array]::Copy($nm,0,$e,56,$nm.Length)
  return $e
}
function New-GptHeader([uint64]$myLba,[uint64]$altLba,[uint64]$entriesLba,[uint64]$lastUsable,[uint32]$entriesCrc){
  $h = New-Object byte[] 92
  [Array]::Copy([System.Text.Encoding]::ASCII.GetBytes("EFI PART"),0,$h,0,8)
  [Array]::Copy((U32 0x00010000),0,$h,8,4); [Array]::Copy((U32 92),0,$h,12,4); [Array]::Copy((U32 0),0,$h,16,4)
  [Array]::Copy((U64 $myLba),0,$h,24,8); [Array]::Copy((U64 $altLba),0,$h,32,8)
  [Array]::Copy((U64 34),0,$h,40,8); [Array]::Copy((U64 $lastUsable),0,$h,48,8)
  [Array]::Copy($DISK_GUID,0,$h,56,16); [Array]::Copy((U64 $entriesLba),0,$h,72,8)
  [Array]::Copy((U32 128),0,$h,80,4); [Array]::Copy((U32 128),0,$h,84,4)
  [Array]::Copy((U32 $entriesCrc),0,$h,88,4); [Array]::Copy((U32 (Get-Crc32 $h)),0,$h,16,4)
  $out = New-Object byte[] 512; [Array]::Copy($h,0,$out,0,92); return $out
}
function Try-UbootPort([string]$p){
  try {
    $sp = New-Object System.IO.Ports.SerialPort($p,$Baud,([System.IO.Ports.Parity]::None),8,([System.IO.Ports.StopBits]::One))
    $sp.ReadTimeout = 800; $sp.WriteTimeout = 800; $sp.DtrEnable = $true; $sp.Open()
    Start-Sleep -Milliseconds 300; $sp.Write([string][char]13)
    $deadline = (Get-Date).AddSeconds(6); $buf = ""
    while ((Get-Date) -lt $deadline) { try { $buf += $sp.ReadExisting() } catch {}; if ($buf -match "=>") { return $sp }; Start-Sleep -Milliseconds 200 }
    $sp.Close(); return $null
  } catch { return $null }
}
Log "查找 U-Boot 串口..."
$sp = $null
if ($Port -ne "") { $sp = Try-UbootPort $Port; if (-not $sp) { throw "串口无 U-Boot 响应" } }
else { foreach ($pn in [System.IO.Ports.SerialPort]::GetPortNames()) { Log ("尝试 " + $pn); $sp = Try-UbootPort $pn; if ($sp) { Log ("找到 U-Boot: " + $pn); break } } }
if (-not $sp) { throw "未找到停在 U-Boot 的串口。请断电短接进 MaskROM，用 RKDevTool 只刷 Loader+parameter+uboot（不勾 recovery），停在 U-Boot 后重跑。" }
$sp.Write("ums 0 mmc 0" + [char]13)
Log "等待 eMMC 作为 U 盘出现 ..."
$disk = $null; $deadline = (Get-Date).AddSeconds($WaitUmsSec)
while ((Get-Date) -lt $deadline) { $disk = Get-Disk -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -like "*UMS*" } | Select-Object -First 1; if ($disk) { break }; Start-Sleep -Seconds 2 }
if (-not $disk) { throw "等待 UMS 磁盘超时" }
$num = $disk.Number; $size = [uint64]$disk.Size; $total = [uint64]([math]::Floor($size/512))
Log ("UMS 磁盘: PhysicalDrive" + $num + " " + [math]::Round($size/1GB,1) + " GB")
if (-not (Test-Path $Image)) { throw ("镜像不存在: " + $Image) }
$imgLen = (Get-Item $Image).Length
Log ("写入镜像 " + [math]::Round($imgLen/1GB,2) + " GB ...")
$dst = [System.IO.File]::Open("\\.\PhysicalDrive" + $num, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
$src = [System.IO.File]::Open($Image, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
try {
  $buf = New-Object byte[] (8*1024*1024); [uint64]$w = 0; $lastLog = Get-Date
  while (($n = $src.Read($buf,0,$buf.Length)) -gt 0) {
    $dst.Write($buf,0,$n); $w += $n
    if (((Get-Date) - $lastLog).TotalSeconds -ge 3) { Log ("进度 " + [math]::Round($w/1GB,1) + " / " + [math]::Round($imgLen/1GB,1) + " GB"); $lastLog = Get-Date }
  }
  $dst.Flush(); Log ("镜像写入完成: " + $w)
} finally { $src.Close() }
$p1First=[uint64]32768; $p1Last=[uint64]1079295; $p2First=[uint64]1081344; $p2Last=[uint64]($total-34)
$entries = New-Object byte[] 16384
[Array]::Copy((New-GptEntry $TYPE_LINUX $P1_GUID $p1First $p1Last "primary"),0,$entries,0,128)
[Array]::Copy((New-GptEntry $TYPE_LINUX $P2_GUID $p2First $p2Last "primary"),0,$entries,128,128)
$ecrc = Get-Crc32 $entries; $lastLba = [uint64]($total-1)
$mbr = New-Object byte[] 512; $pe = New-Object byte[] 16
$pe[2]=0x02; $pe[4]=0xEE; $pe[5]=0xFF; $pe[6]=0xFF; $pe[7]=0xFF
[Array]::Copy((U32 1),0,$pe,8,4); [Array]::Copy((U32 ([uint32][math]::Min($total-1,0xFFFFFFFF))),0,$pe,12,4)
[Array]::Copy($pe,0,$mbr,446,16); $mbr[510]=0x55; $mbr[511]=0xAA
$pb = New-Object byte[] 17408
[Array]::Copy($mbr,0,$pb,0,512)
[Array]::Copy((New-GptHeader ([uint64]1) $lastLba ([uint64]2) ([uint64]($total-34)) $ecrc),0,$pb,512,512)
[Array]::Copy($entries,0,$pb,1024,16384)
$bb = New-Object byte[] 16896
[Array]::Copy($entries,0,$bb,0,16384)
[Array]::Copy((New-GptHeader $lastLba ([uint64]1) ([uint64]($lastLba-32)) ([uint64]($total-34)) $ecrc),0,$bb,16384,512)
$dst.Position = 0; $dst.Write($pb,0,$pb.Length)
$dst.Position = [int64](($lastLba-32)*512); $dst.Write($bb,0,$bb.Length)
$dst.Flush(); $dst.Close()
Log ("分区表写入完成 p2=" + $p2First + "-" + $p2Last)
try { $sp.Write([string][char]3); Start-Sleep -Milliseconds 800; $sp.Write("reset" + [char]13) } catch {}
Start-Sleep -Seconds 2; try { $sp.Close() } catch {}
Log "完成，板子重启进 Deepin"