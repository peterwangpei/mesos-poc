# 准备工作 #

先在本机安装 vagrant 运行环境，以及 ansible

1. 设置 ansible.cfg , 这个文件是设置 登陆到 vagrant 虚拟机的私钥，请关注 `private_key_file`, 一般不用设置
2. 执行 `vagrant up m1 s1`, 运行 kubernetes 最小环境（一台 master，一台 minion），也可以启动所有 `vagrant up`
  * `reg` 机器是用来 运行 registry，主要是为了缓存一些镜像，可以不启动，安装 docker registry 请运行命令 `ansible-playbook -i registry.yml`, 运行前要先在 `ansible_inventory` 里面声明 registry 这台机器。
  * `misc` 暂时无用
3. 设置 `ansible_inventory` 这个文件, 主要配置 `docker_opts` 这个选项，这个变量是用来设置 docker 的启动配置的，如果没有安装本地的 registry 请注释掉。


# 开始安装 #

> 因为安装过程需要下载很多的镜像，以及很多的安装文件， 需要很好的网络带宽，必要时可能需要翻墙。具体请查看 `kubernetes.yml`

运行 `ansible-playbook -i kubernetes.yml`

运行 `ansible-playbook -i addons.yml`
