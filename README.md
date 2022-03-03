# ansible-vmware-kolla-centos8
# storage-1
dnf install nfs-utils
vi /etc/exports
/kolla_nfs 10.1.0.0/16(rw,sync,no_root_squash)
systemctl start nfs-server
systemctl enable nfs-server
exportfs -v

# auto-control
vi /etc/kolla/config/nfs_shares
storage-1:/kolla_nfs

for i in control-1 control-2 control-3 compute-1 compute-2 compute-3 storage-1 ;
do 
  ssh-copy-id -f -i ~/.ssh/id_rsa.pub root@$i ; 
done

# deploy openstack
ansible-playbook deploy_vms_kolla_cluster.yml
ansible-playbook -i multinode prepare.yml 
cp global.yml /etc/kolla/global.yml
cp passsword.yml /etc/kolla/passsword.yml
kolla-ansible -i ./multinode bootstrap-servers
kolla-ansible -i ./multinode prechecks
kolla-ansible -i ./multinode pull
kolla-ansible -i ./multinode deploy

# scale out openstack
kolla-ansible -i ./multinode bootstrap-servers --limit storage
kolla-ansible -i ./multinode prechecks --limit storage
kolla-ansible -i ./multinode pull --limit storage
kolla-ansible -i ./multinode deploy --limit storage