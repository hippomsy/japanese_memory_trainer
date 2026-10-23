# 2026-09-29 개발용: 빌드된 AAB를 localhost로 잠깐 제공해 Play Console 업로드에 사용한다.
import http.server, os
ROOT = os.path.join(os.path.dirname(__file__), '..', 'build', 'app', 'outputs', 'bundle', 'release')
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=ROOT, **k)
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Private-Network', 'true')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()
    def do_OPTIONS(self):
        self.send_response(204); self.end_headers()
http.server.ThreadingHTTPServer(('127.0.0.1', 8765), H).serve_forever()
