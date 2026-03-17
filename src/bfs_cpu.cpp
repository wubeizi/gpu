#include "bfs.h"
#include "utils.h"
#include <queue>

double bfs_cpu(const CSRGraph& graph, int source, std::vector<int>& level) {
    int n = graph.num_nodes;
    
    // 初始化：所有节点 level = -1（未访问）
    level.assign(n, -1);
    
    // 起始节点 level = 0
    level[source] = 0;
    
    // BFS 队列
    std::queue<int> q;
    q.push(source);

    Timer timer;
    timer.start();

    while (!q.empty()) {
        int node = q.front();
        q.pop();

        // 遍历当前节点的所有邻居
        int start = graph.row_offsets[node];
        int end   = graph.row_offsets[node + 1];

        for (int i = start; i < end; i++) {
            int neighbor = graph.col_indices[i];
            // 如果邻居未被访问，标记其层次并加入队列
            if (level[neighbor] == -1) {
                level[neighbor] = level[node] + 1;
                q.push(neighbor);
            }
        }
    }

    timer.stop();
    return timer.elapsed_us();
}
