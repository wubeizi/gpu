#include "bfs.h"
#include "utils.h"
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#define THREADS_PER_BLOCK 256
#define LOCAL_QUEUE_SIZE 512  // 共享内存缓冲区大小

// 使用共享内存加速的 BFS Kernel
__global__ void bfs_shared_kernel(
    int num_nodes,
    const int* row_offsets,
    const int* col_indices,
    int* level,
    int current_level,
    int* global_queue_next,
    int* global_queue_size,
    bool* d_changed) 
{
    // 1. 声明共享内存：局部队列和局部计数器
    __shared__ int local_queue[LOCAL_QUEUE_SIZE];
    __shared__ int local_cnt;

    if (threadIdx.x == 0) local_cnt = 0;
    __syncthreads();

    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid < num_nodes && level[tid] == current_level) {
        int start = row_offsets[tid];
        int end = row_offsets[tid + 1];

        for (int i = start; i < end; i++) {
            int neighbor = col_indices[i];

            // 尝试更新邻居，atomicCAS 确保只有一个线程负责将该邻居入队
            if (atomicCAS(&level[neighbor], -1, current_level + 1) == -1) {
                *d_changed = true;
                
                // 2. 局部入队：先尝试放入 Shared Memory
                int pos = atomicAdd(&local_cnt, 1);
                if (pos < LOCAL_QUEUE_SIZE) {
                    local_queue[pos] = neighbor;
                } else {
                    // 如果共享内存溢出，直接写入全局显存队列
                    int g_pos = atomicAdd(global_queue_size, 1);
                    global_queue_next[g_pos] = neighbor;
                }
            }
        }
    }
    __syncthreads();

    // 3. 批量写回：将共享内存中的数据一次性合并写入全局显存
    if (threadIdx.x == 0) {
        int num_to_write = (local_cnt > LOCAL_QUEUE_SIZE) ? LOCAL_QUEUE_SIZE : local_cnt;
        if (num_to_write > 0) {
            int global_start = atomicAdd(global_queue_size, num_to_write);
            for (int i = 0; i < num_to_write; i++) {
                global_queue_next[global_start + i] = local_queue[i];
            }
        }
    }
}

double bfs_gpu_shared(const CSRGraph& graph, int source, std::vector<int>& level) {
    int n = graph.num_nodes;
    int m = graph.num_edges;

    // 分配设备内存
    int *d_row_offsets, *d_col_indices, *d_level, *d_queue_next, *d_queue_size;
    bool *d_changed, h_changed;

    cudaMalloc(&d_row_offsets, (n + 1) * sizeof(int));
    cudaMalloc(&d_col_indices, m * sizeof(int));
    cudaMalloc(&d_level, n * sizeof(int));
    cudaMalloc(&d_queue_next, n * sizeof(int)); // 辅助队列
    cudaMalloc(&d_queue_size, sizeof(int));
    cudaMalloc(&d_changed, sizeof(bool));

    // 初始化数据
    std::vector<int> h_level(n, -1);
    h_level[source] = 0;

    cudaMemcpy(d_row_offsets, graph.row_offsets.data(), (n + 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_col_indices, graph.col_indices.data(), m * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_level, h_level.data(), n * sizeof(int), cudaMemcpyHostToDevice);

    Timer timer;
    timer.start();

    int current_level = 0;
    int blocks = (n + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

    while (true) {
        h_changed = false;
        cudaMemcpy(d_changed, &h_changed, sizeof(bool), cudaMemcpyHostToDevice);
        
        // 每一层重置队列计数（虽然此朴素 shared 版仍扫描全量，但已为 Frontier 模式做准备）
        int h_queue_size = 0;
        cudaMemcpy(d_queue_size, &h_queue_size, sizeof(int), cudaMemcpyHostToDevice);

        bfs_shared_kernel<<<blocks, THREADS_PER_BLOCK>>>(
            n, d_row_offsets, d_col_indices, d_level, 
            current_level, d_queue_next, d_queue_size, d_changed
        );

        cudaMemcpy(&h_changed, d_changed, sizeof(bool), cudaMemcpyDeviceToHost);
        if (!h_changed) break;
        current_level++;
    }

    cudaDeviceSynchronize();
    timer.stop();

    // 拷贝结果回主机
    cudaMemcpy(level.data(), d_level, n * sizeof(int), cudaMemcpyDeviceToHost);

    // 释放内存
    cudaFree(d_row_offsets);
    cudaFree(d_col_indices);
    cudaFree(d_level);
    cudaFree(d_queue_next);
    cudaFree(d_queue_size);
    cudaFree(d_changed);

    return timer.elapsed_us();
}