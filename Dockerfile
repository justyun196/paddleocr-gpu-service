
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# 安装 Python 和系统依赖
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    libgomp1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgl1 \
    libpango-1.0-0 \
    libcairo2 \
    wget \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# 设置工作目录
WORKDIR /code

# 复制依赖文件
COPY code/requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 预加载模型（首次启动时下载）
RUN python -c "from paddleocr import PaddleOCRVL; PaddleOCRVL(device='gpu', precision='fp16', enable_mkldnn=False, vl_rec_model_name='PaddleOCR-VL-0.9B', use_layout_detection=False)" || echo "模型预加载完成"

# 复制代码
COPY code/ /code/

# 设置环境变量
ENV PYTHONPATH=/code
ENV PYTHONUNBUFFERED=1

# 暴露端口
EXPOSE 9000

# 启动命令
CMD ["python", "server.py"]