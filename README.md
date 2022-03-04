# ansible-vmware-kolla-centos8

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

vi /etc/kolla/config/neutron/ml2_conf.ini 



# deploy openstack

ansible-playbook -i multinode prepare.yml 
cp global.yml /etc/kolla/global.yml
cp passsword.yml /etc/kolla/passsword.yml
kolla-ansible -i ./multinode bootstrap-servers
kolla-ansible -i ./multinode prechecks
kolla-ansible -i ./multinode deploy

# scale out openstack
kolla-ansible -i ./multinode bootstrap-servers --limit storage
kolla-ansible -i ./multinode prechecks --limit storage
kolla-ansible -i ./multinode pull --limit storage
kolla-ansible -i ./multinode deploy --limit storage