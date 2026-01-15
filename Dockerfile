
FROM python:3.10-slim

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV DISABLE_MODEL_SOURCE_CHECK=True
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/code
ENV MKL_NUM_THREADS=1
ENV OMP_NUM_THREADS=1

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    libglib2.0-0 \
    libgthread-2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libfontconfig1 \
    libfreetype6 \
    libpango-1.0-0 \
    libcairo2 \
    libatlas-base-dev \
    liblapack-dev \
    gfortran \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 设置工作目录
WORKDIR /code

# 复制依赖文件
COPY code/requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制代码
COPY code/ /code/

# 设置环境变量
ENV PYTHONPATH=/code
ENV PYTHONUNBUFFERED=1

# 暴露端口
EXPOSE 9000

# 启动命令
CMD ["python", "server.py"]