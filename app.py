# app.py
import sys
print("Python版本:", sys.version)

# 检查能否导入关键包
try:
    import paddle
    print("PaddlePaddle版本:", paddle.__version__)
    print("GPU支持:", paddle.device.is_compiled_with_cuda())
except:
    print("PaddlePaddle未安装")

# 简单的HTTP服务
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        response = json.dumps({"status": "ok", "message": "测试成功"})
        self.wfile.write(response.encode())

if __name__ == "__main__":
    server = HTTPServer(('0.0.0.0', 9000), Handler)
    print("服务器启动在端口 9000")
    server.serve_forever()
