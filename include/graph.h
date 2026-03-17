#pragma once
#include <cstdint>
#include <vector>
#include <string>

// CSR (Compressed Sparse Row) 格式存储图
struct CSRGraph {
    int num_nodes;          // 节点数
    int num_edges;          // 边数（无向图中每条边存两次）
    std::vector<int> row_offsets;   // 大小为 num_nodes + 1，row_offsets[i] 到 row_offsets[i+1] 是节点 i 的邻居在 col_indices 中的范围
    std::vector<int> col_indices;   // 大小为 num_edges，存储所有邻居节点编号
};

// 生成随机图（Erdos-Renyi 模型）
// 每个节点平均有 avg_degree 个邻居，节点度数分布比较均匀
CSRGraph generate_random_graph(int num_nodes, int avg_degree, unsigned int seed = 42);


// 打印图的基本信息
void print_graph_info(const CSRGraph& graph, const std::string& name);

// 保存图到二进制文件
bool save_graph(const CSRGraph& graph, const std::string& filename);

// 从二进制文件读取图
bool load_graph(CSRGraph& graph, const std::string& filename);
