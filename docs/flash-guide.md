# 刷机指南

## 你需要

- Windows PC
- USB 数据线（接板子 OTG 口，靠近 HDMI 的那个 USB3 口）
- 镊子（短接 MaskROM）
- TTL 串口线（可选，推荐）
- RKDevTool 2017 eMMC 工具包（Release 附）
- 本仓库的 `G98-Deepin25-arm64.img`

## 步骤

### 1. 进 MaskROM

断电，镊子短接 SPI 位置两个圆点，保持短接上电，电脑识别到 Rockchip MaskROM 后松手。

### 2. 刷临时引导

RKDevTool 打开 2017 工具包：

- 勾选 Loader、parameter、uboot
- **取消勾选 recovery**
- 点「执行」

刷完板子会停在 U-Boot 的 `=>` 提示符。

### 3. 一键写盘

```powershell
cd scripts
.\flash-g98.ps1 -Image ..\G98-Deepin25-arm64.img
```

脚本会：

1. 自动找停在 U-Boot 的串口（1500000）
2. 发送 `ums 0 mmc 0`
3. 等 eMMC 作为 U 盘出现
4. 按扇区写整盘镜像
5. 按实际 eMMC 大小重建主/备 GPT（p2 扩到整盘）
6. 复位

### 4. 首次启动

- 默认自动登录 g98
- 账号：`g98 / 1234`，`root / 1234`

## 恢复

- 镜像写入出错：重新进 MaskROM，重复步骤 2-3
- 完全救砖：MaskROM + RKDevTool 刷 2017 eMMC recovery 包
