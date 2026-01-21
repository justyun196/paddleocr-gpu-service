
FROM python:3.10-slim

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV DISABLE_MODEL_SOURCE_CHECK=True
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/code
ENV MKL_NUM_THREADS=1
ENV OMP_NUM_THREADS=1
# 在 Dockerfile 中添加
ENV FLAGS_use_mkldnn=false
ENV FLAGS_use_cudnn=false
ENV GLOG_v=2
ENV PADDLE_LOG_LEVEL=ERROR
ENV DISABLE_MODEL_SOURCE_CHECK=True
ENV PADDLE_DOWNLOAD_PROGRESS=0
# 在 Dockerfile 中添加
ENV FLAGS_enable_pir=false
ENV FLAGS_print_ir=false
ENV FLAGS_graphviz_path=
ENV FLAGS_check_nan_inf=false
# 在 Dockerfile 中添加
ENV FLAGS_logging_level=3
ENV GLOG_minloglevel=3
ENV FLAGS_benchmark=false
ENV FLAGS_summary=false
ENV FLAGS_detailed_error_msg=false

# 1. 更新源并安装必要依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    # OpenGL库
    libgl1 \
    libglx-mesa0 \
    libglib2.0-0 \
    # OpenMP支持（PaddlePaddle需要）
    libgomp1 \
    # X11相关
    libsm6 \
    libxext6 \
    libxrender1 \
    # 字体
    libfontconfig1 \
    libfreetype6 \
    # 工具
    wget \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 2. 验证安装
RUN echo "=== 已安装的OpenGL相关包 ===" && \
    dpkg -l | grep -E "(libgl|mesa|opengl)" && \
    echo "" && \
    echo "=== libGL.so.1 文件位置 ===" && \
    find /usr -name "libGL.so.1*" 2>/dev/null || echo "未找到libGL.so.1"

# 设置工作目录
WORKDIR /code

# 复制依赖文件
COPY code/requirements.txt .

# 3. 安装Python依赖（分步安装，便于调试）
RUN pip install --no-cache-dir --upgrade pip

# 先安装基础依赖
RUN pip install --no-cache-dir \
    numpy \
    pillow

# 安装OpenCV（完整版，不是headless）
RUN pip install --no-cache-dir \
    opencv-python

# 安装PaddlePaddle
RUN pip install --no-cache-dir \
    paddlepaddle

# 安装PaddleOCR
RUN pip install --no-cache-dir \
    paddleocr

## 安装其他依赖
RUN pip install --no-cache-dir \
    openpyxl \
    oss2 \
    shapely \
    scipy

# 创建 libGL.so.1 符号链接
RUN ln -sf /usr/lib/x86_64-linux-gnu/libGL.so.1 /usr/lib/libGL.so.1 2>/dev/null || \
    ln -sf /usr/lib/x86_64-linux-gnu/libGL.so.1.0 /usr/lib/libGL.so.1 2>/dev/null || \
    ln -sf /usr/lib/x86_64-linux-gnu/mesa/libGL.so.1 /usr/lib/libGL.so.1 2>/dev/null || \
    echo "Warning: Could not create libGL.so.1 symlink"

# 复制代码4. 验证环境
# 验证关键包是否安装成功
RUN python -c "import cv2; print('OpenCV OK')"
RUN python -c "import paddle; print('PaddlePaddle OK')"
RUN python -c "import paddleocr; print('PaddleOCR OK')"

# 复制代码
COPY code/ /code/

# 暴露端口
EXPOSE 9000

# 启动命令
CMD ["python", "server.py"]