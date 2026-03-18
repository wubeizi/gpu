#include "bfs.h"
#include "utils.h"
#include <cuda_runtime.h>
#include <iostream>

// CUDA Kernel: 使用显式 Frontier 队列的 BFS
__global__ void bfs_frontier_kernel(
    int num_nodes,
    const int* row_offsets,
    const int* col_indices,
    int* level,
    int current_level,
    bool* d_done,
    const int* frontier,
    int frontier_size,
    int* next_frontier,
    int* next_frontier_size)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;

    // 只遍历当前 frontier 队列中的节点，而不是扫描所有节点
    for (int idx = tid; idx < frontier_size; idx += stride) {
        int node = frontier[idx];

        int start_edge = row_offsets[node];
        int end_edge = row_offsets[node + 1];

        for (int i = start_edge; i < end_edge; i++) {
            int neighbor = col_indices[i];

            // 若 neighbor 尚未访问，则设置层号并加入下一层 frontier
            int old_val = atomicCAS(&level[neighbor], -1, current_level + 1);
            if (old_val == -1) {
                int pos = atomicAdd(next_frontier_size, 1);
                next_frontier[pos] = neighbor;
                *d_done = false;
            }
        }
    }
}

double bfs_gpu_frontier(const CSRGraph& graph, int source, std::vector<int>& level) {
    int num_nodes = graph.num_nodes;
    int num_edges = graph.num_edges;

    // 1. 分配设备内存
    int *d_row_offsets, *d_col_indices, *d_level;
    bool *d_done;

    // Frontier 队列
    int *d_frontier, *d_next_frontier;
    int *d_next_frontier_size;

    cudaMalloc(&d_row_offsets, (num_nodes + 1) * sizeof(int));
    cudaMalloc(&d_col_indices, num_edges * sizeof(int));
    cudaMalloc(&d_level, num_nodes * sizeof(int));
    cudaMalloc(&d_done, sizeof(bool));

    cudaMalloc(&d_frontier, num_nodes * sizeof(int));
    cudaMalloc(&d_next_frontier, num_nodes * sizeof(int));
    cudaMalloc(&d_next_frontier_size, sizeof(int));

    // 2. 将图数据拷贝到设备
    cudaMemcpy(d_row_offsets, graph.row_offsets.data(),
               (num_nodes + 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_col_indices, graph.col_indices.data(),
               num_edges * sizeof(int), cudaMemcpyHostToDevice);

    level[source] = 0;
    cudaMemcpy(d_level, level.data(), num_nodes * sizeof(int), cudaMemcpyHostToDevice);

    // 初始化 frontier：第一层只有 source
    cudaMemcpy(d_frontier, &source, sizeof(int), cudaMemcpyHostToDevice);
    int frontier_size = 1;

    // 3. 准备 CUDA 计时器
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    int threads_per_block = 256;
    // int blocks_per_grid = (num_nodes + threads_per_block - 1) / threads_per_block;
    int blocks_per_grid = 64;
    
    int current_level = 0;
    bool h_done = false;

    // --- 开始计时 ---
    cudaEventRecord(start);

    // 4. 执行 BFS 循环
    while (frontier_size > 0) {
        h_done = true;
        int zero = 0;

        cudaMemcpy(d_done, &h_done, sizeof(bool), cudaMemcpyHostToDevice);
        cudaMemcpy(d_next_frontier_size, &zero, sizeof(int), cudaMemcpyHostToDevice);


        bfs_frontier_kernel<<<blocks_per_grid, threads_per_block>>>(
            num_nodes,
            d_row_offsets,
            d_col_indices,
            d_level,
            current_level,
            d_done,
            d_frontier,
            frontier_size,
            d_next_frontier,
            d_next_frontier_size
        );

        // 读取下一层 frontier 的大小
        cudaMemcpy(&frontier_size, d_next_frontier_size, sizeof(int), cudaMemcpyDeviceToHost);

        // 交换当前 frontier 和下一层 frontier
        int* temp = d_frontier;
        d_frontier = d_next_frontier;
        d_next_frontier = temp;

        current_level++;
    }

    // --- 结束计时 ---
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);

    // 5. 将结果拷贝回主机
    cudaMemcpy(level.data(), d_level, num_nodes * sizeof(int), cudaMemcpyDeviceToHost);

    // 6. 释放设备内存
    cudaFree(d_row_offsets);
    cudaFree(d_col_indices);
    cudaFree(d_level);
    cudaFree(d_done);
    cudaFree(d_frontier);
    cudaFree(d_next_frontier);
    cudaFree(d_next_frontier_size);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    // 返回微秒(us)
    return milliseconds * 1000.0;
}