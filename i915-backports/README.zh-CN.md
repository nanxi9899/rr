# Intel i915 GPU Backports for DSM / PVE

本目录集成自 [moetayuko/intel-gpu-i915-backports](https://github.com/moetayuko/intel-gpu-i915-backports)
的 `oot-backport/main` 分支,为 DSM/PVE 提供更新的 Intel 核显(i915)内核模块 backport,
增强硬解/转码(Quick Sync Video)支持。本引导版本: **26.11.0**。

## 目录结构
- `backport/` — backport 框架核心(新版内核驱动适配到旧内核)
- `patches/` / `patches-dsm/` — 通用补丁 / **DSM 专用补丁**
- `integration-patches/` — 启用 backports 的集成补丁
- `autotools/`, `lib/`, `devel/` — 构建工具与辅助脚本
- `gentree.py` — 从匹配内核源码生成 backport 包

## 编译/使用概要
1. 准备与目标 DSM 内核匹配的 Linux 内核源码树。
2. `./gentree.py /path/to/linux-kernel /path/to/output` 生成 backport 包。
3. `cd output && make defconfig && make -j$(nproc)` 编译 i915 模块。
4. 将 `i915.ko` 及依赖模块(`drm.ko`、`i2c-algo-bit.ko` 等)放入 DSM 模块目录后加载。
5. 配合 `files/initrd/opt/rr/i915ids` 白名单让 DSM 识别核显。

## 注意
> 硬盘有价,数据无价。修改驱动/引导有风险,请先在测试环境验证,仅供学习交流,严禁商用。
- 本目录只含源码,不含预编译 `.ko`;需在 DSM/交叉编译环境编译。
- 受上游许可证约束(见 `COPYING`,GPL)。

上游:https://github.com/moetayuko/intel-gpu-i915-backports
