#include "graph.h"
#include "bfs.h"
#include "utils.h"
#include <iostream>
#include <cstdlib>
#include <string>

int main(int argc, char* argv[]) {
    // 默认参数
    int scale = 20;             // 节点数 = 2^scale
    int avg_degree = 16;        // 平均度数
    int source = 0;             // BFS 起始节点

    // 命令行参数解析
    // 用法: ./main [scale] [avg_degree] [source]
    // 示例: ./main 20 16 0
    if (argc >= 2) scale = std::atoi(argv[1]);
    if (argc >= 3) avg_degree = std::atoi(argv[2]);
    if (argc >= 4) source = std::atoi(argv[3]);

    int num_nodes = 1 << scale;

    std::cout << "========================================" << std::endl;
    std::cout << "  BFS GPU Parallel Programming Project" << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << "Scale:      " << scale << " (2^" << scale << " = " << num_nodes << " nodes)" << std::endl;
    std::cout << "Avg degree: " << avg_degree << std::endl;
    std::cout << "Source:     " << source << std::endl;
    std::cout << std::endl;

    // ===================== 加载或生成图 =====================
    std::string graph_file = "graph_random_" + std::to_string(scale) 
                             + "_d" + std::to_string(avg_degree) + ".bin";

    CSRGraph graph;
    if (load_graph(graph, graph_file)) {
        print_graph_info(graph, "random (loaded from file)");
    } else {
        std::cout << "Graph file not found, generating..." << std::endl;
        Timer gen_timer;
        gen_timer.start();

        graph = generate_random_graph(num_nodes, avg_degree);

        gen_timer.stop();
        std::cout << "Graph generated in " << gen_timer.elapsed_ms() << " ms" << std::endl;
        print_graph_info(graph, "random");

        save_graph(graph, graph_file);
    }

    // 确保 source 合法
    if (source < 0 || source >= graph.num_nodes) {
        std::cerr << "Error: source node " << source << " out of range [0, " 
                  << graph.num_nodes - 1 << "]" << std::endl;
        return 1;
    }

    // ===================== CPU 串行 BFS =====================
    std::vector<int> cpu_level;
    double cpu_time = bfs_cpu(graph, source, cpu_level);

    // 统计 BFS 结果信息
    int visited = 0;
    int max_level = 0;
    for (int i = 0; i < graph.num_nodes; i++) {
        if (cpu_level[i] >= 0) {
            visited++;
            if (cpu_level[i] > max_level) max_level = cpu_level[i];
        }
    }

    print_performance("CPU_serial", cpu_time, 0);
    std::cout << "  Visited nodes: " << visited << " / " << graph.num_nodes 
              << " (" << (100.0 * visited / graph.num_nodes) << "%)" << std::endl;
    std::cout << "  Max level:     " << max_level << std::endl;
    std::cout << std::endl;

    // ===================== GPU 版本测试 =====================
    // 其他成员在此处添加自己的 GPU 版本测试
    // 模板如下：
    std::vector<int> level_gpu_naive(graph.num_nodes, -1);
    level_gpu_naive[source] = 0;
    
    // 调用 GPU 版本
    double time_gpu_naive = bfs_gpu_naive(graph, source, level_gpu_naive);
    
    print_performance("GPU_naive", time_gpu_naive, cpu_time);
    check_result(cpu_level, level_gpu_naive, "GPU_naive");
    std::cout << std::endl;


    //
    // std::vector<int> gpu_level_v2;
    // double gpu_time_v2 = bfs_gpu_frontier(graph, source, gpu_level_v2);
    // print_performance("GPU_frontier", gpu_time_v2, cpu_time);
    // check_result(cpu_level, gpu_level_v2, "GPU_frontier");
    // std::cout << std::endl;
    //
    // std::vector<int> gpu_level_v3;
    // double gpu_time_v3 = bfs_gpu_direction(graph, source, gpu_level_v3);
    // print_performance("GPU_direction", gpu_time_v3, cpu_time);
    // check_result(cpu_level, gpu_level_v3, "GPU_direction");
    // std::cout << std::endl;
    //
    // std::vector<int> gpu_level_v4;
    // double gpu_time_v4 = bfs_gpu_shared(graph, source, gpu_level_v4);
    // print_performance("GPU_shared", gpu_time_v4, cpu_time);
    // check_result(cpu_level, gpu_level_v4, "GPU_shared");
    // std::cout << std::endl;
    std::vector<int> level_gpu_shared(graph.num_nodes, -1);
    level_gpu_shared[source] = 0;
    double time_gpu_shared = bfs_gpu_shared(graph, source, level_gpu_shared);
    print_performance("GPU_shared", time_gpu_shared, cpu_time);
    check_result(cpu_level, level_gpu_shared, "GPU_shared");


    std::cout << "========================================" << std::endl;
    std::cout << "  All tests completed." << std::endl;
    std::cout << "========================================" << std::endl;

    return 0;
}