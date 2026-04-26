from flask import Flask
import os
import socket

app = Flask(__name__)


@app.route("/")
def hello():
    return f"Hello, world! from {socket.gethostname()}\n"


@app.route("/healthz")
def healthz():
    return "ok\n", 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
