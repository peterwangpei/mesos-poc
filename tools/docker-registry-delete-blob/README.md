# Docker镜像仓库blob删除工具
## 前提
1. 所有机器都安装了docker并启动完毕，docker registry已经启动完毕，并且连接到rados存储上
2. 在delete主机上，用于删除registry的镜像（未来的2.4或自己编译的master版）可以用`docker images`查看到
3. 运行delete_blob.sh命令的机器上需要安装ansible
4. 有另外的机制（手动或自动）去删除不再使用的镜像的manifest
5. 目前，docker registry的config.yml文件中，storage的下一段必须是http。另外，yml文件的缩进必须是两个空格

## 用法
1. 配置ansible/inventory文件，指定镜像仓库主机（可以为多台）、执行删除blob的主机（只能为一台）、registry容器名、registry配置路径、ceph配置路径和删除registry的镜像
2. 手动运行delete_blob.sh，或者是通过定时任务运行delete_blob.sh

## 原理
先将所有的registry实例停止，再通过设置registry配置文件的maintenance启动为只读模式。然后运行[gc](https://github.com/docker/distribution/blob/master/docs/gc.md)的镜像来删除blob。最后再停止所有的registry实例，删除registry配置文件的maintenance启动为读写模式，恢复原状。
