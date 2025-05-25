import cv2
import numpy as np
import sys


def test_opencv_cuda():
    """
    测试OpenCV的CUDA功能。
    """
    print("--- 正在验证OpenCV CUDA功能 ---")

    try:
        # 检查OpenCV是否已正确导入
        print(f"OpenCV version: {cv2.__version__}")

        # 检查是否有可用的CUDA设备
        if not cv2.cuda.getCudaEnabledDeviceCount():
            print("❌ 未找到CUDA设备。OpenCV CUDA模块可能未编译或不可用。")
            print(
                "请确保OpenCV在编译时启用了CUDA支持，并且您的CUDA驱动和工具包已正确安装。"
            )
            return False
        else:
            cuda_device_count = cv2.cuda.getCudaEnabledDeviceCount()
            print(f"✅ 找到 {cuda_device_count} 个CUDA设备。")
            print(f"当前CUDA设备: {cv2.cuda.getDevice()}")

            # 尝试创建GpuMat并进行简单的CUDA操作
            try:
                # 创建一个CPU上的NumPy数组
                mat_cpu = np.random.rand(100, 100).astype(np.float32)

                # 将数据上传到GPU
                mat_gpu = cv2.cuda_GpuMat()
                mat_gpu.upload(mat_cpu)

                print(f"✅ 成功创建并上传 GpuMat，类型: {mat_gpu.type()}")

                # 示例：在GPU上执行矩阵加法
                mat1_cpu = np.ones((5, 5), dtype=np.float32) * 2
                mat2_cpu = np.ones((5, 5), dtype=np.float32) * 3

                mat1_gpu = cv2.cuda_GpuMat()
                mat2_gpu = cv2.cuda_GpuMat()

                mat1_gpu.upload(mat1_cpu)
                mat2_gpu.upload(mat2_cpu)

                # 创建CUDA流
                stream = cv2.cuda.Stream()

                # 在GPU上执行加法
                result_gpu = cv2.cuda.add(mat1_gpu, mat2_gpu, stream=stream)
                stream.waitForCompletion()  # 等待CUDA操作完成

                # 将结果从GPU下载回CPU
                result_cpu = result_gpu.download()

                print("✅ CUDA矩阵加法成功。部分结果 (左上角):")
                print(result_cpu[0:2, 0:2])
                print(f"预期结果 (左上角): \n{np.ones((2,2)) * 5}")

                print("--- OpenCV CUDA功能验证成功！ ---")
                return True

            except Exception as e:
                print(f"❌ 在尝试CUDA操作时发生错误: {e}")
                print("这可能意味着虽然检测到CUDA设备，但实际的CUDA操作遇到了问题。")
                return False

    except ImportError:
        print("❌ 无法导入cv2模块。")
        print("请确保OpenCV已正确安装到您的Python环境中。")
        return False
    except Exception as e:
        print(f"❌ 发生未知错误: {e}")
        return False


if __name__ == "__main__":
    if test_opencv_cuda():
        sys.exit(0)  # 成功退出
    else:
        sys.exit(1)  # 失败退出
