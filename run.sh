#!/bin/bash
# 构建并运行 BFS 项目
# 用法:
#   ./run.sh                    # 默认: scale=20, random图
#   ./run.sh 18                 # scale=18, random图
#   ./run.sh 20 rmat            # scale=20, RMAT图
#   ./run.sh 20 random 16 0    # 完整参数

set -e

echo ">>> Building..."
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -1
make -j$(nproc) 2>&1 | tail -3
echo ""

echo ">>> Running BFS..."
echo ""
./main "$@"
