#!/usr/bin/env python

import logging
import pika
import json
import time

LOGGER = logging.getLogger(__name__)

__version__ = "1.0.0"
__all__ = ['Receiver', 'Publisher']


class Receiver:
    def __init__(self, url, queue_name="queue", routing_key="queue", exchange_name='topic_exchange',
                 exchange_type='topic', retry_interval=5):

        self._url = url
        self._queue_name = queue_name
        self._routing_key = routing_key
        self._exchange_name = exchange_name
        self._exchange_type = exchange_type
        self._closing = False
        self._consumer_tag = None
        self._connection = None
        self._channel = None
        self._retry_interval = retry_interval
        self._observers = [];

    def _connect(self):

        return pika.SelectConnection(pika.URLParameters(self._url),
                                     on_open_callback=self._on_connection_open,
                                     on_close_callback=self._on_connection_closed,
                                     stop_ioloop_on_close=False)

    def _open_channel(self):

        self._connection.channel(on_open_callback=self._on_channel_open)

    def _setup_exchange(self, exchange_name, exchange_type):

        LOGGER.info('Declaring exchange %s %s', exchange_name, exchange_type)
        self._channel.exchange_declare(self._on_exchange_declare, exchange_name, exchange_type)

    def _on_exchange_declare(self, frame):
        LOGGER.info('Exchange declared')
        self._setup_queue(self._queue_name)

    def _setup_queue(self, queue_name):

        LOGGER.info('Declaring queue %s', queue_name)
        self._channel.queue_declare(self._on_queue_declare, queue_name)

    def _on_queue_declare(self, method_frame):

        LOGGER.info('Binding %s to %s with %s', self._exchange_name, self._queue_name, self._routing_key)
        self._channel.queue_bind(self._on_bind, self._queue_name, self._exchange_name, self._routing_key)

    def _on_bind(self, frame):

        LOGGER.info('Queue bound')
        self._start_consuming()

    def _start_consuming(self):

        LOGGER.info('Issuing consumer related RPC commands')

        self.add_on_cancel_callback()
        self._consumer_tag = self._channel.basic_consume(self._on_message, self._queue_name)

    def _on_message(self, channel, basic_deliver, properties, body):

        LOGGER.info('Received message # %s from %s: %s', basic_deliver.delivery_tag, properties.app_id, body)

        for callback in self._observers:
            callback(channel, basic_deliver, properties, body)

    def _acknowledge_message(self, delivery_tag):

        LOGGER.info('Acknowledging message %s', delivery_tag)
        self._channel.basic_ack(delivery_tag)

    def _on_connection_open(self, connection):

        LOGGER.info('Connection opened')
        self._open_channel()

    def _on_connection_closed(self, connection, reply_code, reply_text):

        self._channel = None

        if self._closing:
            self._connection.ioloop.stop()
        else:
            LOGGER.warning('Connection closed, reopening in 5 seconds: (%s) %s', eply_code, reply_text)
            self._connection.add_timeout(self_retry_interval, self._reconnect)

    def _reconnect(self):
        self._connection.ioloop.stop()

        if not self._closing:
            self.run()

    def _on_channel_open(self, channel):
        LOGGER.info('Channel opened')
        channel.basic_qos(prefetch_count=10)
        self._channel = channel
        self._add_on_channel_close_callback()
        self._setup_exchange(self._exchange_name, self._exchange_type)

    def _add_on_channel_close_callback(self):

        LOGGER.info('Adding channel close callback')
        self._channel.add_on_close_callback(self._on_channel_closed)

    def _on_channel_closed(self, channel, reply_code, reply_text):

        LOGGER.warning('Channel %i was closed: (%s) %s', channel, reply_code, reply_text)

        self._channel = None
        self._connection.close()

    def add_on_cancel_callback(self):
        LOGGER.info('Adding consumer cancellation callback')
        self._channel.add_on_cancel_callback(self.on_consumer_cancelled)

    def on_consumer_cancelled(self, method_frame):

        LOGGER.info('Consumer was cancelled remotely, shutting down: %r', method_frame)

        if self._channel:
            self._channel.close()

    def _stop_consuming(self):

        if self._channel:
            LOGGER.info('Sending a Basic.Cancel RPC command to RabbitMQ')
            self._channel.basic_cancel(self._on_cancel, self._consumer_tag)

    def _on_cancel(self, frame):

        LOGGER.info('RabbitMQ acknowledged the cancellation of the consumer')
        self._close_channel()

    def _close_channel(self):

        LOGGER.info('Closing the channel')
        self._channel.close()

    def run(self):

        LOGGER.info('Running')
        self._connection = self._connect()
        self._connection.ioloop.start()

    def stop(self):

        LOGGER.info('Stopping')
        self._closing = True
        self._stop_consuming()
        self._connection.ioloop.start()
        LOGGER.info('Stopped')

    def bind_to(self, callback):

        LOGGER.info('Bind callback')
        if callback:
            self._observers.append(callback)


