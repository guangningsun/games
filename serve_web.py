#!/usr/bin/env python3
"""gzip http server —— 本地预览 Godot Web 导出

Godot Web 默认 .wasm 35MB，gzip 后 ~7.7MB。Python 自带 http.server
不启用 gzip，浏览器首次加载会慢。这个 server 加上 gzip 支持。

用法：
  python3 serve_web.py [port]   # 默认 8080
"""

import gzip
import mimetypes
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

GZIP_TYPES = {".wasm", ".js", ".html", ".css", ".json", ".svg", ".pck"}
GZIP_MIN_SIZE = 1024  # 小于 1KB 不压缩


class GzipHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # 解析路径（去掉 query string）
        path = self.path.split("?")[0]
        fs_path = self.translate_path(path)

        if not os.path.isfile(fs_path):
            self.send_error(404, f"File not found: {path}")
            return

        with open(fs_path, "rb") as f:
            body = f.read()

        # 决定是否 gzip
        ext = os.path.splitext(fs_path)[1].lower()
        accept_encoding = self.headers.get("Accept-Encoding", "")
        use_gzip = (
            "gzip" in accept_encoding
            and ext in GZIP_TYPES
            and len(body) >= GZIP_MIN_SIZE
        )

        if use_gzip:
            body = gzip.compress(body, compresslevel=6)
            encoding_header = ("Content-Encoding", "gzip")
        else:
            encoding_header = None

        # 发送响应
        ctype, _ = mimetypes.guess_type(fs_path)
        if ctype is None:
            ctype = "application/octet-stream"

        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "public, max-age=3600")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        if encoding_header:
            self.send_header(*encoding_header)
        self.end_headers()
        self.wfile.write(body)

    def translate_path(self, path):
        # 防止 path traversal
        path = path.lstrip("/")
        full = os.path.join(os.getcwd(), path)
        full = os.path.normpath(full)
        if not full.startswith(os.getcwd()):
            return "/dev/null"  # 拒绝跳出 cwd
        return full

    def log_message(self, format, *args):
        # 简化日志
        print(f"  {self.address_string()} - {format % args}")


class ReusableHTTPServer(HTTPServer):
    """允许 TIME_WAIT 状态时立即重用端口（避免重启失败）"""
    allow_reuse_address = True
    allow_reuse_port = True


def main():
    # 端口/地址：环境变量 > 命令行 > 默认 9000
    port = int(os.environ.get("PORT", sys.argv[1] if len(sys.argv) > 1 else 9000))
    host = os.environ.get("HOST", "0.0.0.0")
    # 部署目录：环境变量 DIRECTORY 优先，否则 serve.py 同级目录
    custom_dir = os.environ.get("DIRECTORY")
    if custom_dir:
        web_dir = Path(custom_dir)
    else:
        script_dir = Path(__file__).parent.resolve()
        export_web = script_dir / "export" / "web"
        web_dir = export_web if export_web.exists() else script_dir
    if not web_dir.exists() or not (web_dir / "index.html").exists():
        print(f"✗ {web_dir}/index.html not found")
        sys.exit(1)
    os.chdir(web_dir)
    server = ReusableHTTPServer((host, port), GzipHandler)
    print(f"")
    print(f"  ╭─────────────────────────────────────────╮")
    print(f"  │  Brick Breaker Web                      │")
    print(f"  │                                         │")
    print(f"  │  serving {str(web_dir):<30}│")
    print(f"  │  → http://{host}:{port:<22}│")
    print(f"  │                                         │")
    print(f"  │  gzip enabled                           │")
    print(f"  │  .wasm 35MB → ~7.7MB transfer           │")
    print(f"  ╰─────────────────────────────────────────╯")
    print(f"")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n✓ Server stopped")


if __name__ == "__main__":
    main()