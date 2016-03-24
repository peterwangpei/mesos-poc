#!/usr/bin/env python
import logging
from ansible.playbook import PlayBook
from ansible.inventory import Inventory
from ansible import callbacks
from ansible import utils

LOGGER = logging.getLogger(__name__)

utils.VERBOSITY = 0
playbook_cb = callbacks.PlaybookCallbacks(verbose=utils.VERBOSITY)
stats = callbacks.AggregateStats()
runner_cb = callbacks.PlaybookRunnerCallbacks(stats, verbose=utils.VERBOSITY)

__version__ = "1.0.0"
__all__ = ['Ansible']


class Ansible:
    def Test(self,host):
        playbook = PlayBook(playbook='/Users/ezeng/Development/mesos-poc/vm_booting/playbook.yml',
                            # inventory=Inventory('/Users/ezeng/Development/mesos-poc/vm_booting/ansible/inventory'),
                            host_list=host.split(","),
                            callbacks=playbook_cb,
                            runner_callbacks=runner_cb,
                            stats=stats)
        playbook.run()
