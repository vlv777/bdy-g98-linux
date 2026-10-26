# BDY G98 (RK3588) Linux Port — Deepin 25

把「彼度云 G98」RK3588 开发板（16GB LPDDR4X / 128GB eMMC 后焊 / HDMI 后焊）改造成可用的 ARM64 桌面 / NAS。

## 当前状态

- Deepin 25 (crimson) 可以启动，DDE 桌面正常，1920x1080 HDMI 输出
- 内核：Armbian 6.18.48-ophub + G98 专用 DTB（rk3588-bdy-g98.dtb）
- eMMC：128GB（SLD128）被正确识别，根分区已扩到 113GB
- 网络：2.5G RTL8125B 口可用（DHCP）
- 已修：时区、磁盘扩容、开机等待服务、zram swap、失败服务清理

## 已知问题

- RTC（hym8563）初始化失败，板子无电池，时间靠 NTP
- HDMI 音频日志报 Unknown ELD，但 PipeWire 有 HDMI sink
- 8 个 1G 网口（yt921x DSA）驱动已加载，未插线验证
- GPU devfreq 有告警，实测频率可在 300MHz–1GHz 间切换
- eth0/eth1 为随机 MAC

## 刷机

见 [docs/flash-guide.md](docs/flash-guide.md)。简要流程：

1. 断电，短接 SPI 位置两个圆点进 MaskROM
2. RKDevTool 只刷 Loader + parameter + uboot（不勾 recovery），板子停在 U-Boot
3. 运行 `scripts/flash-g98.ps1`，自动串口发 `ums 0 mmc 0`、写整盘镜像、重建 GPT
4. 重启进 Deepin

默认账号：`g98 / 1234`，`root / 1234`

## 镜像

- `G98-Deepin25-arm64.img`（24.5GiB，压缩分卷见 Release）
- 布局：p1 boot 512MiB @ sector 32768，p2 rootfs @ sector 1081344

## 构建

见 [docs/build-deepin25.md](docs/build-deepin25.md)。

## 致谢

- [ophub](https://github.com/ophub) Armbian 内核 / 引导
- Deepin 社区
