kubectl delete rc --all --server=http://192.168.33.11
kubectl delete svc --all --server=http://192.168.33.11
kubectl delete pv --all --server=http://192.168.33.11
kubectl delete pvc --all --server=http://192.168.33.11
kubectl delete ingress --all --server=http://192.168.33.11
kubectl delete rc --namespace=kube-system --all --server=http://192.168.33.11
kubectl delete svc --namespace=kube-system --all --server=http://192.168.33.11
kubectl delete secret --all --server=http://192.168.33.11
