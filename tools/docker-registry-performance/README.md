# Docker镜像仓库性能测试工具
## 前提
1. 需要镜像仓库准备完毕。由于性能测试将往镜像仓库push大量镜像，而docker registry v2仅支持软删除，并不支持在存储级别上删除镜像，所以建议镜像仓库不与生产环境混用，而是使用独立存储，性能测试完成后将镜像仓库及存储一并删除。
2. 需要准备用于性能测试并安装好docker的客户机。将在客户机上生成指定数量、大小的镜像并push到镜像仓库。目前支持的客户机如下：
  - Ubuntu：docker使用upstart方式启动
  - CentOS：docker使用systemd方式启动
3. 运行test.sh命令的机器上需要安装ansible

## 用法
1. 配置ansible/inventory文件，指定用于性能测试的客户机、镜像仓库地址、单客户机的镜像数量和镜像的大小（单位：MB）
2. 运行test.sh
3. 在控制台上查看运行结果

## 原理
通过ansible在客户机上的docker daemon启动参数里增加`--insecure-registry`来允许客户机push到指定镜像仓库里。之后使用`dd if=/dev/zero`命令生成指定大小的文件并生成一个只含有uuid的随机文件，再将这两个文件通过`docker build`打包到镜像里。通过这样的方式，能保证镜像的大小和随机性。当指定数量的镜像生成结束后，开始计时每个镜像push所耗时间，并将结果写入`/tmp/milliseconds.csv`文件里。最后收集文件内容并计算50%、90%、95%和100%的镜像push耗时，精确到毫秒。

以下是一个运行结果示例（2台客户机，分别是Ubuntu和CentOS，每台客户机10个镜像，每个镜像5Mb）：
```
[143 154 155 155 160 162 164 169 179 183 183 184 186 189 194 195 195 197 201 240]
50% images pushed in 183 milliseconds
90% images pushed in 197 milliseconds
95% images pushed in 201 milliseconds
100% images pushed in 240 milliseconds
```
