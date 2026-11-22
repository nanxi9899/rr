# RR 定制引导 v26.11.01

基于官方 [RROrg/rr](https://github.com/RROrg/rr) v26.9.0 已编译镜像定制，宿主仓库 `nanxi9899/rr`。

## 定制内容

| 项目 | 原版本 | 定制后 | 来源 |
|------|--------|--------|------|
| RR 版本号 | 26.9.0 | **26.11.01** | 手动设定 |
| Intel 核显驱动 (i915) | RR 内置版 | **6.18.56 LTS (261028.0)** | [moetayuko/intel-gpu-i915-backports](https://github.com/moetayuko/intel-gpu-i915-backports/releases/tag/I915_6.18.56_LTS_261028.0) |
| HDD db 硬盘插件 | v3.6.139 | **v3.7.140** | [007revad/Synology_HDD_db](https://github.com/007revad/Synology_HDD_db/releases/tag/v3.7.140) |

## 发布资产

镜像大文件通过 GitHub Release 发布（本仓库不放二进制文件，受单文件 100MB 限制）：

- `rr-26.11.01.img.zip` — 镜像 zip 压缩包（约 1.4 GiB，作为 Release 附件）
- `rr-26.11.01.img` — 定制引导镜像（3.5 GiB，超过 Release 2GB 上限，建议放网盘）
- [校验和 sha256sum.txt](sha256sum.txt)

## 修改明细

### 1. 版本号 26.11.01
- `p1/RR_VERSION`：`26.9.0` → `26.11.01`（GRUB 引导菜单读取）
- `p3/initrd-rr` 内 `opt/rr/include/consts.sh`：`RR_VERSION="26.11.01"`（RR 系统内部显示）

### 2. Intel i915 核显驱动 6.18.56 LTS
从发布包提取 14 个 `.ko` 模块，合并进以下 16 个平台/DSM 组合的模块包 `p3/modules/<平台>-<版本>-5.10.55.tgz`：

```
epyc7002   : 7.1 / 7.2 / 7.3 / 7.4
epyc7003   : 7.4
epyc7003ntb: 7.4
geminilakenk: 7.2 / 7.3 / 7.4
icelaked   : 7.4
r1000nk    : 7.2 / 7.3 / 7.4
v1000nk    : 7.2 / 7.3 / 7.4
```

同时将随包的 Intel 显卡固件合并进 `p3/modules/firmware.tgz` 的 `i915/` 目录。

> 新 i915.ko 依赖 `auxiliary / gpu_buddy / hdmi / video / backlight / i2c-algo-bit` 等模块，前 3 个由新包提供并已写入；`video`、`backlight` 由 DSM 内核内置，`i2c-algo-bit` 原在模块包中，依赖链完整。

### 3. HDD db 插件 v3.7.140
将 `p3/addons/hdddb/all.tgz` 内的 `root/usr/bin/hdddb.sh` 替换为 v3.7.140 的 `syno_hdd_db.sh`（MD5 校验通过）。

## 使用方法

1. 下载镜像并校验：
   ```bash
   sha256sum -c sha256sum.txt
   ```
2. 写入引导盘：
   ```bash
   sudo dd if=rr-26.11.01.img of=/dev/sdX bs=1M status=progress
   ```
3. 从引导盘启动，进入 RR 恢复界面后选择对应机型/DSM 版本安装。

## 风险提示

- 修改引导存在数据丢失风险，请务必备份重要数据后再使用。
- 本镜像仅供学习交流，禁止商业用途（遵循 GPL-V3 许可与免责声明）。
- i915 核显驱动仅在支持 iGPU 的平台（列表见上）生效，请按实际 CPU 核显选择对应机型。
- 若升级后出现驱动异常，可退回官方 26.9.0 镜像。

## 构建来源核对

- 官方基础镜像：`rr-26.9.0.img.zip`（SHA256 `cd5c44abffaeabafb754272bfc3345953bf4ac3a6344b719cdc853788a4b4119`，已校验一致）
- i915 驱动包：16 个平台包均通过官方校验
- HDD db：v3.7.140 源码包 `syno_hdd_db.sh`

上传发布操作见 [RELEASE-UPLOAD-GUIDE.md](RELEASE-UPLOAD-GUIDE.md)。
