#!/usr/bin/env python3
"""HTTPS + gzip http server —— 部署 Godot Web 导出 + 自签名证书

Godot 4 Web 要求 HTTPS（Secure Context），否则浏览器拒绝启动。
用自签名证书（生产环境建议换 Let's Encrypt）。

用法：
  python3 serve_https.py [port]   # 默认 9000
  python3 serve_https.py 9443      # 自定义端口
"""

import gzip
import mimetypes
import os
import ssl
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

GZIP_TYPES = {".wasm", ".js", ".html", ".css", ".json", ".svg", ".pck"}
GZIP_MIN_SIZE = 1024


class GzipHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?")[0]
        # 裸域名 fallback 到 index.html
        if path == "/" or path == "":
            path = "/index.html"
        fs_path = self.translate_path(path)

        if not os.path.isfile(fs_path):
            self.send_error(404, f"File not found: {path}")
            return

        with open(fs_path, "rb") as f:
            body = f.read()

        # gzip 决策
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
        path = path.lstrip("/")
        full = os.path.join(os.getcwd(), path)
        full = os.path.normpath(full)
        if not full.startswith(os.getcwd()):
            return "/dev/null"
        return full

    def log_message(self, format, *args):
        print(f"  {self.address_string()} - {format % args}")


class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True


def main():
    port = int(os.environ.get("PORT", sys.argv[1] if len(sys.argv) > 1 else 9000))
    # 默认绑 127.0.0.1（只监听本地回环，不对外暴露）
    # 公开访问请用 nginx 反向代理
    host = os.environ.get("HOST", "127.0.0.1")
    script_dir = Path(__file__).parent.resolve()
    custom_dir = os.environ.get("DIRECTORY")
    if custom_dir:
        web_dir = Path(custom_dir)
    else:
        export_web = script_dir / "export" / "web"
        web_dir = export_web if export_web.exists() else script_dir
    if not web_dir.exists() or not (web_dir / "index.html").exists():
        print(f"✗ {web_dir}/index.html not found")
        sys.exit(1)
    os.chdir(web_dir)

    # HTTPS 配置（127.0.0.1/localhost 不需要，浏览器视其为 Secure Context）
    # 公开域名才需要 HTTPS + 证书
    cert_path = script_dir / "certs" / "cert.pem"
    key_path = script_dir / "certs" / "key.pem"
    https_enabled = (
        cert_path.exists()
        and key_path.exists()
        and host not in ("127.0.0.1", "localhost")
    )

    server = ReusableHTTPServer((host, port), GzipHandler)
    if https_enabled:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(str(cert_path), str(key_path))
        server.socket = ctx.wrap_socket(server.socket, server_side=True)
        scheme = "https"
    else:
        scheme = "http"
        if host not in ("127.0.0.1", "localhost"):
            print(f"⚠ 公开 IP 需要 HTTPS（certs/ 缺失），回退到 HTTP")

    print(f"""
  ╭─────────────────────────────────────────╮
  │  Brick Breaker Web                      │
  │                                         │
  │  serving {str(web_dir):<30}│
  │  → {scheme}://{host}:{port:<22}│
  │                                         │
  │  bound: {'localhost only' if host in ('127.0.0.1', 'localhost') else 'all interfaces':<28}│
  │  gzip enabled                           │
  │  .wasm 35MB → ~7.7MB transfer           │
  │  HTTPS: {('yes' if https_enabled else 'no (localhost OK)'):<23}│
  ╰─────────────────────────────────────────╯
""")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n✓ Server stopped")


if __name__ == "__main__":
    main()