#!/usr/bin/env python

import urllib2
import sys
import json
import requests
import threading
import os
from urllib import urlencode
from urllib import quote
from mako.template import Template
from optparse import OptionParser
from urlgrabber.keepalive import HTTPHandler

server = None
templatefile = None
configfile = None

class EndPoint:
    address = ""
    port = ""

    def __init__(self,address, port):
        self.address = address
        self.port = port

class Service:
    name = ""
    endpoints = []

    def __init__(self, name, endpoints):
        self.name = name
        self.endpoints = endpoints

def generateconfig(server,configfile):
    services = loadservices(server)
    template = Template(filename=templatefile)
    content =  template.render(items=services)

    try:
        file = open(configfile,"w")
        file.write(content)
    finally:
        file.close()

def reloadbalancer():
    generateconfig(server,configfile)
    os.system("/bin/bash reload.sh {0}".format(configfile))

def loadjson(url):
    try:
        request = requests.get(url)
        return json.loads(request.content)
    finally:
        request.close()

def loadservices(server):

    serviceurl = "http://{0}/api/v1/namespaces/default/services".format(server)

    jsonservices = loadjson(serviceurl)

    services = []

    for s in jsonservices["items"]:

        if not "name" in s["metadata"]:
            continue

        name = quote(s["metadata"]["name"])

        endpointurl = "http://{0}/api/v1/namespaces/default/endpoints/{1}".format(server,name)

        jsonendpoint = loadjson(endpointurl)

        endpoints = []

        for subset in jsonendpoint["subsets"]:
            for address in subset["addresses"]:
                for port in subset["ports"]:
                    endpoint = EndPoint(address["ip"],port["port"])
                    endpoints.append(endpoint)

        service = Service(s["metadata"]["name"],endpoints)

        services.append(service)

    return services

def main(argv):

    global server
    global templatefile
    global configfile

    parser = OptionParser(usage="%prog -s url")
    parser.add_option("-s","--server", dest="server", help="The address and port of the Kubernetes API server")
    parser.add_option("-t","--template", dest="template", help="The template of haproxy config file", default="template.cfg")
    parser.add_option("-c","--config", dest="config", help="The config file path of haproxy", default="/etc/haproxy/haproxy.cfg")

    (options, argv) = parser.parse_args(argv)

    print options.template

    if options.server is None:
        parser.error("The address and port of the Kubernetes API server was not given")

    if options.template is None:
        parser.error("The template of haproxy config file was not given")

    if options.config is None:
        parser.error("The config file path of haproxy was not given")

    handler = HTTPHandler()
    opener = urllib2.build_opener(handler)
    urllib2.install_opener(opener)

    server = options.server
    templatefile = options.template
    configfile = options.config

    serviceurl = "http://{0}/api/v1/namespaces/default/endpoints?watch=true".format(options.server)
    stream = urllib2.urlopen(serviceurl)

    message = ""
    length = -1
    reloadtimer = None

    while True:

        if message.endswith("\r\n"):
            message = message.rstrip()

            if len(message) > 0:
                length = int(message,16)
                message = ""

        if length == -1:
            message += stream.read(1)
        else:
            message = stream.read(length)
            length = -1
            message = ""

            if reloadtimer is not None:
                reloadtimer.cancel()

            reloadtimer = threading.Timer(0.5, reloadbalancer)
            reloadtimer.start()

if __name__ == "__main__":
    main(sys.argv)