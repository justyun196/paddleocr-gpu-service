from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import sys
import os
import traceback
import time

# 添加当前目录到 Python 路径
sys.path.insert(0, os.path.dirname(__file__))

# 设置环境变量（必须在导入前）
os.environ['DISABLE_MODEL_SOURCE_CHECK'] = 'True'

# 全局变量
OCR_AVAILABLE = False
OCR_INIT_ERROR = None
HANDLER_FUNC = None

print("="*60)
print("🚀 PaddleOCR HTTP Server 启动中...")
print("="*60)

# 尝试导入 handler
def init_handler():
    global OCR_AVAILABLE, OCR_INIT_ERROR, HANDLER_FUNC
    
    try:
        print("📦 正在导入 handler 模块...")
        start_time = time.time()
        
        from handler import handler as handler_func
        HANDLER_FUNC = handler_func
        
        init_time = time.time() - start_time
        OCR_AVAILABLE = True
        print(f"✅ Handler 导入成功，耗时: {init_time:.2f}秒")
        print("="*60)
        return True
        
    except Exception as e:
        OCR_AVAILABLE = False
        OCR_INIT_ERROR = str(e)
        print(f"❌ Handler 导入失败: {e}")
        print("="*60)
        traceback.print_exc()
        print("="*60)
        return False

# 初始化 handler（延迟初始化，避免启动失败）
HANDLER_LOADED = False

def get_handler():
    global HANDLER_LOADED
    
    if not HANDLER_LOADED:
        HANDLER_LOADED = init_handler()
    
    if HANDLER_LOADED:
        return HANDLER_FUNC
    else:
        def fallback_handler(data, context):
            return {
                'success': False,
                'error': 'OCR handler not available',
                'details': OCR_INIT_ERROR,
                'message': '服务正在初始化中，请稍后重试'
            }
        return fallback_handler

class RequestHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        start_time = time.time()
        content_length = int(self.headers.get('Content-Length', 0))
        
        try:
            post_data = self.rfile.read(content_length) if content_length > 0 else b''
            
            # 打印请求信息
            print(f"\n{'='*60}")
            print(f"[{self.log_date_time_string()}] 📨 POST 请求")
            print(f"   路径: {self.path}")
            print(f"   数据长度: {content_length} bytes")
            
            # 调用 handler
            handler_func = get_handler()
            result = handler_func(post_data.decode('utf-8') if post_data else '{}', None)
            
            # 返回响应
            response_data = json.dumps(result, ensure_ascii=False)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', len(response_data))
            self.end_headers()
            self.wfile.write(response_data.encode('utf-8'))
            
            elapsed = time.time() - start_time
            print(f"   状态: {'✅ 成功' if result.get('success') else '❌ 失败'}")
            print(f"   耗时: {elapsed:.2f}秒")
            print(f"{'='*60}\n")
            
        except Exception as e:
            elapsed = time.time() - start_time
            print(f"\n{'='*60}")
            print(f"[{self.log_date_time_string()}] ❌ 处理异常")
            print(f"   错误: {str(e)}")
            print(f"   耗时: {elapsed:.2f}秒")
            print(f"{'='*60}\n")
            traceback.print_exc()
            
            error_response = json.dumps({
                'success': False,
                'error': str(e),
                'traceback': traceback.format_exc()
            }, ensure_ascii=False)
            
            self.send_response(500)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', len(error_response))
            self.end_headers()
            self.wfile.write(error_response.encode('utf-8'))
    
    def do_GET(self):
        print(f"\n{'='*60}")
        print(f"[{self.log_date_time_string()}] 🔍 GET 请求")
        print(f"   路径: {self.path}")
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.end_headers()
        
        status_info = {
            'status': 'ready' if OCR_AVAILABLE else 'initializing',
            'message': 'PaddleOCR Service is running',
            'ocr_available': OCR_AVAILABLE,
            'service': 'PaddleOCR HTTP Server',
            'version': '1.0.0',
            'endpoints': {
                'GET /': '健康检查',
                'POST /': 'OCR识别'
            },
            'error': OCR_INIT_ERROR if not OCR_AVAILABLE else None
        }
        
        response_data = json.dumps(status_info, ensure_ascii=False, indent=2)
        self.send_header('Content-Length', len(response_data))
        self.wfile.write(response_data.encode('utf-8'))
        
        print(f"   状态: {status_info['status']}")
        print(f"{'='*60}\n")
    
    def log_message(self, format, *args):
        # 使用标准输出，方便函数计算日志收集
        print(f"[{self.log_date_time_string()}] {format % args}")

def run_server(port=9000):
    server_address = ('', port)
    httpd = HTTPServer(server_address, RequestHandler)
    
    print(f"\n{'='*60}")
    print(f"🚀 PaddleOCR HTTP Server")
    print(f"{'='*60}")
    print(f"📡 监听地址: 0.0.0.0:{port}")
    print(f"🔗 健康检查: http://localhost:{port}/")
    print(f"📝 OCR 识别: POST http://localhost:{port}/")
    print(f"{'='*60}\n")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 正在关闭服务器...")
        httpd.server_close()
        print("✅ 服务器已关闭")
    except Exception as e:
        print(f"\n❌ 服务器错误: {e}")
        traceback.print_exc()

if __name__ == '__main__':
    run_server()