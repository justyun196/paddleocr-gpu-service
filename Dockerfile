FROM python:3.10-slim

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /code

# 复制依赖文件
COPY code/requirements.txt .

# 安装Python依赖（一次性安装）
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    numpy==1.24.3 \
    pillow==10.1.0 \
    opencv-python==4.8.1.78 \
    paddlepaddle==2.5.1 \
    paddleocr==2.7.0.3 \
    openpyxl==3.1.2 \
    oss2==2.18.1

# 验证安装
RUN python -c "import cv2; print('OpenCV:', cv2.__version__)" && \
    python -c "import paddle; print('PaddlePaddle:', paddle.__version__)" && \
    python -c "from paddleocr import PaddleOCR; print('PaddleOCR: OK')"

# 复制代码
COPY code/ /code/

# 创建测试脚本
RUN echo '#!/usr/bin/env python3' > /code/test.py && \
    echo 'import cv2' >> /code/test.py && \
    echo 'import paddle' >> /code/test.py && \
    echo 'from paddleocr import PaddleOCR' >> /code/test.py && \
    echo 'print("✅ 所有导入成功")' >> /code/test.py

EXPOSE 9000

# 启动测试脚本
CMD ["python", "/code/test.py"]