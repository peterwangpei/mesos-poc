#!/usr/bin/env python

import json
import sys
import urllib2
import subprocess
import threading
from Queue import Queue
from Queue import Empty
from optparse import OptionParser
import datetime
import logging
from urlgrabber.keepalive import HTTPHandler


def loadTestCase(filename):
    try:
        fp = open(filename, "r")
        return json.load(fp)
    finally:
        fp.close()


def execCommandWithCheck(command):
    subprocess.check_call(command, shell=True)
    print command


def watchEvents(case, queue):
    watchurl = "http://{0}/api/v1/namespaces/{1}/pods?watch=true".format(case["api_server"], case["namespace"])
    stream = urllib2.urlopen(watchurl)

    event = ""
    length = -1

    while True:

        if event.endswith("\r\n"):
            event = event.rstrip()

            if len(event) > 0:
                length = int(event, 16)
                event = ""

        if length == -1:
            event += stream.read(1)
        else:
            event = stream.read(length)
            queue.put_nowait(event)
            length = -1
            event = ""


def execCommand(command):
    subprocess.call(command, shell=True)
    print command


def outputRecord(record, target):
    print "%s---%s pods left" % (datetime.datetime.now(), target)


def processEvents(queue, target, beginTime, checker, ):
    endTime = datetime.datetime.min
    while True:
        try:
            event = queue.get_nowait()

            record = eval(checker)(event, beginTime, )
            if record:
                target -= 1
                outputRecord(record, target)

                if record[3] > endTime:
                    endTime = record[3];

            if target == 0:
                return endTime

            if target < 0:
                raise Exception("Invalid target condition")

            queue.task_done()
        except Empty:
            continue


def checkDeletionEvent(event, beginTime, ):
    data = json.loads(event)

    object = data["object"]

    if data["type"] != "DELETED":
        return

    if not object.has_key("status"):
        return

    if not object["status"].has_key("containerStatuses"):
        return

    metadata = object["metadata"]
    status = object["status"]
    containerStatuses = status["containerStatuses"]
    deletionTime = datetime.datetime.min

    for container in containerStatuses:
        if not container["state"].has_key("terminated"):
            return

        containerDelectionTime = datetime.datetime.strptime(metadata["deletionTimestamp"], "%Y-%m-%dT%H:%M:%SZ")
        if containerDelectionTime > deletionTime:
            deletionTime = containerDelectionTime

    logging.debug("%s,%s,%s,%f", "MATCH", beginTime.strftime("%Y/%m/%d %H:%M:%S.%f"),
                  deletionTime.strftime("%Y/%m/%d %H:%M:%S.%f"), (deletionTime - beginTime).total_seconds())

    return True, data, beginTime, deletionTime,


def checkCreationEvent(event, beginTime, ):
    data = json.loads(event)

    object = data["object"]

    if data["type"] != "MODIFIED":
        return

    if not object.has_key("status"):
        return

    if not object["status"].has_key("containerStatuses"):
        return

    status = object["status"]
    containerStatuses = status["containerStatuses"]
    startedTime = datetime.datetime.min

    for container in containerStatuses:
        if not container["state"].has_key("running"):
            return

        if not container["ready"]:
            return

        containerStartedTime = datetime.datetime.strptime(container["state"]["running"]["startedAt"],
                                                          "%Y-%m-%dT%H:%M:%SZ")
        if containerStartedTime > startedTime:
            startedTime = containerStartedTime

    startTime = datetime.datetime.strptime(status["startTime"], "%Y-%m-%dT%H:%M:%SZ")

    logging.debug("%s,%s,%s,%f", "MATCH", startTime.strftime("%Y/%m/%d %H:%M:%S.%f"),
                  startedTime.strftime("%Y/%m/%d %H:%M:%S.%f"), (startedTime - startTime).total_seconds())

    return True, data, startTime, startedTime,


def main(argv):
    global case
    global isachieved
    global exit_condition
    global queue
    global lasttime

    queue = Queue();

    parser = OptionParser(usage="%prog -c case")
    parser.add_option("-c", "--case", dest="case", help="The json config file path of test case")

    (options, argv) = parser.parse_args(argv)

    if options.case is None:
        parser.error("The yaml config file path of test case was not given")

    handler = HTTPHandler()
    opener = urllib2.build_opener(handler)
    urllib2.install_opener(opener)

    case = loadTestCase(options.case)

    target = int(case["exit_condition"])
    checker = case["checker"]

    logging.basicConfig(level=logging.NOTSET,
                        format='%(message)s',
                        filename="{0}_{1}.log".format(case["log_name"],
                                                      datetime.datetime.now().strftime("%Y%m%d%H%M%S")),
                        filemode='w')

    try:
        beginTime = datetime.datetime.now()
        logging.debug("%s,%s,%s,%s", "START", beginTime.strftime("%Y/%m/%d %H:%M:%S.%f"), "", "")

        execCommandWithCheck(case["start_command"])

        thread = threading.Thread(target=watchEvents, args=(case, queue,))
        thread.daemon = True
        thread.start()

        endTime = processEvents(queue, target, beginTime, checker, )

        logging.debug("%s,%s,%s,%f", "STOP", beginTime.strftime("%Y/%m/%d %H:%M:%S.%f"),
                      endTime.strftime("%Y/%m/%d %H:%M:%S.%f"), (endTime - beginTime).total_seconds())

    finally:
        if case.has_key("clear_command") and case["clear_command"]:
            execCommand(case["clear_command"])


if __name__ == "__main__":
    main(sys.argv)
