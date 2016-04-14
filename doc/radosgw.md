# 使用RADOSGW提供ceph的S3和Swift接口
由于Docker Registry在2.4版本[移除了对rados的支持](https://github.com/docker/distribution/commit/5967d333425a8dd5d36c5bb456098839654d38af)，所以如果使用ceph作为后端存储就需要利用RADOSGW了。本文介绍了通过RADOSGW来实现S3和OpenStack Swift存储接口的方法。

## 前提条件

- ceph已经安装完成，用户拥有管理员权限
- 操作系统为ubuntu，理论上CentOS也行，但没有经过验证
- 为配置简单起见，ceph和apache2将被安装在同一台机器上

## 搭建环境
首先需要安装一些ceph、radosgw的依赖包，还有python-boto、swift客户端等工具可以用于测试。
```sh
sudo apt-get update
sudo apt-get -y --force-yes install ceph-common radosgw python-boto
sudo pip install --upgrade setuptools
sudo pip install --upgrade python-swiftclient
```

接下来需要为radosgw生成一个名为`gateway`的用户：
```sh
sudo ceph auth del client.radosgw.gateway
sudo ceph auth get-or-create client.radosgw.gateway osd 'allow rwx' mon 'allow rwx' -o /etc/ceph/ceph.client.radosgw.keyring
```

然后需要把这个用户加到`ceph.conf`配置里，提供端口为9000的[FastCGI](https://en.wikipedia.org/wiki/FastCGI)服务：
```sh
sudo sed -i '$a [client.radosgw.gateway]' /etc/ceph/ceph.conf
sudo sed -i '$a host = vagrant-ubuntu-trusty-64' /etc/ceph/ceph.conf
sudo sed -i '$a keyring = /etc/ceph/ceph.client.radosgw.keyring' /etc/ceph/ceph.conf
sudo sed -i '$a rgw socket path = ""' /etc/ceph/ceph.conf
sudo sed -i '$a log file = /var/log/radosgw/client.radosgw.gateway.log' /etc/ceph/ceph.conf
sudo sed -i '$a rgw frontends = fastcgi socket_port=9000 socket_host=0.0.0.0' /etc/ceph/ceph.conf
sudo sed -i '$a rgw print continue = false' /etc/ceph/ceph.conf
```

然后重新启动radosgw：
```sh
sudo /etc/init.d/radosgw start
```

为了提供HTTP服务，需要安装apache2（CentOS系是httpd）：
```sh
sudo apt-get -y --force-yes install apache2
```

接下来创建一个apache2的配置文件，监听80端口并把请求转发到radosgw提供的FastCGI 9000端口上：
```sh
cat << EOF > rgw.conf
<VirtualHost *:80>
ServerName localhost
DocumentRoot /var/www/html

ErrorLog /var/log/apache2/rgw_error.log
CustomLog /var/log/apache2/rgw_access.log combined

# LogLevel debug

RewriteEngine On

RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization},L]

SetEnv proxy-nokeepalive 1

ProxyPass / fcgi://localhost:9000/

</VirtualHost>
EOF

sudo mv rgw.conf /etc/apache2/conf-enabled/rgw.conf
```

由于上述配置需要用到一些apache2默认未加载的模块，所以需要加载并重新启动apache2：
```sh
sudo a2enmod rewrite
sudo a2enmod proxy_http
sudo a2enmod proxy_fcgi
sudo service apache2 restart
```

## 测试服务
### S3
RADOSGW的基本配置已经完成，现在我们测试一下s3接口（对于registry来说，可以不用管S3，但是需要创建s3用户，以便用其创建swift用户，所以建议顺便测一下）。它的存储模型是这样的：用户可以创建和管理多个[存储桶（bucket）](http://docs.aws.amazon.com/zh_cn/AmazonS3/latest/dev/UsingBucket.html)，每个存储桶里可以存放无限多个对象（object），每个对象是一个键值对。存储桶的名称与区域无关，全球唯一。

接下来先创建一个s3用户（就算不测试s3也需要执行）：
```sh
radosgw-admin user create --uid="testuser" --display-name="First User" | tee user.txt
export ACCESS_KEY=`cat user.txt | sed -n 's/ *"access_key": "\(.*\)",/\1/p'`
export SECRET_KEY=`cat user.txt | sed -n 's/ *"secret_key": "\(.*\)"/\1/p'`
export IPADDR="用apache2服务器的IP代替"
```

使用以下python代码来测试我们的s3接口是否已经可用：
```sh
cat << EOF > s3test.py
import boto
import boto.s3.connection
import os

access_key = os.environ["ACCESS_KEY"]
secret_key = os.environ["SECRET_KEY"]
ipaddr = os.environ["IPADDR"]
conn = boto.connect_s3(
aws_access_key_id = access_key,
aws_secret_access_key = secret_key,
host = ipaddr,
is_secure=False,
calling_format = boto.s3.connection.OrdinaryCallingFormat(),
)
bucket = conn.create_bucket('my-new-bucket')
for bucket in conn.get_all_buckets():
    print "{name}\t{created}".format(
        name = bucket.name,
        created = bucket.creation_date,
)
EOF

python s3test.py
```

如果显示了`my-new-bucket`，那就说明测试成功地通过s3接口创建了一个存储桶。

### Swift
接下来测试swift。对于swift来说，它的存储模型是这样的：一个账号（account）里可以有多个容器（container），容器里可以有许多个键值对，字典里的值称为对象（object）。账号和容器被存储在SQLite数据库里，而对象是以文件方式存储的。

首先需要创建swift用户并生成secret：
```sh
radosgw-admin subuser create --uid=testuser --subuser=testuser:swift --access=full
radosgw-admin key create --subuser=testuser:swift --key-type=swift --gen-secret | tee subuser.txt
export PASSWORD=`cat subuser.txt | sed -n '/testuser:swift/{N;p;}' | sed -n 's/ *"secret_key": "\(.*\)"/\1/p'`
```

然后就可以用以下命令查看swift里所有的容器：
```sh
export AUTHURL="http://$IPADDR/auth/v1.0"
swift -A http://$IPADDR/auth/v1.0 -U testuser:swift -K $PASSWORD list
```

应该能看到刚才测试s3接口时创建的`my-new-bucket`，在这里s3的存储桶和swift的容器是同一个概念。

## 配置Docker Registry
根据[Won't support ceph rados anymore](https://github.com/docker/distribution/issues/1541)里的回答，目前版本的Ceph还不支持s3的v4认证，所以我们使用Swift接口。在Docker Registry的`config.yml`的`storage`里使用以下配置：
```
  swift:
    username: testuser:swift
    password: 用echo $PASSWORD的结果代替
    authurl: 用echo $AUTHURL的结果代替
    container: swift
```

这里的username是创建的swift用户，password是生成的secret_key，authurl跟上面查看swift里所有容器的url一致，container可以自行设置，不重复即可。然后重新启动docker。可以开始`docker push`测试了。
