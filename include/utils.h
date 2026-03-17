#pragma once
#include <cstdint>
#include <vector>
#include <string>

// ======================== 计时工具 ========================

// 获取当前时间（微秒）
uint64_t get_microseconds();

// 简单的计时器类
class Timer {
public:
    void start();
    void stop();
    double elapsed_us() const;   // 返回微秒
    double elapsed_ms() const;   // 返回毫秒
private:
    uint64_t t_start_ = 0;
    uint64_t t_end_ = 0;
};

// ======================== 正确性验证 ========================

// 比较两个 BFS 结果是否一致
// 返回 true 表示结果正确，false 表示有差异
// 如果有差异，会打印前 max_errors 个不匹配的位置
bool check_result(const std::vector<int>& reference, 
                  const std::vector<int>& result,
                  const std::string& version_name,
                  int max_errors = 10);

// ======================== 输出工具 ========================

// 打印性能结果
void print_performance(const std::string& version_name, 
                       double time_us, 
                       double cpu_time_us);
