
FROM ubuntu:20.04

# 安装 Python 3.10 和系统依赖
RUN DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3.10 \
    python3.10-dev \
    python3.10-distutils \
    wget \
    && wget https://bootstrap.pypa.io/get-pip.py \
    && python3.10 get-pip.py \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libgomp1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgl1 \
    libgl1-mesa-glx \
    libfontconfig1 \
    libfreetype6 \
    libx11-6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxcursor1 \
    libxinerama1 \
    libpango-1.0-0 \
    libcairo2 \
    libgdk-pixbuf2.0-0 \
    libgtk-3-0 \
    libatlas-base-dev \
    liblapack-dev \
    gfortran \
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

# 复制代码
COPY code/ /code/

# 设置环境变量
ENV PYTHONPATH=/code
ENV PYTHONUNBUFFERED=1

# 暴露端口
EXPOSE 9000

# 启动命令
CMD ["python", "server.py"]