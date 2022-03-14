# ansible-vmware-kolla-centos8
global.basic.yml is for core services
global.rating.yml is for core services + rating services

# create VM 
ansible-playbook deploy_vms_kolla_cluster.yml
ansible-playbook remove_vms_kolla_ansible_c1.yml

# prepare openstack environment
for i in control-1 control-2 control-3 compute-1 compute-2 compute-3 storage-1 ;
do 
  ssh-copy-id -f -i ~/.ssh/id_rsa.pub root@$i ; 
done

vi /etc/kolla/config/nfs_shares
storage-1:/kolla_nfs

cp -u ml2_conf.ini /etc/kolla/config/neutron/ml2_conf.ini 
cp -u globals.yml /etc/kolla/globals.yml
cp -u passsword.yml /etc/kolla/passsword.yml
ansible-playbook -i multinode prepare.yml 
# deploy openstack
kolla-ansible -i ./multinode bootstrap-servers
kolla-ansible -i ./multinode prechecks
ansible-playbook snapshot_create_vms_kolla_ansible_c1.yml
ansible-playbook snapshot_vms_kolla_ansible_c1.yml -e "input_state=revert"
kolla-ansible -i ./multinode deploy

# scale out openstack
kolla-ansible -i ./multinode bootstrap-servers --limit storage
kolla-ansible -i ./multinode prechecks --limit storage
kolla-ansible -i ./multinode pull --limit storage
kolla-ansible -i ./multinode deploy --limit storage

# openstack
. /etc/kolla/admin-openrc-c1.sh
openstack image create "cirros" --file /root/cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack flavor create --id 1 --ram 1024 --disk 1  --vcpu 1 tiny
openstack flavor create --id 2 --ram 4096 --disk 10 --vcpu 2 small
openstack flavor create --id 4 --ram 8096 --disk 50 --vcpu 2 medium
openstack network create --share --provider-physical-network physnet1 --provider-network-type vlan --provider-segment=111 pro-vlan111
openstack subnet create --subnet-range 10.1.0.0/16 --gateway 10.1.0.1 --network pro-vlan111 --allocation-pool start=10.1.17.130,end=10.1.17.150 pro-vlan111-subnet1
openstack network create --share --provider-physical-network physnet1 --provider-network-type vlan --provider-segment=126 pro-vlan126
openstack subnet create --subnet-range 192.168.126.0/24 --gateway 192.168.126.1 --network pro-vlan126 --allocation-pool start=192.168.126.130,end=192.168.126.150 pro-vlan126-subnet1
net-id-pro-vlan111='openstack network list | grep pro-vlan111 | cut -f2 -d"|"'
openstack server create --flavor 1 --image cirros --nic net-id=96448280-519e-4173-a198-ee0b18d66f02 inst1
openstack server create --flavor 1 --image cirros --nic net-id=$net-id-pro-vlan111 inst1
