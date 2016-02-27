#!/usr/bin/env python
import json
import os
import sys
import urllib2
from optparse import OptionParser
import subprocess
import random


def loadOutput(output):
    if not output:
        return

    try:
        return json.loads(output)
    except:
        return


def loadConfig(filename):
    if not os.path.isfile(filename):
        return

    try:
        fp = open(filename, "r")
        return json.load(fp)
    finally:
        fp.close()


def getNodePods(config, nodeName):
    query_url = "http://{0}/api/v1/namespaces/{1}/pods?fieldSelector=spec.nodeName%3D{2}".format(config["api_server"],
                                                                                                 config["namespace"],
                                                                                                 nodeName)
    stream = urllib2.urlopen(query_url)
    output = stream.read()

    if not output:
        return

    result = loadOutput(output)

    if not result:
        return

    if not result.has_key("items"):
        return

    # TODO Need to check pod state
    return result["items"]


def execCommandWithCheck(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True);
    output, retcode = process.communicate()

    if retcode:
        raise subprocess.CalledProcessError(retcode, command)

    return output


def killNodes(config, nodes, count):
    killCommand = config["kill_command"]

    killedNodes = []

    for index in range(0, count):
        nodeIndex = random.randint(0, len(nodes) - 1)
        nodeName = nodes.pop(nodeIndex)

        pods = getNodePods(config, nodeName)

        execCommandWithCheck(killCommand + " " + nodeName)

        killedNodes.append((nodeName, len(pods),))

    return killedNodes


def main(argv):
    parser = OptionParser(usage="%prog -c config")
    parser.add_option("-c", "--config", dest="config", help="The environment config file")

    (options, argv) = parser.parse_args(argv)

    if options.config is None:
        parser.error("The environment config file was not given")

    config = loadConfig(options.config)

    if not config:
        print options.config + " was not found."
        sys.exit(1)

    if not config.has_key("gather_command") or not config["gather_command"]:
        print "gather_command is required."
        sys.exit(1)

    output = execCommandWithCheck(config["gather_command"])

    nodes = output.splitlines()

    if len(nodes) <= 1:
        print '{{"node":"{0}","target":{1}}}'.format("", 0)
        exit(0)

    result = killNodes(config, nodes, 1)

    if config.has_key("clear_command") and config["clear_command"]:
        clear_command = config["clear_command"]
        clear_command = clear_command.replace("{NODE}", result[0][0])

        execCommandWithCheck(clear_command)

    print '{{"node":"{0}","target":{1}}}'.format(result[0][0], result[0][1])


if __name__ == "__main__":
    main(sys.argv)
