# openstack
. /etc/kolla/admin-openrc-c1.sh
wget https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
openstack image create "cirros" --file ./cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack flavor create --id 1 --ram 1024 --disk 1  --vcpu 1 tiny
openstack flavor create --id 2 --ram 4096 --disk 10 --vcpu 2 small
openstack flavor create --id 4 --ram 8096 --disk 50 --vcpu 2 medium
openstack network create --share --external --provider-physical-network physnet1 --provider-network-type vlan --provider-segment=111 public1
openstack subnet create --subnet-range 10.1.0.0/16 --gateway 10.1.0.1 --network public1 --allocation-pool start=10.1.17.130,end=10.1.17.150 public1-subnet

openstack network create --share --external --provider-physical-network physnet1 --provider-network-type flat public1
openstack subnet create --subnet-range 10.1.0.0/16 --gateway 10.1.0.1 --network public1 --allocation-pool start=10.1.17.130,end=10.1.17.150 public1-subnet

openstack subnet create --subnet-range 192.168.126.0/24 --gateway 192.168.126.1 --network pro-vlan126 --allocation-pool start=192.168.126.130,end=192.168.126.150 pro-vlan126-subnet1
net-id-pro-vlan111='openstack network list | grep pro-vlan111 | cut -f2 -d"|"'
openstack server create --flavor 1 --image cirros --nic net-id=96448280-519e-4173-a198-ee0b18d66f02 inst1
openstack server create --flavor 1 --image cirros --nic net-id=$net-id-pro-vlan111 inst1