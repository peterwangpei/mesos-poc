# 将MySQL部署在CephFS

## 启动Ceph
	
	docker run -d \
	  --net=host \
	  --privileged \
	  -v /etc/ceph:/etc/ceph \
	  -v /var/log/radosgw:/var/log/radosgw \
	  -e MON_IP=$MON_IP \
	  -e CLUSTER=ceph \
	  -e RGW_NAME=radosgw \
	  -e CEPH_NETWORK=192.168.0.0/24 \
	  --name=ceph \
	  ceph/demo
  
## 创建用户（可选）
当Ceph容器启动之后，可以使用如下命令创建用户

	ceph auth get-or-create client.demo  mon 'allow *' osd 'allow *' -o /etc/ceph/ceph.client.demo.keyring
	
## 创建Secret
通过如下的命令获得keyring中保存的Key
	
	cat /etc/ceph/ceph.client.demo.keyring | sed -n 's/^.*key *= *//p' | base64
	
命令执行之后，会生成类似下面结果的字符串

	QVFCTkxqeFgrTCt2SlJBQWx0OC9aUlpMbWM5RUxlMUxTeVpxamc9PQo=

然后根据下面的配置创建一个Secret，其中Key部分的值为上一个步骤生成的字符串
	
	apiVersion: v1
	kind: Secret
	metadata:
	  name: ceph-secret
	data:
	  key: QVFCTkxqeFgrTCt2SlJBQWx0OC9aUlpMbWM5RUxlMUxTeVpxamc9PQo=
	  
## 启动MySQL Master
使用Kubernete启动Master

	apiVersion: v1
	kind: Pod
	metadata:
	  name: master
	spec:
	  containers:
	    - name: master
	      image: daocloud.io/library/mysql:5.5.49
	      ports:
	        - containerPort: 3306
	          hostPort: 3306
	      volumeMounts:
	        - mountPath: "/data"
	          name: cephfs
	        - mountPath: "/etc/mysql/conf.d"
	          name: conf
	      env:
	        - name: "MYSQL_ROOT_PASSWORD"
	          value: "xA123456"
	
	  volumes:
	    - name: conf
	      hostPath:
	        path: /etc/master
	    - name: cephfs
	      cephfs:
	        monitors:
	          - 192.168.0.160:6789
	        user: admin
	        secretRef:
	          name: ceph-secret
	        readOnly: false

在/etc/master下创建一个具有以下内容的配置文件，在本例中命名为master.conf：
   
	[mysqld]
	log-bin=mysql-bin
	server-id=1
	datadir=/data/master

*注意：由于目前版本Kubernetes的Bug，不能挂接CephFS的目录，所以需要修改MySQL的数据目录（datadir）*
        
## 启动MySQL Slave
采用与Master类似的方式启动Slave，需要注意的是配置文件中`server-id`的值不能重复。
## 创建同步用户
连接到MySQL Master容器
	
	docker exec -it $CONTAINER_ID sh
连接MySQL

	mysql -u"$USER" -p"$PASSWORD"
创建用户

	CREATE USER 'mysync' IDENTIFIED BY 'xA123456';

## 同步授权
接上面的命名

	GRANT REPLICATION SLAVE ON *.* TO 'mysync';
## 检查Master的状态
显示Master的状态之后，在后续步骤完成之前，不要做任何操作，以避免日志的位置发生变更

	show master status;
	
## 配置从数据库
在MySQL Slave上执行下面的命令
	
	change master to master_host='$MASTER_IP',master_user='mysync',master_password='xA123456',master_log_file='上一个步骤显示的日志名称',master_log_pos=上一个步骤显示的日志位置;

## 启动同步功能

	start slave;
## 检查同步状态
使用下面的命令查看同步状态，如果同步状态都显示正常，则表示同步已经设置成功，至此设置工作已经完成，后续开始测试同步。

	show slave status\G
## 在Master上创建数据库
	create database demo;
## 在Master上创建表
	//切换数据库
	use demo;
	//创建表
	create table user(id int(3),name char(10));
	//查看数据库
	show databases;
## 在Master上插入数据
可以使用下面的Python批次插入数据
	
	#!/usr/bin/env python
	import MySQLdb
	
	db = MySQLdb.connect("$MASTER_IP", "$USEr", "$PASSWORD", "demo")
	
	cursor = db.cursor()
	
	for index in range(0, 100):
	    sql = "insert into user values" + "(" + str(index) + ",'" + str(index) + "')"
	    cursor.execute(sql)
	
	try:
	    db.commit()
	except:
	    db.rollback()
	
	db.close()
## 在Slave中查看插入的数据
如果一切顺利，那么在Slave中可以看到在Master中插入的数据。

## 使用RBD
1. 创建池
		
		ceph osd pool create kube 16 16
2. 创建镜像
	
		rbd create kube --size 1024 --pool kube
3. 将RBD挂载到Pod中

		apiVersion: v1
		kind: Pod
		metadata:
		  name: cephfs4
		spec:
		  containers:
		    - name: cephfs-rw
		      image: nginx:1.9.11
		      volumeMounts:
		        - mountPath: "/mnt/rbd"
		          name: rbd
		  volumes:
		    - name: rbd
		      rbd:
		        monitors:
		          - 192.168.0.160:6789
		        user: admin
		        pool: kube
		        image: kube
		        fsType: ext4
		        keyring: ""
		        secretRef:
		          name: ceph-secret
		        readOnly: false
		        

## 在线动态调整镜像尺寸
1. 调整镜像尺寸

		rbd resize --image kube --pool kube --size 4096

2. 到Pod运行的主机，找到RBD挂载的块设备

		mount | grep $卷名/$池名-image-$镜像名 
		
		执行的结构可能如下：
		/dev/rbd1 on /var/lib/kubelet/plugins/kubernetes.io/rbd/rbd/kube-image-kube type ext4 (rw)
		
3. 扩展文件系统
		
		sudo resize2fs $挂载点 

## 使用XFS文件系统

1. 安装XFS文件系统支持
	
		apt-get install xfsprogs
2. 创建镜像
 
		rbd create xfs --size 1024 --pool kube
3. 将RBD挂载到Pod中

		apiVersion: v1
		kind: Pod
		metadata:
		  name: cephfs4
		spec:
		  containers:
		    - name: cephfs-rw
		      image: nginx:1.9.11
		      volumeMounts:
		        - mountPath: "/mnt/rbd"
		          name: rbd
		  volumes:
		    - name: rbd
		      rbd:
		        monitors:
		          - 192.168.0.160:6789
		        user: admin
		        pool: kube
		        image: kube
		        fsType: ext4
		        keyring: ""
		        secretRef:
		          name: ceph-secret
		        readOnly: false
		        
4.　按照上述方式调整镜像大小

5.　调整文件系统

	sudo xfs_growfs $挂载点
	
*注意：只有以非只读方式挂载的文件系统才能够调整*