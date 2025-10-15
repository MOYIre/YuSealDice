#!/bin/bash
# 快速编译脚本 适用于go语言项目 -爱来自铭茗

set -e

# 自动寻找项目根目录
ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT_DIR"

BUILD_DIR="./build"
mkdir -p "$BUILD_DIR"

# 检查 Go 环境
if ! command -v go >/dev/null 2>&1; then
    echo "未检测到 Go 环境"
    printf "是否自动安装 Go？(y/n): "
    read install_go
    if [ "$install_go" = "y" ]; then
        if command -v brew >/dev/null 2>&1; then
            brew install go
        elif command -v pkg >/dev/null 2>&1; then
            pkg install golang -y
        elif command -v apt >/dev/null 2>&1; then
            sudo apt install golang -y
        else
            echo "无法自动安装，请手动安装 Go"
            exit 1
        fi
    else
        echo "未安装 Go，退出"
        exit 1
    fi
fi

# 模块检测逻辑
if [ -d .git ]; then
    echo "检测到 Git 仓库"
    if [ ! -f go.mod ]; then
        repo_name=$(basename "$(git rev-parse --show-toplevel)")
        echo "未找到 go.mod，正在自动初始化模块：$repo_name"
        go mod init "$repo_name"
    fi
else
    echo "未检测到 Git 仓库"
    printf "是否要从远程仓库克隆？(y/n): "
    read pull
    if [ "$pull" = "y" ]; then
        printf "请输入仓库地址（例如 https://github.com/user/project.git）: "
        read repo_url
        git clone "$repo_url"
        cd "$(basename "$repo_url" .git)"
    else
        echo "未拉取仓库，退出"
        exit 1
    fi
fi

# 启用国内代理加速（如已设置则跳过）
if [ -z "$GOPROXY" ]; then
    export GOPROXY=https://goproxy.cn,direct
    echo "已设置 GOPROXY=https://goproxy.cn,direct"
fi

# 自动依赖修复
echo "🔍 检查 Go 依赖..."
if ! go list ./... >/dev/null 2>go_err.log; then
    echo "检测到缺失依赖，正在自动修复..."
    go mod tidy || true
    go get ./... || true
    go mod tidy

    # 检测 botgo/openapi/v2 报错
    if grep -q "botgo/openapi/v2" go_err.log; then
        echo "检测到 botgo/openapi/v2 缺失，自动回退到兼容版本 v0.1.10"
        go get github.com/tencent-connect/botgo@v0.1.10
        go mod tidy
    fi
fi
rm -f go_err.log

echo "御铭茗编译小助手"
echo "🐾快速编译选项🐾"
echo "1) Linux amd64"
echo "2) Linux arm64" 
echo "3) Windows amd64"
echo "4) Android arm64"
echo "5) macOS amd64"
echo "6) 所有以上平台"

printf "请选择 [1-6]: "
read choice

case $choice in
    1) TARGETS=("linux amd64") ;;
    2) TARGETS=("linux arm64") ;;
    3) TARGETS=("windows amd64") ;;
    4) TARGETS=("android arm64") ;;
    5) TARGETS=("darwin amd64") ;;
    6) TARGETS=("linux amd64" "linux arm64" "windows amd64" "android arm64" "darwin amd64") ;;
    *) echo "无效选择"; exit 1 ;;
esac

for target in "${TARGETS[@]}"; do
    os=$(echo $target | cut -d' ' -f1)
    arch=$(echo $target | cut -d' ' -f2)
    output="app-${os}-${arch}"
    [ "$os" = "windows" ] && output="${output}.exe"

    echo "开始编译: $os $arch"

    if [ "$os" = "android" ]; then
        # Android 直接 go build
        go build -o "$BUILD_DIR/$output"
    else
        # 其他平台
        CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" go build -o "$BUILD_DIR/$output"
    fi
done

echo "编译完成辣！文件在 ./build 目录："
ls -lh "$BUILD_DIR"
