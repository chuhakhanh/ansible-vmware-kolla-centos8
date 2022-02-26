# ansible-vmware-kolla-centos8
# storage-1
dnf install nfs-utils
systemctl start nfs-server
systemctl enable nfs-server
vi /etc/exports
/kolla_nfs 10.1.0.0/16(rw,sync,no_root_squash)

# auto-control
vi /etc/kolla/config/nfs_shares
storage-1:/kolla_nfs
