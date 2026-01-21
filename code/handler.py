import json, base64, os, io, time, gc

# 禁用 oneDNN 以避免兼容性问题（必须在导入 paddle 之前设置）
os.environ['FLAGS_use_mkldnn'] = 'false'
os.environ['FLAGS_use_cudnn'] = 'false'

# 减少 PaddlePaddle 日志输出
os.environ['GLOG_v'] = '2'  # 减少 PaddlePaddle 日志
os.environ['PADDLE_LOG_LEVEL'] = 'ERROR'  # 只显示错误
os.environ['DISABLE_MODEL_SOURCE_CHECK'] = 'True'  # 跳过模型源检查

# 减少其他库的日志输出
os.environ['PYTHONUNBUFFERED'] = '0'  # 减少 Python 缓冲输出
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'  # 禁用 TensorFlow 日志（如果有的话）
os.environ['PYTHONWARNINGS'] = 'ignore'  # 忽略 Python 警告

# 减少下载进度条输出
os.environ['PADDLE_DOWNLOAD_PROGRESS'] = '0'  # 禁用 Paddle 下载进度条
os.environ['HUB_DOWNLOAD_PROGRESS'] = '0'  # 禁用 Hub 下载进度条

# 禁用 PaddlePaddle 计算图详细日志
os.environ['FLAGS_enable_pir'] = 'false'  # 禁用 PIR 模式（减少计算图日志）
os.environ['FLAGS_print_ir'] = 'false'  # 禁用 IR 打印
os.environ['FLAGS_graphviz_path'] = ''  # 禁用 Graphviz 输出
os.environ['FLAGS_check_nan_inf'] = 'false'  # 禁用 NaN/Inf 检查（减少日志）

import paddle
paddle.set_device('cpu')
paddle.disable_static()

# 尝试导入 PaddleOCRVL，失败则使用基础版 PaddleOCR
try:
    import paddleocr
    from paddleocr.ppocr.vl import PaddleOCRVL
    PADDLEOCR_VL_AVAILABLE = True
    print("✅ PaddleOCRVL 可用")
except ImportError as e:
    from paddleocr import PaddleOCR
    PaddleOCRVL = None
    PADDLEOCR_VL_AVAILABLE = False
    print("⚠️ PaddleOCRVL 不可用，使用基础版 PaddleOCR")

from openpyxl import Workbook
import cv2

# 全局OCR实例（避免重复加载）
ocr = None

def init_ocr():
    global ocr
    if ocr is None:
        if PADDLEOCR_VL_AVAILABLE:
            ocr = PaddleOCRVL()
        else:
            ocr = PaddleOCR(use_angle_cls=True, lang='ch', use_mkldnn=False)
    return ocr

def recognize_single_image(img_bytes):
    ocr_instance = init_ocr()
    
    if ocr_instance is None:
        return {
            'success': False,
            'error': 'OCR引擎初始化失败'
        }
    
    try:
        from PIL import Image
        import numpy as np
        
        image = Image.open(io.BytesIO(img_bytes))
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        img_np = np.array(image)
        
        if not PADDLEOCR_VL_AVAILABLE:
            result = ocr_instance.ocr(img_np)
        else:
            temp_path = "/tmp/temp_image.jpg"
            with open(temp_path, "wb") as f:
                f.write(img_bytes)
            try:
                result = ocr_instance.predict(temp_path)
            finally:
                if os.path.exists(temp_path):
                    os.remove(temp_path)
        
        recognized_texts = []
        
        if not PADDLEOCR_VL_AVAILABLE and result:
            if result[0]:
                for line in result[0]:
                    if line and len(line) >= 2:
                        box = line[0]
                        text = line[1][0]
                        confidence = float(line[1][1])
                        
                        recognized_texts.append({
                            'text': text,
                            'confidence': confidence,
                            'bbox': box
                        })
        elif PADDLEOCR_VL_AVAILABLE and result:
            if isinstance(result, list):
                for doc in result:
                    if isinstance(doc, dict):
                        if 'text_blocks' in doc:
                            for block in doc['text_blocks']:
                                recognized_texts.append({
                                    'text': block.get('text', ''),
                                    'confidence': float(block.get('confidence', 1.0)),
                                    'bbox': block.get('bbox', [])
                                })
        
        full_text = '\n'.join([item['text'] for item in recognized_texts])
        
        return {
            'success': True,
            'text': full_text,
            'details': recognized_texts,
            'model_type': 'PaddleOCR-VL' if PADDLEOCR_VL_AVAILABLE else 'PaddleOCR-Base'
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': f'识别失败: {str(e)}'
        }

