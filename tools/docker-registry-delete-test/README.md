# Docker镜像仓库删除测试工具
## 前提
1. 所有机器都安装了docker并启动完毕，客户机已连接上指定的镜像仓库
2. 镜像仓库主机上，registry的镜像（现在的2.2或2.3版）和删除registry的镜像（未来的2.4或自己编译的master版）可以用`docker images`查看到
3. 运行test.sh命令的机器上需要安装ansible

## 用法
1. 配置ansible/inventory文件，指定镜像仓库主机、客户机、镜像仓库地址、镜像仓库存储位置、registry的镜像和删除registry的镜像
2. 运行test.sh
3. 在控制台上查看运行结果

## 原理
在客户机上创建几个（默认为3个）随机镜像，其中tag分别是1，2... Tag为1的是基础的父镜像，其他的所有镜像都是在其基础上的镜像。Push完镜像后，一个个地删除镜像的manifest和blob，查看剩余占用空间。详细步骤可以查看[test.yml](/ansible/module/test.yml)文件。

以下是一个运行结果示例（先push 3个镜像，tag分别是1，2和3。其中2和3是建立在1的基础上。先删除3的manifest，然后删除3的blob，然后是2，最后是1）：
```
4k after initial
416k after pushed 3 images
412k after deleted 1 child image manifest
380k after deleted 1 child image blob
376k after deleted 1 child image manifest
344k after deleted 1 child image blob
340k after deleted 1 parent image manifest
292k after deleted 1 parent image blob
```

## 可能出现的问题
1. 如果删除镜像后重新push之后，有小概率（20%左右）出现不能通过GET manifest by tag API查看到这个镜像的问题
2. 如果删除镜像后重新push之后，再次删除时会出现提示unknown blob的错误，这个是由于DELETE manifest API仅删除manifest，没删除signature导致的，不过没有太大影响
3. 删除blob的时候，由于需要设置registry为只读模式，需要停止一下registry。虽然时间短暂，但是有可能导致正在上传的镜像上传失败。Blob删除完成的时候，由于需要取消registry的只读模式，也需要停止一下registry。虽然时间短暂，但是有可能导致正在下载的镜像下载失败
