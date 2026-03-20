#include "bfs.h"
#include "utils.h"
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

#define THREADS_PER_BLOCK 256
#define WARP_SIZE 32   // 一个 warp = 32 个线程

// Warp-Centric BFS：一个 warp 处理一个节点
__global__ void bfs_warp_kernel(
    const int* frontier,       // 当前层 frontier 队列
    int frontier_size,         // frontier 大小
    const int* row_offsets,    // CSR 行偏移
    const int* col_indices,    // CSR 邻接表
    int* level,                // BFS 层级数组
    int current_level,         // 当前层数
    int* next_frontier,        // 下一层 frontier
    int* next_size)            // 下一层大小（全局计数器）
{
    int global_tid = blockIdx.x * blockDim.x + threadIdx.x;

    // Warp 划分
    int warp_id = global_tid / WARP_SIZE;   // 每个 warp 对应一个节点
    int lane = threadIdx.x % WARP_SIZE;     // warp 内线程编号 [0,31]

    if (warp_id >= frontier_size) return;

    int u = frontier[warp_id];

    int start = row_offsets[u];
    int end = row_offsets[u + 1];

    // Warp 内协作遍历邻居
    // 每个线程处理一部分边（stride = WARP_SIZE）
    for (int i = start + lane; i < end; i += WARP_SIZE) {
        int v = col_indices[i];

        // 原子更新，保证只访问一次
        if (atomicCAS(&level[v], -1, current_level + 1) == -1) {
            int pos = atomicAdd(next_size, 1);
            next_frontier[pos] = v;
        }
    }
}

// Host 函数
double bfs_gpu_warp(const CSRGraph& graph, int source, std::vector<int>& level)
{
    int n = graph.num_nodes;
    int m = graph.num_edges;

    // 设备内存
    int *d_row_offsets, *d_col_indices, *d_level;
    int *d_frontier, *d_next_frontier;
    int *d_frontier_size, *d_next_size;

    cudaMalloc(&d_row_offsets, (n + 1) * sizeof(int));
    cudaMalloc(&d_col_indices, m * sizeof(int));
    cudaMalloc(&d_level, n * sizeof(int));
    cudaMalloc(&d_frontier, n * sizeof(int));
    cudaMalloc(&d_next_frontier, n * sizeof(int));
    cudaMalloc(&d_frontier_size, sizeof(int));
    cudaMalloc(&d_next_size, sizeof(int));

    // 初始化
    std::vector<int> h_level(n, -1);
    h_level[source] = 0;

    cudaMemcpy(d_row_offsets, graph.row_offsets.data(), (n + 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_col_indices, graph.col_indices.data(), m * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_level, h_level.data(), n * sizeof(int), cudaMemcpyHostToDevice);

    // 初始 frontier
    int h_frontier_size = 1;
    cudaMemcpy(d_frontier, &source, sizeof(int), cudaMemcpyHostToDevice);

    Timer timer;
    timer.start();

    int current_level = 0;

    // BFS
    while (h_frontier_size > 0) {

        // 初始化下一层 frontier
        int h_next_size = 0;
        cudaMemcpy(d_next_size, &h_next_size, sizeof(int), cudaMemcpyHostToDevice);

        // Warp 级调度
        // 每个节点对应一个 warp
        int num_warps = h_frontier_size;
        int num_threads = num_warps * WARP_SIZE;

        int blocks = (num_threads + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

        bfs_warp_kernel<<<blocks, THREADS_PER_BLOCK>>>(
            d_frontier,
            h_frontier_size,
            d_row_offsets,
            d_col_indices,
            d_level,
            current_level,
            d_next_frontier,
            d_next_size
        );

        // 获取下一层 frontier 大小
        cudaMemcpy(&h_frontier_size, d_next_size, sizeof(int), cudaMemcpyDeviceToHost);

        // frontier 交换（滚动队列）
        std::swap(d_frontier, d_next_frontier);

        current_level++;
    }

    cudaDeviceSynchronize();
    timer.stop();

    // 拷贝结果
    cudaMemcpy(level.data(), d_level, n * sizeof(int), cudaMemcpyDeviceToHost);

    // 释放内存
    cudaFree(d_row_offsets);
    cudaFree(d_col_indices);
    cudaFree(d_level);
    cudaFree(d_frontier);
    cudaFree(d_next_frontier);
    cudaFree(d_frontier_size);
    cudaFree(d_next_size);

    return timer.elapsed_us();
}