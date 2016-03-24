#!/bin/bash
cd $(dirname $0)/ansible
ansible-playbook module/delete_blob.yml
