
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
    # OpenGL库
    libgl1 \
    libglx-mesa0 \
    libglib2.0-0 \
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
    numpy==1.24.3 \
    pillow==10.1.0

# 安装OpenCV（完整版，不是headless）
RUN pip install --no-cache-dir \
    opencv-python==4.8.1.78

# 安装PaddlePaddle
RUN pip install --no-cache-dir \
    paddlepaddle

# 安装PaddleOCR
RUN pip install --no-cache-dir \
    paddleocr

# 安装其他依赖
RUN pip install --no-cache-dir \
    openpyxl==3.1.2 \
    oss2==2.18.1 \
    shapely==2.0.2 \
    scipy==1.11.4

# 4. 验证环境
RUN python -c "import cv2; print(f'OpenCV: {cv2.__version__}'); import numpy as np; print(f'NumPy: {np.__version__}'); import paddle; print(f'PaddlePaddle: {paddle.__version__}'); from paddleocr import PaddleOCR; print('PaddleOCR: OK')"

# 复制代码
COPY code/ /code/

# 暴露端口
EXPOSE 9000

# 启动命令
CMD ["python", "server.py"]