def handler(event, context):
    evt = json.loads(event)
    
    if 'image' in evt:
        try:
            img_bytes = base64.b64decode(evt['image'])
        except Exception as e:
            return {
                'success': False,
                'error': f'Base64 解码失败: {str(e)}'
            }
        result = recognize_single_image(img_bytes)
        return result
    
    elif 'bucket' in evt and 'key' in evt:
        try:
            import oss2
            
            auth = oss2.StsAuth(
                context.credentials.access_key_id,
                context.credentials.access_key_secret,
                context.credentials.security_token
            )
            
            bucket = oss2.Bucket(
                auth,
                f'https://oss-{context.region}.aliyuncs.com',
                evt['bucket']
            )
            
            tasks = json.loads(bucket.get_object(evt['key']).read())
            print(f"获取到 {len(tasks)} 个任务")
            
            wb = Workbook()
            ws = wb.active
            ws.append(['文件名', '识别文本', '置信度'])
            
            for i, t in enumerate(tasks):
                print(f"处理第 {i+1}/{len(tasks)} 个文件: {t['key']}")
                
                img_bytes = bucket.get_object(t['key']).read()
                result = recognize_single_image(img_bytes)
                
                if result['success']:
                    for item in result['details']:
                        ws.append([
                            t['key'],
                            item['text'],
                            f"{item['confidence']:.4f}"
                        ])
                else:
                    ws.append([t['key'], '识别失败', '0.0000'])
            
            buf = io.BytesIO()
            wb.save(buf)
            buf.seek(0)
            
            out_key = evt['key'].replace('.json', '_result.xlsx')
            bucket.put_object(out_key, buf)
            
            print(f"✅ 批量处理完成，结果已保存到: {out_key}")
            
            return {
                'success': True,
                'excel': out_key,
                'total_files': len(tasks)
            }
            
        except Exception as e:
            print(f"❌ 批量处理失败: {e}")
            import traceback
            traceback.print_exc()
            return {
                'success': False,
                'error': str(e)
            }
    
    else:
        return {
            'success': False,
            'error': '无效的请求参数，请提供 image（同步模式）或 bucket/key（异步模式）'
        }

import json, base64, os, io, time, gc
import paddle
paddle.set_device('cpu')
paddle.disable_static()

# 尝试导入 PaddleOCRVL，失败则使用基础版 PaddleOCR
try:
    from paddleocr.ppocr.vl import PaddleOCRVL
    PADDLEOCR_VL_AVAILABLE = True
    print("✅ PaddleOCRVL 可用")
except ImportError:
    from paddleocr import PaddleOCR
    PaddleOCRVL = None  # 标记VL不可用
    PADDLEOCR_VL_AVAILABLE = False
    print("⚠️ PaddleOCRVL 不可用，使用基础版 PaddleOCR")

from openpyxl import Workbook
import cv2

# 全局OCR实例（避免重复加载）
ocr = None

def init_ocr():
    global ocr
    if ocr is None:
        if PADDLEOCR_VL_AVAILABLE:
            print("正在初始化PaddleOCRVL模型（CPU版本）...")
            ocr = PaddleOCRVL()
            print("✅ PaddleOCRVL 模型初始化完成")
        else:
            print("正在初始化PaddleOCR基础版模型（CPU版本）...")
            ocr = PaddleOCR(use_angle_cls=True, lang='ch')
            print("✅ PaddleOCR 基础版模型初始化完成")
    return ocr

