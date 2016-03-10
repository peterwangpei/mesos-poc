#!/usr/bin/env python
import sys
import ssl
import json
import base64
import urllib2
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
from optparse import OptionParser


class TestHTTPHandle(BaseHTTPRequestHandler):
    def do_GET(self):

        if self.path == "/":
            buffer = "Please spelcify pod name to query pod ip address"
        else:
            parts = self.path[1:].split("/")
            namespace = "default"
            podname = ""

            if len(parts) == 1:
                podname = parts[0]

            if len(parts) == 2:
                namespace = parts[0]
                podname = parts[1]

            if len(namespace) == 0 or len(podname) == 0:
                buffer = "Please spelcify pod name to query pod ip address"
            else:
                url = "https://192.168.33.121:6443/api/v1/namespaces/" + namespace + "/pods/" + podname
                print url

                base64string = base64.encodestring('%s:%s' % ("root", "root")).replace('\n', '')
                request = urllib2.Request(url)
                request.add_header("Authorization", "Basic %s" % base64string)

                context = ssl._create_unverified_context()

                data = urllib2.urlopen(request, context=context).read()

                pod = json.loads(data)

                buffer = pod["status"]["hostIP"]

        self.protocal_version = "HTTP/1.1"

        self.send_response(200)

        self.send_header("Welcome", "Contect")

        self.end_headers()

        self.wfile.write(buffer)


def start_server(port):
    http_server = HTTPServer(('', int(port)), TestHTTPHandle)
    http_server.serve_forever()


def main(argv):
    # parser = OptionParser(usage="%prog -s url")
    # parser.add_option("-s","--server", dest="server", help="The address and port of the Kubernetes API server")
    #
    # (options, argv) = parser.parse_args(argv)
    #
    # if options.server is None:
    #     parser.error("The address and port of the Kubernetes API server was not given")
    start_server(1080)


if __name__ == "__main__":
    main(sys.argv)
