# TODO / 待办

## update.img（未完成）

- 现状：`update.img` 已用 afptool-rs 生成（RKFW + RKAF），但 RKDevTool v3.37 报「加载固件失败」
- 已排查：
  - AFPTool 2.28 + RKImageMaker 2.23 组合报 `Get image version failed`
  - RKAF 头 version 字段（偏移 128/132）补值无效
  - 仓库内所有 RKImageMaker 都是 2.23
- 下一步可选：
  1. 找到与 RKImageMaker 2.23 配套的 **AFPTool 2.23**，用它重新打包 firmware.img
  2. 逆向 RKDevTool 对 RKFW 头的校验字段
  3. 用第三方 RockUSB 实现（如 hiifong/rkdevtool、rkflash-rs）直接刷 RKFW
  4. 用 Rockchip 官方 `upgrade_tool`（Linux x86-64，已在 tools/ 下载）在 WSL 里刷 update.img
- 在此之前请使用整盘镜像 + flash-g98.ps1

## 整盘镜像

- 已在实机验证过同内容启动（当前板子跑的就是这套 rootfs）
- flash-g98.ps1 还需一次完整上机验证（MaskROM → 脚本刷写 → 启动）

## 其他

- 8 个 1G 网口待插线验证
- HDMI 音频 ELD 告警待确认
- GPU devfreq 告警可忽略
