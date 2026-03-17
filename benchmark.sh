#!/bin/bash
set -e

echo ">>> Building..."
mkdir -p build
g++ -std=c++17 -O2 -I include src/main.cpp src/graph.cpp src/bfs_cpu.cpp src/utils.cpp -o build/main
echo "Build success!"
echo ""

SCALES="16 18 20 22"

echo "============================================================"
echo "  BFS CPU Serial Benchmark (Random Graph)"
echo "============================================================"
echo ""

for scale in $SCALES; do
    ./build/main $scale
    echo ""
done

echo "============================================================"
echo "  Benchmark completed!"
echo "============================================================"