def recognize_single_image(img_bytes):
    ocr_instance = init_ocr()
    
    if ocr_instance is None:
        return {
            'success': False,
            'error': 'OCR引擎初始化失败'
        }
    
    try:
        from PIL import Image
        import numpy as np
        
        image = Image.open(io.BytesIO(img_bytes))
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        img_np = np.array(image)
        
        if not PADDLEOCR_VL_AVAILABLE:
            result = ocr_instance.ocr(img_np)
        else:
            temp_path = "/tmp/temp_image.jpg"
            with open(temp_path, "wb") as f:
                f.write(img_bytes)
            try:
                result = ocr_instance.predict(temp_path)
            finally:
                if os.path.exists(temp_path):
                    os.remove(temp_path)
        
        recognized_texts = []
        
        if not PADDLEOCR_VL_AVAILABLE and result:
            if result[0]:
                for line in result[0]:
                    if line and len(line) >= 2:
                        box = line[0]
                        text = line[1][0]
                        confidence = float(line[1][1])
                        
                        recognized_texts.append({
                            'text': text,
                            'confidence': confidence,
                            'bbox': box
                        })
        elif PADDLEOCR_VL_AVAILABLE and result:
            if isinstance(result, list):
                for doc in result:
                    if isinstance(doc, dict):
                        if 'text_blocks' in doc:
                            for block in doc['text_blocks']:
                                recognized_texts.append({
                                    'text': block.get('text', ''),
                                    'confidence': float(block.get('confidence', 1.0)),
                                    'bbox': block.get('bbox', [])
                                })
        
        full_text = '\n'.join([item['text'] for item in recognized_texts])
        
        return {
            'success': True,
            'text': full_text,
            'details': recognized_texts,
            'model_type': 'PaddleOCR-VL' if PADDLEOCR_VL_AVAILABLE else 'PaddleOCR-Base'
        }
        
    except Exception as e:
        print(f"❌ 图像识别失败: {e}")
        import traceback
        traceback.print_exc()
        
        return {
            'success': False,
            'error': f'识别失败: {str(e)}',
            'traceback': traceback.format_exc()
        }

def handler(event, context):
    evt = json.loads(event)
    
    if 'image' in evt:
        print("同步模式：处理单张图片")
        
        image_data = evt['image']
        
        print(f"📥 接收到 base64 数据，长度: {len(image_data)}")
        
        try:
            img_bytes = base64.b64decode(image_data)
            print(f"✅ Base64 解码成功，图像大小: {len(img_bytes)} bytes")
        except Exception as e:
            print(f"❌ Base64 解码失败: {e}")
            print(f"   数据前100字符: {image_data[:100]}")
            return {
                'success': False,
                'error': f'Base64 解码失败: {str(e)}'
            }
        
        result = recognize_single_image(img_bytes)
        return result
    
    elif 'bucket' in evt and 'key' in evt:
        print("异步模式：批量处理")
        try:
            import oss2
            
            auth = oss2.StsAuth(
                context.credentials.access_key_id,
                context.credentials.access_key_secret,
                context.credentials.security_token
            )
            
            bucket = oss2.Bucket(
                auth,
                f'https://oss-{context.region}.aliyuncs.com',
                evt['bucket']
            )
            
            tasks = json.loads(bucket.get_object(evt['key']).read())
            print(f"获取到 {len(tasks)} 个任务")
            
            wb = Workbook()
            ws = wb.active
            ws.append(['文件名', '识别文本', '置信度'])
            
            for i, t in enumerate(tasks):
                print(f"处理第 {i+1}/{len(tasks)} 个文件: {t['key']}")
                
                img_bytes = bucket.get_object(t['key']).read()
                result = recognize_single_image(img_bytes)
                
                if result['success']:
                    for item in result['details']:
                        ws.append([
                            t['key'],
                            item['text'],
                            f"{item['confidence']:.4f}"
                        ])
                else:
                    ws.append([t['key'], '识别失败', '0.0000'])
            
            buf = io.BytesIO()
            wb.save(buf)
            buf.seek(0)
            
            out_key = evt['key'].replace('.json', '_result.xlsx')
            bucket.put_object(out_key, buf)
            
            print(f"✅ 批量处理完成，结果已保存到: {out_key}")
            
            return {
                'success': True,
                'excel': out_key,
                'total_files': len(tasks)
            }
            
        except Exception as e:
            print(f"❌ 批量处理失败: {e}")
            import traceback
            traceback.print_exc()
            return {
                'success': False,
                'error': str(e)
            }
    
    else:
        return {
            'success': False,
            'error': '无效的请求参数，请提供 image（同步模式）或 bucket/key（异步模式）'
        }
