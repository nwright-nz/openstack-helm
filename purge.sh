#/bin/bash
helm delete --purge etcd-rabbitmq
helm delete --purge heat
helm delete --purge horizon
helm delete --purge ingress
helm delete --purge keystone
helm delete --purge libvirt
helm delete --purge mariadb
helm delete --purge memcached
helm delete --purge neutron
helm delete --purge nova
helm delete --purge glance
helm delete --purge cinder
helm delete --purge openvswitch
helm delete --purge rabbitmq
helm delete ceph --purge

