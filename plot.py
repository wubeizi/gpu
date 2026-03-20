import matplotlib.pyplot as plt
import numpy as np

# 数据规模
scales = ['2^16', '2^18', '2^20', '2^22']

# 串行
cpu = np.array([1816, 13757, 81701, 553176])

# 并行 naive
gpu_naive = np.array([276, 462, 1385, 5230])

# frontier
gpu_frontier = np.array([247, 364, 1027, 4924])

# shared
gpu_shared = np.array([309, 456, 1138, 3754])

# warp
gpu_warp = np.array([251, 415, 667, 4183])

# 图1：执行时间柱状图
x = np.arange(len(scales))
width = 0.15

plt.figure()
plt.bar(x - 2*width, cpu, width, label='CPU')
plt.bar(x - width, gpu_naive, width, label='GPU_naive')
plt.bar(x, gpu_frontier, width, label='GPU_frontier')
plt.bar(x + width, gpu_shared, width, label='GPU_shared')
plt.bar(x + 2*width, gpu_warp, width, label='GPU_warp')

plt.xticks(x, scales)
plt.yscale('log')
plt.xlabel('Graph Scale')
plt.ylabel('Execution Time (us)')
plt.title('Execution Time Comparison')
plt.legend()
plt.show()
plt.savefig('execution_time_comparison.png')  # 保存图像

# 相对串行加速比
speedup_naive = cpu / gpu_naive
speedup_frontier = cpu / gpu_frontier
speedup_shared = cpu / gpu_shared
speedup_warp = cpu / gpu_warp

plt.figure()
plt.plot(scales, speedup_naive, marker='o', label='GPU_naive')
plt.plot(scales, speedup_frontier, marker='o', label='GPU_frontier')
plt.plot(scales, speedup_shared, marker='o', label='GPU_shared')
plt.plot(scales, speedup_warp, marker='o', label='GPU_warp')

plt.xlabel('Graph Scale')
plt.ylabel('Speedup over CPU')
plt.title('Speedup vs CPU')
plt.legend()
plt.grid()
plt.show()
plt.savefig('speedup_vs_cpu.png')  # 保存图像

# 相对 naive 并行加速比
speedup_frontier_vs_naive = gpu_naive / gpu_frontier
speedup_shared_vs_naive = gpu_naive / gpu_shared
speedup_warp_vs_naive = gpu_naive / gpu_warp

plt.figure()
plt.plot(scales, speedup_frontier_vs_naive, marker='o', label='Frontier / Naive')
plt.plot(scales, speedup_shared_vs_naive, marker='o', label='Shared / Naive')
plt.plot(scales, speedup_warp_vs_naive, marker='o', label='Warp / Naive')

plt.xlabel('Graph Scale')
plt.ylabel('Speedup over GPU_naive')
plt.title('Optimization Speedup vs Naive GPU')
plt.legend()
plt.grid()
plt.show()
plt.savefig('optimization_speedup_vs_naive.png')  # 保存图像