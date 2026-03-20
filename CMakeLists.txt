cmake_minimum_required(VERSION 3.16)
project(bfs_gpu LANGUAGES CXX CUDA)
# 后续加入 CUDA 时，改为: project(bfs_gpu LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 优化等级
set(CMAKE_CXX_FLAGS_RELEASE "-O2")

# 头文件目录
include_directories(${PROJECT_SOURCE_DIR}/include)

# ==================== 当前仅 CPU 版本 ====================
#add_executable(main
#    src/main.cpp
#    src/graph.cpp
#    src/bfs_cpu.cpp
#    src/utils.cpp
#)

# ==================== 后续加入 CUDA 版本 ====================
# 取消以下注释，并将 GPU 源文件加入：
#
# enable_language(CUDA)
# set(CMAKE_CUDA_STANDARD 17)
# set(CMAKE_CUDA_ARCHITECTURES 89)  # RTX 4090 用 89，根据你的显卡修改

set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -arch=sm_86 -std=c++17")
add_executable(main
    src/main.cpp
    src/graph.cpp
    src/bfs_cpu.cpp
    src/utils.cpp
    src/bfs_gpu_naive.cu       # 成员B
    src/bfs_gpu_frontier.cu    # 成员C
    src/bfs_gpu_shared.cu      # 成员D
    src/bfs_gpu_warp.cu      # 成员E
)

target_compile_options(main PRIVATE $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr>)
