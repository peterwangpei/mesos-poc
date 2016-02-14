#!/usr/bin/env python

import os
import re
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

DELETE_PATTERN = re.compile(r'^\{"type":"DELETED".*')
MODIFIED_PATTERN = re.compile(r'^\{"type":"MODIFIED".*')


def loadTestCase(filename):
    if not os.path.isfile(filename):
        return

    try:
        fp = open(filename, "r")
        return json.load(fp)
    finally:
        fp.close()


def loadOutput(output):
    if not output:
        return

    try:
        return json.loads(output)
    except:
        return


def execCommand(command):
    print command
    subprocess.call(command, shell=True)


def execCommandWithCheck(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True);
    output, retcode = process.communicate()

    if retcode:
        raise subprocess.CalledProcessError(retcode, command)

    return output


def watchEvents(case, queue):
    watch_url = "http://{0}/api/v1/namespaces/{1}/pods?watch=true".format(case["api_server"], case["namespace"])
    stream = urllib2.urlopen(watch_url)

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


def outputRecord(record, target):
    print "%s---%s pods left" % (datetime.datetime.now(), target)


def processEvents(queue, target, beginTime, checker, ):
    endTime = datetime.datetime.min

    if target <= 0:
        return

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
    global DELETE_PATTERN

    match = DELETE_PATTERN.match(event)

    if not match:
        return

    data = json.loads(event)

    object = data["object"]

    if data["type"] != "DELETED":
        return

    if not object.has_key("status"):
        return

    if not object["status"].has_key("containerStatuses"):
        return

    metadata = object["metadata"]
    podName = metadata["name"]
    namespace = metadata["namespace"]

    if object.has_key("spec"):
        nodeName = object["spec"]["nodeName"]

    status = object["status"]
    containerStatuses = status["containerStatuses"]
    deletionTime = datetime.datetime.min

    for container in containerStatuses:
        if not container["state"].has_key("terminated"):
            return

        containerDelectionTime = datetime.datetime.strptime(metadata["deletionTimestamp"], "%Y-%m-%dT%H:%M:%SZ")
        if containerDelectionTime > deletionTime:
            deletionTime = containerDelectionTime

    if deletionTime < beginTime:
        return

    logging.debug("%s,%s,%s,%s,%s,%s,%f", "MATCH", namespace, nodeName, podName,
                  beginTime.strftime("%Y/%m/%d %H:%M:%S.%f"),
                  deletionTime.strftime("%Y/%m/%d %H:%M:%S.%f"), (deletionTime - beginTime).total_seconds())

    return True, data, beginTime, deletionTime,


def checkCreationEvent(event, beginTime, ):
    global MODIFIED_PATTERN

    match = MODIFIED_PATTERN.match(event)

    if not match:
        return

    data = json.loads(event)

    object = data["object"]

    if data["type"] != "MODIFIED":
        return

    if not object.has_key("status"):
        return

    if not object["status"].has_key("containerStatuses"):
        return

    metadata = object["metadata"]
    podName = metadata["name"]
    namespace = metadata["namespace"]

    if object.has_key("spec"):
        nodeName = object["spec"]["nodeName"]

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

    if startedTime < beginTime:
        return

    logging.debug("%s,%s,%s,%s,%s,%s,%f", "MATCH", namespace, nodeName, podName,
                  startTime.strftime("%Y/%m/%d %H:%M:%S.%f"),
                  startedTime.strftime("%Y/%m/%d %H:%M:%S.%f"), (startedTime - startTime).total_seconds())

    return True, data, startTime, startedTime,


def main(argv):
    parser = OptionParser(usage="%prog -c case")
    parser.add_option("-c", "--case", dest="case", help="The test case file path")

    (options, argv) = parser.parse_args(argv)

    if options.case is None:
        parser.error("The test case file path was not given")

    handler = HTTPHandler()
    opener = urllib2.build_opener(handler)
    urllib2.install_opener(opener)

    case = loadTestCase(options.case)

    if not case:
        print options.case + " was not found."
        sys.exit(1)

    target = 0
    checker = None
    log_path = "."
    log_name = "case"
    api_server = "127.0.0.1:8080"
    namespace = "default"
    case_name = "TESTCASE"

    if case.has_key("api_server"):
        api_server = str(case["api_server"])

    if case.has_key("namespace"):
        namespace = str(case["namespace"])

    os.environ["api_server"] = api_server
    os.environ["namespace"] = namespace

    if case.has_key("exit_condition"):
        target = int(case["exit_condition"])

    if case.has_key("checker"):
        checker = case["checker"]

    if case.has_key("log_path"):
        log_path = case["log_path"]

    if case.has_key("log_name"):
        log_name = case["log_name"]

    if case.has_key("case_name"):
        case_name = case["case_name"]

    logging.basicConfig(level=logging.NOTSET,
                        format='%(message)s',
                        filename="{0}/{1}".format(log_path, log_name),
                        filemode='a')

    try:
        begin_time = datetime.datetime.utcnow()

        logging.debug("%s,%s,%s,%s,%s,%s,%s", "START", case_name, "", "", begin_time.strftime("%Y/%m/%d %H:%M:%S.%f"),
                      "", "")

        if not case.has_key("start_command") or not case["start_command"]:
            sys.exit(1)

        if checker:
            queue = Queue();

            thread = threading.Thread(target=watchEvents, args=(case, queue,))
            thread.daemon = True
            thread.start()

        output = execCommandWithCheck(case["start_command"])

        result = loadOutput(output)

        if result and result.has_key("target"):
            target = int(result["target"])

        if checker:
            end_time = processEvents(queue, target, begin_time, checker, )

    finally:
        if not end_time:
            end_time = datetime.datetime.utcnow()

        logging.debug("%s,%s,%s,%s,%s,%s,%f", "STOP", case_name, "", "", begin_time.strftime("%Y/%m/%d %H:%M:%S.%f"),
                      end_time.strftime("%Y/%m/%d %H:%M:%S.%f"), (end_time - begin_time).total_seconds())

        if case.has_key("clear_command") and case["clear_command"]:
            execCommand(case["clear_command"])


if __name__ == "__main__":
    main(sys.argv)
