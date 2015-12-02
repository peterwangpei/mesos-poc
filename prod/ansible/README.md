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

Run command `ansible-playbook -i poc playbook.yml`
