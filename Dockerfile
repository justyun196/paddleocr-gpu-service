FROM python:3.10-slim

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV DISABLE_MODEL_SOURCE_CHECK=True

# 1. 安装系统依赖（使用经过验证的组合）
RUN apt-get update && apt-get install -y --no-install-recommends \
    # OpenGL库
    libgl1-mesa-glx \
    libglib2.0-0 \
    # X11库
    libsm6 \
    libxext6 \
    libxrender1 \
    # 字体
    libfontconfig1 \
    libfreetype6 \
    # 工具
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 2. 验证系统库
RUN echo "=== 验证libGL.so.1 ===" && \
    find /usr -name "libGL.so.1" 2>/dev/null | head -5 && \
    echo "=== 验证完成 ==="

# 设置工作目录
WORKDIR /code

# 3. 复制依赖文件
COPY code/requirements.txt .

# 4. 分步安装Python包（便于调试）
RUN pip install --no-cache-dir --upgrade pip

# 步骤1：安装NumPy和Pillow
RUN echo "安装NumPy和Pillow..." && \
    pip install --no-cache-dir numpy==1.24.3 pillow==10.1.0 && \
    python -c "import numpy as np; print('✅ NumPy:', np.__version__); from PIL import Image; print('✅ Pillow: OK')"

# 步骤2：安装OpenCV
RUN echo "安装OpenCV..." && \
    pip install --no-cache-dir opencv-python==4.8.1.78 && \
    python -c "import cv2; print('✅ OpenCV:', cv2.__version__)"

# 步骤3：安装PaddlePaddle
RUN echo "安装PaddlePaddle..." && \
    pip install --no-cache-dir paddlepaddle==2.5.1 && \
    python -c "import paddle; print('✅ PaddlePaddle:', paddle.__version__)"

# 步骤4：安装PaddleOCR
RUN echo "安装PaddleOCR..." && \
    pip install --no-cache-dir paddleocr==2.7.0.3 && \
    python -c "from paddleocr import PaddleOCR; print('✅ PaddleOCR: 导入成功')"

# 步骤5：安装其他依赖
RUN echo "安装其他依赖..." && \
    pip install --no-cache-dir openpyxl==3.1.2 oss2==2.18.1 && \
    python -c "import openpyxl; import oss2; print('✅ 其他依赖: OK')"

# 5. 复制代码
COPY code/ /code/

# 6. 最终验证（使用正确的多行语法）
RUN python -c "print('='*60); \
print('最终环境验证'); \
print('='*60); \
import sys; \
print('Python:', sys.version); \
import cv2; \
print('✅ OpenCV:', cv2.__version__); \
import numpy as np; \
print('✅ NumPy:', np.__version__); \
import paddle; \
print('✅ PaddlePaddle:', paddle.__version__); \
print('   GPU支持:', paddle.device.is_compiled_with_cuda()); \
try: \
    from paddleocr import PaddleOCR; \
    print('✅ PaddleOCR: 导入成功'); \
except Exception as e: \
    print('❌ PaddleOCR:', e); \
try: \
    from paddleocr.ppocr.vl import PaddleOCRVL; \
    print('✅ PaddleOCRVL: 导入成功'); \
except Exception as e: \
    print('⚠️ PaddleOCRVL:', e); \
print('='*60)"

# 7. 创建测试脚本（使用正确的heredoc语法）
RUN cat > /code/test_imports.py << 'EOF'
#!/usr/bin/env python3
import os
import sys

# 设置环境变量
os.environ['DISABLE_MODEL_SOURCE_CHECK'] = 'True'

print("="*60)
print("导入测试")
print("="*60)

# 测试所有导入
imports = [
    ('cv2', 'opencv-python'),
    ('numpy', 'numpy'),
    ('paddle', 'paddlepaddle'),
    ('paddleocr', 'paddleocr'),
    ('openpyxl', 'openpyxl'),
    ('oss2', 'oss2'),
]

for module_name, package_name in imports:
    try:
        if module_name == 'cv2':
            import cv2
            print(f"✅ {package_name}: {cv2.__version__}")
        elif module_name == 'numpy':
            import numpy as np
            print(f"✅ {package_name}: {np.__version__}")
        elif module_name == 'paddle':
            import paddle
            print(f"✅ {package_name}: {paddle.__version__}")
        elif module_name == 'paddleocr':
            from paddleocr import PaddleOCR
            print(f"✅ {package_name}: 导入成功")
        elif module_name == 'openpyxl':
            import openpyxl
            print(f"✅ {package_name}: {openpyxl.__version__}")
        elif module_name == 'oss2':
            import oss2
            print(f"✅ {package_name}: 导入成功")
    except ImportError as e:
        print(f"❌ {package_name}: {e}")
    except Exception as e:
        print(f"⚠️ {package_name}: {e}")

print("="*60)
EOF

# 8. 暴露端口
EXPOSE 9000

# 9. 启动命令
CMD ["python", "test_imports.py"]