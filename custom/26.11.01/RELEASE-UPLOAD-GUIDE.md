# RR 26.11.01 镜像发布指引

本仓库不存放二进制镜像（GitHub 仓库单文件上限 100MB）。请按下面步骤在网页端创建 Release 并上传镜像。

## GitHub 大小限制（先读）

| 文件 | 大小 | 能否作为 Release 附件 |
|------|------|----------------------|
| `rr-26.11.01.img.zip` | 约 1.4 GiB | ✅ 可以（Release 单附件上限 2GB） |
| `rr-26.11.01.img` | 3.5 GiB | ❌ 不行（超过 2GB 上限，建议放网盘/夸克/百度网盘） |

## 步骤

1. 打开 Release 新建页：
   https://github.com/nanxi9899/rr/releases/new

2. 填写信息：
   - **Tag version**：`26.11.01`（若该 tag 已存在，先选已有 tag）
   - **Release title**：`RR 26.11.01 (i915 6.18.56 + HDD db 3.7.140)`
   - **Description**（可复制下面模板）

3. 上传附件：把 `rr-26.11.01.img.zip` 拖到附件区，等待上传完成。

4. 点击 **Publish release**。

5. （可选）把 3.5GB 的 `rr-26.11.01.img` 上传到网盘，将链接补充到 Release 描述里。

## Release 描述模板

```markdown
RR 定制引导 v26.11.01

- 版本号：26.11.01
- Intel i915 核显驱动：6.18.56 LTS (261028.0)
- HDD db 插件：v3.7.140
- 基于官方 26.9.0 镜像定制

下载：rr-26.11.01.img.zip
校验和见仓库 custom/26.11.01/sha256sum.txt

> 仅供学习交流，严禁商用；修改引导有风险，请先测试备份。
```

## 上传后校验

下载方校验：

```bash
sha256sum -c sha256sum.txt
# 期望输出：
# rr-26.11.01.img: OK
# rr-26.11.01.img.zip: OK
```
