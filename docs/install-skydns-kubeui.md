
请先搭建 k8s-mesos 集群

需要用到的镜像

~~~~~~
# 以下镜像因为 需要用到 谷歌的地址，所以在dockerhub上做了一个拷贝
zhpooer/etcd:2.0.9
zhpooer/kube2sky:1.11
zhpooer/skydns:2015-10-13-8c72f8c

zhpooer/kube-ui:v2
~~~~~~

# install Kubeui

[官方参考文档](https://github.com/kubernetes/kubernetes/blob/master/docs/getting-started-guides/mesos.md#launching-kube-dns)

创建文件 `skydns.yaml`, 按键如下变量替换模板文件

~~~~~~
k8s_cluster_ip_range: 10.10.10.0/24
k8s_dns_server: 10.10.10.10
k8s_dns_replicas: 1
k8s_dns_domain: cluster.local
~~~~~~

`skydns.yaml`

~~~~~~
---
apiVersion: v1
kind: ReplicationController
metadata:
  name: kube-dns-v9
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    version: v9
    kubernetes.io/cluster-service: "true"
spec:
  replicas: {{ k8s_dns_replicas }}
  selector:
    k8s-app: kube-dns
    version: v9
  template:
    metadata:
      labels:
        k8s-app: kube-dns
        version: v9
        kubernetes.io/cluster-service: "true"
    spec:
      containers:
      - name: etcd
        image: zhpooer/etcd:2.0.9
        resources:
          limits:
            cpu: 100m
            memory: 50Mi
        command:
        - /usr/local/bin/etcd
        - -data-dir
        - /var/etcd/data
        - -listen-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -advertise-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -initial-cluster-token
        - skydns-etcd
        volumeMounts:
        - name: etcd-storage
          mountPath: /var/etcd/data
      - name: kube2sky
        image: zhpooer/kube2sky:1.11
        resources:
          limits:
            cpu: 100m
            memory: 50Mi
        args:
        # command = "/kube2sky"
        - -kube_master_url={{k8s_api_server_lb_url}}
        - -domain={{k8s_dns_domain}}
      - name: skydns
        image: zhpooer/skydns:2015-10-13-8c72f8c
        resources:
          limits:
            cpu: 100m
            memory: 50Mi
        args:
        # command = "/skydns"
        - -machines=http://127.0.0.1:4001
        - -addr=0.0.0.0:53
        - -ns-rotate=false
        - -domain={{ k8s_dns_domain }}.
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 1
          timeoutSeconds: 5
      - name: healthz
        image: zhpooer/exechealthz:1.0
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
        args:
        - -cmd=nslookup kubernetes.default.svc.{{ k8s_dns_domain }} localhost >/dev/null
        - -port=8080
        ports:
        - containerPort: 8080
          protocol: TCP
      volumes:
      - name: etcd-storage
        emptyDir: {}
      dnsPolicy: Default  # Don't use cluster DNS.


---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "KubeDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP:  "{{ k8s_dns_server }}"
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP

~~~~~~

运行命令

~~~~~~
kubectl create -f skydns.yaml -s --server=http://#{负载均衡地址}:#{k8s_api_server_lb_port}
~~~~~~

可以在 `http://mesos-master:5050` 看到 skydns 的运行状况

# Install kubeui

1. 按照如下模板创建文件 `kube-ui.yaml`
2. 运行命令 `kubectl create -f kube-ui.yaml -s --server=http://#{负载均衡地址}:#{k8s_api_server_lb_port}`
3. 运行成功以后，可以查看 `http://#{负载均衡地址}:#{k8s_api_server_lb_port}/ui` 


~~~~~~
---

apiVersion: v1
kind: ReplicationController
metadata:
  name: kube-ui-v2
  namespace: kube-system
  labels:
    k8s-app: kube-ui
    version: v2
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 1
  selector:
    k8s-app: kube-ui
    version: v2
  template:
    metadata:
      labels:
        k8s-app: kube-ui
        version: v2
        kubernetes.io/cluster-service: "true"
    spec:
      containers:
      - name: kube-ui
        image: zhpooer/kube-ui:v2
        resources:
          limits:
            cpu: 100m
            memory: 50Mi
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          timeoutSeconds: 5

---

apiVersion: v1
kind: Service
metadata:
  name: kube-ui
  namespace: kube-system
  labels:
    k8s-app: kube-ui
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "KubeUI"
spec:
  selector:
    k8s-app: kube-ui
  ports:
  - port: 80
    targetPort: 8080

~~~~~~


