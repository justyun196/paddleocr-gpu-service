
FROM python:3.10-slim

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV DISABLE_MODEL_SOURCE_CHECK=True
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/code
ENV MKL_NUM_THREADS=1
ENV OMP_NUM_THREADS=1

# 1. 更新源并安装必要依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 完整的Mesa图形栈
    libgl1 \
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    libglapi-mesa \
    libglx-mesa0 \
    mesa-utils \
    # 其他依赖
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

# 2. 创建必要的符号链接
RUN mkdir -p /usr/lib/x86_64-linux-gnu/mesa && \
    ln -sf /usr/lib/x86_64-linux-gnu/libGL.so.1 /usr/lib/libGL.so.1 2>/dev/null || true && \
    ln -sf /usr/lib/x86_64-linux-gnu/libGL.so.1 /usr/lib/x86_64-linux-gnu/mesa/libGL.so.1 2>/dev/null || true && \
    ln -sf /usr/lib/x86_64-linux-gnu/libGL.so.1.0 /usr/lib/libGL.so.1 2>/dev/null || true && \
    echo "符号链接创建完成"

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

# 安装其他依赖
RUN pip install --no-cache-dir \
    openpyxl \
    oss2 \
    shapely \
    scipy

# 复制代码
COPY code/ /code/

# 暴露端口
EXPOSE 9000

# 启动命令
CMD ["python", "server.py"]