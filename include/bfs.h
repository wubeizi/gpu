#pragma once
#include "graph.h"
#include <vector>

// CPU 串行 BFS
// 输入：CSR格式的图、起始节点
// 输出：每个节点的层次（level），未访问到的节点 level 为 -1
// 返回值：执行时间（微秒）
double bfs_cpu(const CSRGraph& graph, int source, std::vector<int>& level);

// ============================================================
// 以下是 GPU 版本的接口，供其他成员实现
// ============================================================

// GPU naive BFS（成员B实现）
double bfs_gpu_naive(const CSRGraph& graph, int source, std::vector<int>& level);

//GPU 优化一：前沿队列优化（成员C实现）
double bfs_gpu_frontier(const CSRGraph& graph, int source, std::vector<int>& level);

// GPU 优化二：方向优化（成员D实现）
// double bfs_gpu_direction(const CSRGraph& graph, int source, std::vector<int>& level);

// GPU 优化三：共享内存缓存（成员E实现）
double bfs_gpu_shared(const CSRGraph& graph, int source, std::vector<int>& level);
