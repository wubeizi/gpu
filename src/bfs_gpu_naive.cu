#include "bfs.h"
#include "utils.h"
#include <cuda_runtime.h>
#include <iostream>


// CUDA Kernel: 朴素拓扑驱动 (带 Grid-Stride 限流的降速版)
__global__ void bfs_naive_kernel(
    int num_nodes,
    const int* row_offsets,
    const int* col_indices,
    int* level,
    int current_level,
    bool* d_done) 
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x; // 获取所有线程的总数
    
    // 【核心修复】：必须把 if 换成 for 循环！
    // 线程不仅处理 tid，还要处理 tid + stride, tid + 2*stride... 直到覆盖所有节点
    for (int node = tid; node < num_nodes; node += stride) {
        // 如果当前节点属于当前正在前推的层 (Frontier)
        if (level[node] == current_level) {
            int start_edge = row_offsets[node];
            int end_edge = row_offsets[node + 1];
            
            // 遍历所有邻居节点
            for (int i = start_edge; i < end_edge; i++) {
                int neighbor = col_indices[i];
                
                // 使用 atomicCAS 避免写入冲突
                int old_val = atomicCAS(&level[neighbor], -1, current_level + 1);
                if (old_val == -1) {
                    *d_done = false;
                }
            }
        }
    }
}


// CUDA Kernel: 朴素拓扑驱动
//__global__ void bfs_naive_kernel(
//    int num_nodes,
//   const int* row_offsets,
//    const int* col_indices,
//    int* level,
//    int current_level,
//    bool* d_done) 
//{
//    int tid = blockIdx.x * blockDim.x + threadIdx.x;
//    
//    // 确保线程没有越界
//    if (tid < num_nodes) {
//        // 如果当前节点属于当前正在前推的层 (Frontier)
//        if (level[tid] == current_level) {
//            int start_edge = row_offsets[tid];
//            int end_edge = row_offsets[tid + 1];
//            
//            // 遍历所有邻居节点
//            for (int i = start_edge; i < end_edge; i++) {
//                int neighbor = col_indices[i];
//                
//                // 如果邻居尚未被访问过（假设 -1 表示未访问）
//                // 使用 atomicCAS (Compare And Swap) 避免多线程同时访问同一个未访问邻居时的写入冲突
//                int old_val = atomicCAS(&level[neighbor], -1, current_level + 1);
//                if (old_val == -1) {
//                   // 只要有至少一个节点被更新，说明图还没遍历完
//                    *d_done = false;
//                }
//            }
//        }
//    }
//}

double bfs_gpu_naive(const CSRGraph& graph, int source, std::vector<int>& level) {
    int num_nodes = graph.num_nodes;
    int num_edges = graph.num_edges;

    // 1. 分配设备内存
    int *d_row_offsets, *d_col_indices, *d_level;
    bool *d_done;
    
    cudaMalloc(&d_row_offsets, (num_nodes + 1) * sizeof(int));
    cudaMalloc(&d_col_indices, num_edges * sizeof(int));
    cudaMalloc(&d_level, num_nodes * sizeof(int));
    cudaMalloc(&d_done, sizeof(bool));

    // 2. 将图数据拷贝到设备
    cudaMemcpy(d_row_offsets, graph.row_offsets.data(), (num_nodes + 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_col_indices, graph.col_indices.data(), num_edges * sizeof(int), cudaMemcpyHostToDevice);
    level[source] = 0;
    // 初始化设备端的 level 数组（通常外部传入的 level 已经将 source 设为 0，其余为 -1）
    cudaMemcpy(d_level, level.data(), num_nodes * sizeof(int), cudaMemcpyHostToDevice);

    // 3. 准备 CUDA 计时器
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    // 线程块和网格配置
    int threads_per_block = 256;
    // int blocks_per_grid = (num_nodes + threads_per_block - 1) / threads_per_block;
    int blocks_per_grid = 64;

    int current_level = 0;
    bool h_done = false;

    // --- 开始计时 ---
    cudaEventRecord(start);

    // 4. 执行 BFS 循环
    while (!h_done) {
        h_done = true; // 假设这是最后一层
        cudaMemcpy(d_done, &h_done, sizeof(bool), cudaMemcpyHostToDevice);

        bfs_naive_kernel<<<blocks_per_grid, threads_per_block>>>(
            num_nodes, d_row_offsets, d_col_indices, d_level, current_level, d_done
        );

        // 同步并检查是否还有新节点被访问
        cudaMemcpy(&h_done, d_done, sizeof(bool), cudaMemcpyDeviceToHost);
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
    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    // 返回微秒 (us)
    return milliseconds * 1000.0;
}