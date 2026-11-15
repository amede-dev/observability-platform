"""Application de démonstration : métriques Prometheus + logs JSON, sans dépendance externe.

Endpoints :
  /          réponse 200 (latence simulée)
  /error     réponse 500 (pour tester HighHTTPErrorRate)
  /crash     arrête le processus (pour tester PodCrashLooping)
  /metrics   métriques au format Prometheus
  /healthz   sonde de santé
Un trafic synthétique est généré en continu (ERROR_RATE = proportion d'erreurs).
"""
import json
import os
import random
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ERROR_RATE = float(os.environ.get("ERROR_RATE", "0.02"))
BUCKETS = [0.05, 0.1, 0.25, 0.5, 1, 2.5, 5]
lock = threading.Lock()
requests = {}              # (status) -> count
hist = [0] * (len(BUCKETS) + 1)
hist_sum = 0.0
hist_count = 0


def log(level, message, **extra):
    print(json.dumps({"time": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                      "level": level, "message": message, **extra}), flush=True)


def observe(status, duration):
    global hist_sum, hist_count
    with lock:
        requests[status] = requests.get(status, 0) + 1
        hist_sum += duration
        hist_count += 1
        for i, b in enumerate(BUCKETS):
            if duration <= b:
                hist[i] += 1
        hist[-1] += 1


def render_metrics():
    out = ["# TYPE http_requests_total counter"]
    with lock:
        for status, n in requests.items():
            out.append(f'http_requests_total{{status="{status}"}} {n}')
        out.append("# TYPE http_request_duration_seconds histogram")
        for i, b in enumerate(BUCKETS):
            out.append(f'http_request_duration_seconds_bucket{{le="{b}"}} {hist[i]}')
        out.append(f'http_request_duration_seconds_bucket{{le="+Inf"}} {hist[-1]}')
        out.append(f"http_request_duration_seconds_sum {hist_sum}")
        out.append(f"http_request_duration_seconds_count {hist_count}")
    return "\n".join(out) + "\n"


def handle(path):
    start = time.time()
    time.sleep(random.uniform(0.01, 0.3))
    if path == "/error" or random.random() < ERROR_RATE:
        status = "500"
        log("error", "erreur interne simulée", path=path, status=500)
    else:
        status = "200"
        log("info", "requête traitée", path=path, status=200)
    observe(status, time.time() - start)
    return int(status)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path == "/metrics":
            body = render_metrics().encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
        elif self.path == "/healthz":
            body = b"ok"
            self.send_response(200)
        elif self.path == "/crash":
            log("fatal", "arrêt demandé via /crash")
            sys.stdout.flush()
            os._exit(1)
        else:
            code = handle(self.path)
            body = b"ok" if code == 200 else b"erreur"
            self.send_response(code)
        self.end_headers()
        self.wfile.write(body)


def traffic():
    """Génère un trafic interne pour alimenter les dashboards."""
    while True:
        handle("/")
        time.sleep(random.uniform(0.05, 0.4))


if __name__ == "__main__":
    threading.Thread(target=traffic, daemon=True).start()
    log("info", "démarrage de l'application de démonstration", port=8080)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
