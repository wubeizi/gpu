#include "graph.h"
#include <algorithm>
#include <random>
#include <set>
#include <iostream>
#include <cmath>

CSRGraph generate_random_graph(int num_nodes, int avg_degree, unsigned int seed) {
    std::mt19937 rng(seed);
    // 每个节点大约 avg_degree 条边，总边数（无向图，每条边存两次）
    long long target_edges = (long long)num_nodes * avg_degree;

    // 用 set 去重，存储有向边（无向图存两个方向）
    std::vector<std::set<int>> adj(num_nodes);
    std::uniform_int_distribution<int> dist(0, num_nodes - 1);

    long long edges_added = 0;
    while (edges_added < target_edges) {
        int u = dist(rng);
        int v = dist(rng);
        if (u != v && adj[u].find(v) == adj[u].end()) {
            adj[u].insert(v);
            adj[v].insert(u);
            edges_added += 2;
        }
    }

    // 转换为 CSR 格式
    CSRGraph graph;
    graph.num_nodes = num_nodes;
    graph.row_offsets.resize(num_nodes + 1);

    // 计算每个节点的度数
    graph.row_offsets[0] = 0;
    for (int i = 0; i < num_nodes; i++) {
        graph.row_offsets[i + 1] = graph.row_offsets[i] + (int)adj[i].size();
    }

    graph.num_edges = graph.row_offsets[num_nodes];
    graph.col_indices.resize(graph.num_edges);

    // 填充邻居列表
    for (int i = 0; i < num_nodes; i++) {
        int offset = graph.row_offsets[i];
        for (int neighbor : adj[i]) {
            graph.col_indices[offset++] = neighbor;
        }
    }

    return graph;
}



void print_graph_info(const CSRGraph& graph, const std::string& name) {
    // 计算度数统计
    int max_degree = 0;
    long long total_degree = 0;
    for (int i = 0; i < graph.num_nodes; i++) {
        int degree = graph.row_offsets[i + 1] - graph.row_offsets[i];
        max_degree = std::max(max_degree, degree);
        total_degree += degree;
    }
    double avg_degree = (double)total_degree / graph.num_nodes;

    std::cout << "=== Graph: " << name << " ===" << std::endl;
    std::cout << "  Nodes:      " << graph.num_nodes << std::endl;
    std::cout << "  Edges:      " << graph.num_edges << " (directed, i.e. " 
              << graph.num_edges / 2 << " undirected)" << std::endl;
    std::cout << "  Avg degree: " << avg_degree << std::endl;
    std::cout << "  Max degree: " << max_degree << std::endl;
    std::cout << "  Memory:     " 
              << (graph.row_offsets.size() * sizeof(int) + graph.col_indices.size() * sizeof(int)) / (1024.0 * 1024.0)
              << " MB" << std::endl;
    std::cout << std::endl;
}

bool save_graph(const CSRGraph& graph, const std::string& filename) {
    FILE* fp = fopen(filename.c_str(), "wb");
    if (!fp) {
        std::cerr << "Error: cannot open file " << filename << " for writing" << std::endl;
        return false;
    }

    // 写入 num_nodes 和 num_edges
    fwrite(&graph.num_nodes, sizeof(int), 1, fp);
    fwrite(&graph.num_edges, sizeof(int), 1, fp);

    // 写入 row_offsets 数组（num_nodes + 1 个 int）
    fwrite(graph.row_offsets.data(), sizeof(int), graph.num_nodes + 1, fp);

    // 写入 col_indices 数组（num_edges 个 int）
    fwrite(graph.col_indices.data(), sizeof(int), graph.num_edges, fp);

    fclose(fp);

    // 计算文件大小
    double file_mb = ((2 + graph.num_nodes + 1 + graph.num_edges) * sizeof(int)) / (1024.0 * 1024.0);
    std::cout << "Graph saved to " << filename << " (" << file_mb << " MB)" << std::endl;
    return true;
}

bool load_graph(CSRGraph& graph, const std::string& filename) {
    FILE* fp = fopen(filename.c_str(), "rb");
    if (!fp) {
        return false;  // 文件不存在，不打印错误（属于正常情况，需要生成图）
    }

    // 读取 num_nodes 和 num_edges
    if (fread(&graph.num_nodes, sizeof(int), 1, fp) != 1 ||
        fread(&graph.num_edges, sizeof(int), 1, fp) != 1) {
        fclose(fp);
        return false;
    }

    // 读取 row_offsets
    graph.row_offsets.resize(graph.num_nodes + 1);
    if (fread(graph.row_offsets.data(), sizeof(int), graph.num_nodes + 1, fp) != (size_t)(graph.num_nodes + 1)) {
        fclose(fp);
        return false;
    }

    // 读取 col_indices
    graph.col_indices.resize(graph.num_edges);
    if (fread(graph.col_indices.data(), sizeof(int), graph.num_edges, fp) != (size_t)graph.num_edges) {
        fclose(fp);
        return false;
    }

    fclose(fp);

    double file_mb = ((2 + graph.num_nodes + 1 + graph.num_edges) * sizeof(int)) / (1024.0 * 1024.0);
    std::cout << "Graph loaded from " << filename << " (" << file_mb << " MB)" << std::endl;
    return true;
}
