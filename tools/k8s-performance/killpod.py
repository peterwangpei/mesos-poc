#!/usr/bin/env python
import json
import os
import sys
from optparse import OptionParser
import subprocess
import random


def loadConfig(filename):
    if not os.path.isfile(filename):
        return

    try:
        fp = open(filename, "r")
        return json.load(fp)
    finally:
        fp.close()


def execCommandWithCheck(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True);
    output, retcode = process.communicate()

    if retcode:
        raise subprocess.CalledProcessError(retcode, command)

    return output


def killPods(config, pods, count):
    killCommand = config["kill_command"]

    for index in range(0, count):
        podIndex = random.randint(0, len(pods) - 1)
        podName = pods.pop(podIndex)

        execCommandWithCheck(killCommand + " " + podName)
        print "Pod " + podName + " was been killed."


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

    if not config.has_key("kill_command") or not config["kill_command"]:
        print "kill_command is required."
        sys.exit(1)

    output = execCommandWithCheck(config["gather_command"])

    pods = output.splitlines()

    pod_count = int(config["pod_count"])

    if pod_count > len(pods):
        print "Not enough pods that can be delete."
        exit(1)

    killPods(config, pods, pod_count)

if __name__ == "__main__":
    main(sys.argv)