class Publisher:
    def __init__(self, url, queue_name="queue", routing_key="queue", exchange_name='topic_exchange',
                 exchange_type='topic',
                 publish_interval=1, retry_interval=5):

        self._url = url
        self._queue_name = queue_name
        self._routing_key = routing_key
        self._exchange_name = exchange_name
        self._exchange_type = exchange_type
        self._publish_interval = publish_interval
        self._retry_interval = retry_interval

        self._connection = None
        self._channel = None
        self._stopping = False
        self._deliveries = None
        self._acked = None
        self._nacked = None
        self._message_number = None

    def _connect(self):

        LOGGER.info('Connecting to %s', self._url)
        return pika.SelectConnection(pika.URLParameters(self._url),
                                     on_open_callback=self._on_connection_open,
                                     on_close_callback=self._on_connection_closed,
                                     stop_ioloop_on_close=False)

    def _on_connection_open(self, unused_connection):

        LOGGER.info('Connection opened')

        self._open_channel()

    def _on_connection_closed(self, connection, reply_code, reply_text):

        self._channel = None

        if self._stopping:
            self._connection.ioloop.stop()
        else:
            LOGGER.warning('Connection closed, reopening in %d seconds: (%s) %s',
                           self._retry_interval, reply_code, reply_text)

            self._connection.add_timeout(self._retry_interval, self._connection.ioloop.stop)

    def _open_channel(self):

        LOGGER.info('Creating a new channel')

        self._connection.channel(on_open_callback=self._on_channel_open)

    def _on_channel_open(self, channel):

        LOGGER.info('Channel opened')

        self._channel = channel
        self._add_on_channel_close_callback()
        self._setup_exchange(self._exchange_name, self._exchange_type)

    def _add_on_channel_close_callback(self):

        LOGGER.info('Adding channel close callback')

        self._channel.add_on_close_callback(self._on_channel_closed)

    def _on_channel_closed(self, channel, reply_code, reply_text):

        LOGGER.warning('Channel was closed: (%s) %s', reply_code, reply_text)

        self._channel = None

        if not self._stopping:
            self._connection.close()

    def _setup_exchange(self, exchange_name, exchange_type):

        LOGGER.info('Declaring exchange %s %s', exchange_name, exchange_type)

        self._channel.exchange_declare(self._on_exchange_declare,
                                       exchange_name,
                                       exchange_type)

    def _on_exchange_declare(self, frame):

        LOGGER.info('Exchange declared')

        self._setup_queue(self._queue_name)

    def _setup_queue(self, queue_name):

        LOGGER.info('Declaring queue %s', queue_name)

        self._channel.queue_declare(self._on_queue_declare, queue_name)

    def _on_queue_declare(self, method_frame):

        LOGGER.info('Binding %s to %s with %s',
                    self._exchange_name, self._queue_name, self._routing_key)

        self._channel.queue_bind(self._on_bind,
                                 self._queue_name,
                                 self._exchange_name,
                                 self._routing_key)

    def _on_bind(self, frame):

        LOGGER.info('Queue bound')

        self._start_publishing()

    def _start_publishing(self):

        LOGGER.info('Issuing consumer related RPC commands')

        self._enable_delivery_confirmations()
        self._schedule_next_message()

    def _enable_delivery_confirmations(self):

        LOGGER.info('Issuing Confirm.Select RPC command')

        self._channel.confirm_delivery(self._on_delivery_confirmation)

    def _on_delivery_confirmation(self, method_frame):

        confirmation_type = method_frame.method.NAME.split('.')[1].lower()

        LOGGER.info('Received %s for delivery tag: %i',
                    confirmation_type,
                    method_frame.method.delivery_tag)

        if confirmation_type == 'ack':
            self._acked += 1
        elif confirmation_type == 'nack':
            self._nacked += 1

        self._deliveries.remove(method_frame.method.delivery_tag)

        LOGGER.info('Published %i messages, %i have yet to be confirmed, '
                    '%i were acked and %i were nacked',
                    self._message_number, len(self._deliveries),
                    self._acked, self._nacked)

    def _schedule_next_message(self):

        LOGGER.info('Scheduling next message for %0.1f seconds',
                    self._publish_interval)

        self._connection.add_timeout(self._publish_interval,
                                     self.publish_message)

    def publish_message(self):

        if self._channel is None or not self._channel.is_open:
            return

        message = {"Host": "192.168.0.202"}

        properties = pika.BasicProperties(app_id='example-publisher',
                                          content_type='application/json',
                                          headers=message)

        self._channel.basic_publish(self._exchange_name, self._routing_key,
                                    json.dumps(message, ensure_ascii=False),
                                    properties)

        self._message_number += 1

        self._deliveries.append(self._message_number)

        LOGGER.info('Published message # %i', self._message_number)
        self._schedule_next_message()
        # self.stop()

    def run(self):

        while not self._stopping:

            self._connection = None
            self._deliveries = []
            self._acked = 0
            self._nacked = 0
            self._message_number = 0

            try:
                self._connection = self._connect()
                self._connection.ioloop.start()
            except KeyboardInterrupt:

                self.stop()
                if (self._connection is not None and not self._connection.is_closed):
                    self._connection.ioloop.start()

        LOGGER.info('Stopped')

    def stop(self):

        LOGGER.info('Stopping')
        self._stopping = True
        self._close_channel()
        self._close_connection()

    def _close_channel(self):

        if self._channel is not None:
            LOGGER.info('Closing the channel')
            self._channel.close()

    def _close_connection(self):

        if self._connection is not None:
            LOGGER.info('Closing connection')
            self._connection.close()
