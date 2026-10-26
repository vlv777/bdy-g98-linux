# update.img 升级方式

## 文件

- `update.img`：RKFW 封装，BOOT = rk3588_spl_loader_v1.21.114_only-emmc.bin，内置 RKAF（parameter + uboot + boot + rootfs）

## 生成方式

用 [afptool-rs](https://github.com/suyulin/afptool-rs) 打包：

```bash
# RKAF
afptool-rs pack-rkaf --model RK3588 --manufacturer RK3588 rkaf_pkg update_rkaf.img
# RKFW
afptool-rs pack-rkfw rkfw_pkg update.img -c RK3588 -v 1.0.0 -t 1761440000 --code 0x02000000
```

目录结构：

```
rkaf_pkg/
  package-file
  parameter.txt
  uboot.img
  boot.img
  rootfs.img
  partition-metadata.txt   # name,full_path,flash_size,flash_offset,part_offset,padded_size,part_byte_count
rkfw_pkg/
  BOOT                     # eMMC loader
  embedded-update.img      # 上面打出的 RKAF
```

## 分区布局

- IDB loader：sector 0x40（RKDevTool 自动写）
- uboot：0x4000 sectors（8MiB）
- boot：0x8000 sectors（16MiB），512MiB
- rootfs：0x108000 sectors（553,648,128 字节），24GiB

## 使用

RKDevTool → 升级固件 → 选择 `update.img` → 升级。

> 注意：这条路径尚未在实机上完成最终验证，优先使用整盘镜像 + flash-g98.ps1。


## 关键修复（2026-10-26）

RKImageMaker 2.23 生成 update.img 时必须用 `-os_type:androidos`，用 `RKOS` 会报
`Get image version failed`。这是 Rockchip Linux SDK 的官方用法（androidos 只代表容器格式）。

```powershell
RKImageMaker.exe -RK3588 loader.bin firmware.img update.img -os_type:androidos -storage:EMMC
```
