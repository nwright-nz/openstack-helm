#!/bin/bash

kubectl create ns openstack
echo "Preparing rook to be used by openstack..."
echo ""
echo ""

values=$(kubectl get svc -n rook -l 'app=rook-ceph-mon' -o jsonpath='{range .items[*]}{@.spec.clusterIP}{":"}{@.spec.ports[*].port}{" "}' | sed "s/ /,/g")
names=$(kubectl get svc -n rook -l 'app=rook-ceph-mon' -o jsonpath={.items[*].metadata.name})
fsid=$(kubectl get secret rook-ceph-mon -n rook -o jsonpath={.data.fsid} | base64 --decode)
clusterIP=$(kubectl get  endpoints rook-ceph-mon0 -n rook -o jsonpath={.subsets[*].addresses[*].ip})
svcIP=$(kubectl get svc rook-ceph-mon0 -n rook -o jsonpath={.spec.clusterIP})
adminSecret=$(kubectl get secret rook-ceph-mon -n rook -o jsonpath={.data.admin-secret} | base64 --decode)
monSecret=$(kubectl get secret rook-ceph-mon -n rook -o jsonpath={.data.mon-secret} | base64 --decode )
clusterName=$(kubectl get secret rook-ceph-mon -n rook -o jsonpath={.data.cluster-name} | base64 --decode )

sed "s/{{rook_cluster_name}}/$clusterName/g; s/{{mon_host}}/${values::-1}/g; s:{{rook_mon_key}}:$monSecret:g; s:{{rook_admin_key}}:$adminSecret:g; s/{{fsid}}/$fsid/g; s/{{mon_names}}/$names/g; s/{{cluster_address}}/$clusterIP/g; s/{{service_address}}/$svcIP/g" ./rook-utils/templates/rook-ceph-conf.yaml > ./rook-utils/rook-ceph-conf-cm.yaml
#sed -i "s/{{mon_names}}/$names/g" storage-template.yaml
#sed -i "s/{{cluster_address}}/$clusterIP/g" storage-template.yaml
#sed -i "s/{{service_address}}/$svcIP/g" storage-template.yaml


echo ""
echo "Creating keyring data in openstack namespace..."
echo ""

sed  "s:{{rook_mon_key}}:$monSecret:g; s:{{rook_admin_key}}:$adminSecret:g" ./rook-utils/templates/keyring.yaml > ./rook-utils/keyring-cm.yaml
kubectl create -f ./rook-utils/
echo ""
echo""
echo "----------------------------------"
echo "Beginnning Openstack Install"
echo "----------------------------------"

helm install --name=mariadb ./mariadb --namespace=openstack
echo ""
echo "Waiting for Maria DB to come up (this may take a while)"
echo ""
while [ "$(kubectl get statefulset -n openstack -o jsonpath={.items[*].status.replicas})" != "$(kubectl get statefulset -n openstack -o jsonpath={.items[*].status.readyReplicas})" ]; do echo "Still waiting for replicas to create.."; sleep 20; done

helm install --name=memcached ./memcached --namespace=openstack
helm install --name=etcd-rabbitmq ./etcd --namespace=openstack
helm install --name=rabbitmq ./rabbitmq --namespace=openstack
helm install --name=ingress ./ingress --namespace=openstack
helm install --name=libvirt ./libvirt --namespace=openstack
helm install --name=openvswitch ./openvswitch --namespace=openstack
helm install --namespace=openstack --name=keystone ./keystone \
  --set pod.replicas.api=2
helm install --namespace=openstack --name=horizon ./horizon \
  --set network.enable_node_port=true
GLANCE_BACKEND="rook" helm install --namespace=openstack --name=glance ./glance \
  --set pod.replicas.api=2 \
  --set pod.replicas.registry=2 \
  --set storage=${GLANCE_BACKEND}
helm install --namespace=openstack --name=heat ./heat
helm install --namespace=openstack --name=neutron ./neutron \
  --set pod.replicas.server=2

helm install --namespace=openstack --name=nova ./nova \
  --set pod.replicas.api_metadata=2 \
  --set pod.replicas.osapi=2 \
  --set pod.replicas.conductor=2 \
  --set pod.replicas.consoleauth=2 \
  --set pod.replicas.scheduler=2 \
  --set pod.replicas.novncproxy=2
helm install --namespace=openstack --name=cinder ./cinder \
  --set pod.replicas.api=2


