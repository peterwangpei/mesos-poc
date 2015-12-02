## install ansible 

Ubuntu install ansible:

~~~~~~
$ sudo apt-get install software-properties-common
$ sudo apt-add-repository ppa:ansible/ansible
$ sudo apt-get update
$ sudo apt-get install ansible
~~~~~~

CentOS install ansible: 

~~~~~~
$ sudo yum install ansible
~~~~~~

Run command `ansible-playbook -i ansible_inventory mesos_playbook.yml` to install docker and run mesos cluster
Run command `ansible-playbook -i ansible_inventory k8s_playbook.yml` to run kubernetes master as mesos framework
