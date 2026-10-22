import functools
import http.server
import os


class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


root = os.path.dirname(os.path.abspath(__file__))
http.server.ThreadingHTTPServer(("", 5194), functools.partial(NoCache, directory=root)).serve_forever()
