#!/usr/bin/env python

import logging
import logging.config
import sys
import json
from poc import Queue
from poc.Ansible import Ansible

logging.config.fileConfig('logging_config.ini')


def main(argv):
    try:
        if argv[1] == "send":
            print "send mode"
            queue = Queue.Publisher(
                "amqp://admin:xA123456@192.168.0.202:5672/%2F?connection_attempts=3&heartbeat_interval=3600")
            queue.run()
        elif argv[1] == "receive":
            print "receive mode"
            queue = Queue.Receiver(
                "amqp://admin:xA123456@192.168.0.202:5672/%2F?connection_attempts=3&heartbeat_interval=3600")
            queue.bind_to(on_message)
            queue.run()
        else:
            print "call ansible"
            ansible = Ansible()
            ansible.Test('192.168.0.202')

    except KeyboardInterrupt:
        if queue:
            queue.stop()


def on_message(channel, basic_deliver, properties, body):
    print "received message " + body
    message = json.loads(body)

    if message.has_key("Host"):
        ansible = Ansible()
        ansible.Test(message["Host"])

    channel.basic_ack(basic_deliver.delivery_tag)


if __name__ == "__main__":
    main(sys.argv)
