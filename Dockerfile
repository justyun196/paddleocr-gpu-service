# 使用 NVIDIA CUDA 基础镜像（包含CUDA环境）
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

WORKDIR /app

# 安装 Python 3.10
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 设置 Python 3.10 为默认
RUN ln -sf /usr/bin/python3.10 /usr/bin/python

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY . .

# 暴露端口
EXPOSE 9000

# 启动命令
CMD ["python", "app.py"]
