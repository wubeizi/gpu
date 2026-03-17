#include "utils.h"
#include <sys/time.h>
#include <iostream>
#include <iomanip>

// ======================== 计时工具 ========================

uint64_t get_microseconds() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000000ULL + (uint64_t)tv.tv_usec;
}

void Timer::start() {
    t_start_ = get_microseconds();
}

void Timer::stop() {
    t_end_ = get_microseconds();
}

double Timer::elapsed_us() const {
    return (double)(t_end_ - t_start_);
}

double Timer::elapsed_ms() const {
    return (double)(t_end_ - t_start_) / 1000.0;
}

// ======================== 正确性验证 ========================

bool check_result(const std::vector<int>& reference,
                  const std::vector<int>& result,
                  const std::string& version_name,
                  int max_errors) {
    if (reference.size() != result.size()) {
        std::cout << "[" << version_name << "] FAILED: size mismatch ("
                  << reference.size() << " vs " << result.size() << ")" << std::endl;
        return false;
    }

    int error_count = 0;
    int n = (int)reference.size();

    for (int i = 0; i < n; i++) {
        if (reference[i] != result[i]) {
            if (error_count < max_errors) {
                std::cout << "[" << version_name << "] Mismatch at node " << i
                          << ": expected " << reference[i]
                          << ", got " << result[i] << std::endl;
            }
            error_count++;
        }
    }

    if (error_count == 0) {
        std::cout << "[" << version_name << "] Check result success!" << std::endl;
        return true;
    } else {
        std::cout << "[" << version_name << "] FAILED: " << error_count 
                  << " / " << n << " nodes mismatch" << std::endl;
        return false;
    }
}

// ======================== 输出工具 ========================

void print_performance(const std::string& version_name,
                       double time_us,
                       double cpu_time_us) {
    std::cout << version_name << " Execution Time elapsed " 
              << std::fixed << std::setprecision(0) << time_us << " us" << std::endl;
    if (cpu_time_us > 0) {
        std::cout << version_name << " speed up " 
                  << std::fixed << std::setprecision(3) << (cpu_time_us / time_us) 
                  << "X" << std::endl;
    }
}
