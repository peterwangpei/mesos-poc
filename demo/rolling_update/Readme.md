
## 1. 创建 nginx rc1

~~~~~~
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-ingress
  labels:
    name: nginx-ingress
spec:
  replicas: 1
  selector:
    name: nginx-ingress
    version: v1                # v1 是这个服务的版本 
  template:
    metadata:
      labels:
        name: nginx-ingress
        version: v1            # 版本
    spec:
      containers:
      - image: library/nginx:alpine
        name: nginx-ingress
        ports:
        - containerPort: 80
          hostPort: 3333
          name: public
~~~~~~

## 2. 创建 nginx_service，指向到 rc1

~~~~~~
apiVersion: v1
kind: Service
metadata:
  labels:
    name: nginx-ingress
  name: nginx-ingress
spec:
  ports:
    - port: 80
  selector:
    name: nginx-ingress
    version: v1           # 版本
~~~~~~

## 3. 开始 update

创建 nginx_rc_v2

~~~~~~
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-ingress-v2
  labels:
    name: nginx-ingress
spec:
  replicas: 1
  selector:
    name: nginx-ingress
    version: v2           # 新版本标示
  template:
    metadata:
      labels:
        name: nginx-ingress
        version: v2       # 新版本标示
    spec:
      containers:
      - image: library/nginx:alpine
        name: nginx-ingress
        ports:
        - containerPort: 80
          hostPort: 3334
          name: public
~~~~~~

## 4. 切换服务指向到 rc2

~~~~~~
kubectl -s http://localhost:8085 patch svc nginx-ingress -p '{"spec": {"selector": {"version": "v2", "name": "nginx-ingress"}}}'
~~~~~~

以上命令 就是修改了 service selector, 最终结果如下

~~~~~~
apiVersion: v1
kind: Service
metadata:
  labels:
    name: nginx-ingress
  name: nginx-ingress
spec:
  ports:
    - port: 80
  selector:
    name: nginx-ingress
    version: v2           # 版本
~~~~~~

## 5. 销毁 rc v1
