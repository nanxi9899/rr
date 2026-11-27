# RR 定制引导 v26.11.01（i915 6.18.56 + HDD db 3.7.140）

基于官方 [RROrg/rr](https://github.com/RROrg/rr) v26.9.0 已编译镜像定制。

> 镜像下载请到本仓库 [Releases](https://github.com/nanxi9899/rr/releases) 页面（与 v26.11.0 相同位置）。

## 定制内容

| 项目 | 原版本 | 定制后 | 来源 |
|------|--------|--------|------|
| RR 版本号 | 26.9.0 | **26.11.01** | 手动设定 |
| Intel 核显驱动 (i915) | RR 内置版 | **6.18.56 LTS (261028.0)** | [moetayuko/intel-gpu-i915-backports](https://github.com/moetayuko/intel-gpu-i915-backports/releases/tag/I915_6.18.56_LTS_261028.0) |
| HDD db 硬盘插件 | v3.6.139 | **v3.7.140** | [007revad/Synology_HDD_db](https://github.com/007revad/Synology_HDD_db/releases/tag/v3.7.140) |

## 发布资产

- `rr-26.11.01.img.zip` — 约 1.4 GiB，作为 Release 附件（Release 单附件上限 2GB）
- `rr-26.11.01.img` — 3.5 GiB，超过 2GB 上限，建议放网盘
- 校验和见 [sha256sum-26.11.01.txt](sha256sum-26.11.01.txt)

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

同时将随包的 Intel 显卡固件合并进 `p3/modules/firmware.tgz` 的 `i915/` 目录。新 i915.ko 的依赖链已核对完整。

### 3. HDD db 插件 v3.7.140
将 `p3/addons/hdddb/all.tgz` 内的 `root/usr/bin/hdddb.sh` 替换为 v3.7.140 的 `syno_hdd_db.sh`（MD5 校验通过）。

## 使用方法

```bash
sha256sum -c sha256sum-26.11.01.txt
sudo dd if=rr-26.11.01.img of=/dev/sdX bs=1M status=progress
```

## 风险提示

- 修改引导存在数据丢失风险，请务必备份重要数据后再使用。
- 本镜像仅供学习交流，禁止商业用途（遵循 GPL-V3 许可与免责声明）。
- i915 核显驱动仅在支持 iGPU 的平台生效，请按实际 CPU 核显选择对应机型。
- 若升级后出现驱动异常，可退回官方 26.9.0 镜像。

## 构建来源核对

- 官方基础镜像：`rr-26.9.0.img.zip`（SHA256 `cd5c44abffaeabafb754272bfc3345953bf4ac3a6344b719cdc853788a4b4119`，已校验一致）
- i915 驱动包：16 个平台包均通过官方校验
- HDD db：v3.7.140 源码包 `syno_hdd_db.sh`

## 素材入库（vendored assets）

定制素材已随仓库提交到 `assets/` 目录，构建脚本 `scripts/build-custom-26.11.01.sh` 直接使用本地副本，不再在 CI 阶段从外部 release 下载 i915 包或 hdddb 脚本：

```
assets/
├── i915/
│   └── i915-dsm-<平台>-<DSM 版本>-1.6.18.56.261028.0.tar.gz   # 16 个平台包
└── hdddb/
    ├── hdddb.sh        # syno_hdd_db.sh v3.7.140
    └── install.sh      # RR addon late/uninstall 安装脚本（与 RROrg/rr-addons 上游一致）
```

- i915 上游来源：`moetayuko/intel-gpu-i915-backports` tag `I915_6.18.56_LTS_261028.0`。
- hdddb 上游来源：`007revad/Synology_HDD_db` tag `v3.7.140`。
- 基础镜像仍在 CI 阶段从 `RROrg/rr` 官方 release 拉取（26.9.0）。

上传发布操作见 [RELEASE-UPLOAD-GUIDE-26.11.01.md](RELEASE-UPLOAD-GUIDE-26.11.01.md)。
