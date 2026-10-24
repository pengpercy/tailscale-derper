# Tailscale DERP container

使用 **Tailscale 官方原版源码**构建的精简 DERP 镜像，支持纯 IP、自签名证书及证书指纹校验。没有修改上游代码。

这是社区维护的容器封装，**不是 Tailscale 官方发布或背书的镜像**。

```sh
docker pull ghcr.io/pengpercy/tailscale-derper:1.104.2
docker run --rm ghcr.io/pengpercy/tailscale-derper:1.104.2 --version
```

支持 `linux/amd64` 和 `linux/arm64`。镜像基于 `scratch`，包含静态 DERP 程序、CA 证书、上游许可证和构建信息，不包含 shell、编译器或包管理器。完整使用上游命令行参数，未增加额外的环境变量入口。

## 纯 IP 部署

前提：宿主机已运行 Tailscale 并加入你的 Headscale/Tailnet。示例通过本机 Tailscale socket 校验客户端，避免开放给任意节点使用。应让宿主机 `tailscaled` 和 `derper` 保持相同上游版本；官方建议使用相同源码修订版。

```sh
cp .env.example .env
# 将 .env 中的 DERP_HOST 改为本服务器公网 IP。
mkdir -p certs
docker compose up -d
docker compose logs --tail 30
```

放行公网 **TCP 8090** 和 **UDP 3478**。不需要域名；此示例也不需要占用 80 或 443。每个服务限制为 1 核 CPU、512 MiB 内存，允许额外使用 512 MiB Swap（宿主机需配置 Swap）。

首次启动时，官方 DERP 会自动生成带 IP SAN 的自签名证书，并在日志中输出 `CertName`。在 Headscale 本地 DERP YAML 中配置对应证书指纹，例如：

```yaml
regions:
  900:
    regionid: 900
    regioncode: custom
    regionname: Custom DERP
    nodes:
      - name: custom-derp
        regionid: 900
        hostname: 192.0.2.10
        ipv4: 192.0.2.10
        derpport: 8090
        stunport: 3478
        certname: "sha256-raw:替换为日志输出的完整SHA256指纹"
```

**不要添加 `insecurefortests: true`**。指纹需要通过可信渠道写入控制服务。加载 map 后，检查客户端 `tailscale debug derp-map`、`tailscale status` 和 `tailscale netcheck`。

证书目录和 DERP 身份数据卷必须持久保存。手动证书更新后需重启 DERP；更换证书时也必须更新 Headscale 的指纹。`docker compose down -v` 会删除身份数据卷，正常升级请使用 `docker compose pull && docker compose up -d`。

## 构建与发布

```sh
docker build --build-arg VERSION="$(cat VERSION)" -t local/derper:1.104.2 .
```

GitHub Actions 在主分支推送、版本标签或手动触发时，先验证 amd64 版本和自签名 IP TLS 启动，再发布 amd64/arm64 镜像及构建来源证明到 GHCR。只使用 GitHub 自动提供的 `GITHUB_TOKEN`，仓库不需要保存个人访问令牌。

`Dockerfile` 固定上游模块版本，Go 保留默认模块校验。`VERSION` 是发布版本；升级时同步修改 Dockerfile 默认版本与 Compose 示例，然后检查对应 Go 工具链要求。版本 tag 用于固定上游版本，`latest` 会随发布更新；需要固定镜像内容时可使用 GHCR 提供的 digest。

镜像内 `/BUILD-INFO.txt` 记录 Go 版本、上游模块和依赖校验和，可通过 `docker create` 与 `docker cp` 导出。不要把服务器私钥、证书、Tailscale 状态或真实 `.env` 提交到仓库。

## 上游

- [Tailscale DERP 源码与运行说明](https://github.com/tailscale/tailscale/tree/main/cmd/derper)
- [官方自签名 IP 证书与指纹实现](https://github.com/tailscale/tailscale/blob/v1.104.2/cmd/derper/cert.go)
- [Headscale DERP 配置](https://headscale.net/stable/ref/derp/)

上游 DERP 使用 BSD-3-Clause 许可证；上游许可证保存在镜像 `/LICENSE`。本仓库的容器与配置文件同样采用 BSD-3-Clause。
