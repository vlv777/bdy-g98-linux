# 构建 Deepin 25 rootfs

## 环境

- WSL2 Ubuntu 24.04（非 root 用户 builder）
- qemu-user-static + binfmt
- squashfs-tools、e2fsprogs

## 1. 解包 Deepin 25 ISO

```bash
sudo unsquashfs -d /root/rootfs live/filesystem.squashfs
sudo unsquashfs -d /root/rootfs-extra live/filesystem-extra.squashfs
# 合并 rootfs-extra 到 rootfs
```

## 2. chroot 配置

- `/etc/fstab`：root UUID 用 p2 文件系统 UUID
- 用户：root/1234，g98/1234（sudo/video/render/audio 组）
- `/etc/lightdm/lightdm.conf.d/50-autologin.conf`：autologin-user=g98
- locale 中文，时区 Asia/Shanghai
- 拷贝 G98 内核模块（/lib/modules/6.18.48-ophub）和 firmware

## 3. 生成 24GiB ext4 镜像

```bash
truncate -s 24G deepin-rootfs.img
mkfs.ext4 -F deepin-rootfs.img
mount -o loop deepin-rootfs.img /mnt
rsync -aHAX /root/rootfs/ /mnt/
umount /mnt
```

## 4. 组装整盘镜像

- 0x0：Armbian 镜像前 16MiB（loader + u-boot）
- 0x8000 扇区（16MiB）：p1 boot 分区镜像
- 0x108000 扇区（553,648,128 字节）：Deepin rootfs
- GPT：p1 32768–1079295，p2 1081344–(整盘-34)

脚本见 `scripts/build-image.ps1`（Windows 侧组装）。
