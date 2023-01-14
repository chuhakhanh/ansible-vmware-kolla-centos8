# ansible-vmware-kolla-centos8

## Introduction

### Reference


### Description

    This setup is aim to provision for multiple lab environment for varies tests. 

    deploy-1 is a VM server for deployment with Docker containers. Container deploy-1 with ansible is used to run Ansible Playbook from sources.

    repo-1 is a repository server with a httpd Package Repository, a docker registry  

## Setup VMware vsphere infrastructure cluster

### Prepare template 

    https://opendev.org/openstack/nova/commit/2a6bdf8f0e0e22fc7703faa9669ace7380dc73c3
    VMware: Enable disk.EnableUUID=True in vmx
    Currently there is no link in /dev/disk/by-id for SCSI (sdx) devices because by default VMWare doesn't provide information needed by udev to generate /dev/disk/by-id. When this specific parameter disk.EnableUUID
    is set to True in vmx file inside the guest vm /dev/disk/by-id shows a link to UUID of the attached SCSI device

    Edit Settings>VM Options>Advanced>Edit Configuration in Configuration Parameters>Add parameter
    disk.EnableUUID = TRUE
          
### Prepare provisioning VM deploy-1

From repo-1 export images

    docker save -o centos-source-deploy.tar 4b4369be8793

From deploy-1 

Run docker container deploy

    podman load -i centos-source-deploy.tar
    podman run -d --name deploy-1 4b4369be8793
    podman exec -it deploy-1 /bin/bash; 
    vi ~/.bashrc 
    alias ll='ls -lG'
    dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
    yum install sshpass
    yum install tmux

### Create a virtual machine cluster

    docker exec -it deploy-1 -u0 /bin/bash;
    git clone https://github.com/chuhakhanh/ansible-vmware-kolla-centos8
    cd /root/ansible-vmware-kolla-centos8
    git checkout poc-cgnat

    -e "action=destroy" -e "lab_name=lab1"
    -e "action=poweroff" -e "lab_name=lab15"
    -e "action=poweron" -e "lab_name=lab15"
    -e "action=create_snapshot" -e "lab_name=lab15"
    -e "action=remove_snapshot" -e "lab_name=lab15"

    for i in lab1 
    do
        ansible-playbook -i config/inventory_all playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=create" -e "lab_name=$i"
    done

## Provisioning application(openstack with kolla ansible) cluster

### Push public ssh key into this machines due to predefined password (i=lab#)
    
    ssh-keygen
    chmod u+x ./script/key_copy.sh
    
For all cluster 
    
    for i in lab1
    do
        ./script/key_copy.sh "config/cluster/$i/inventory"
    done
    
    sshpass -p "alo1234" ssh-copy-id -f -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@10.1.17.117
    
### Install OS prequisite for cluster

For all cluster 

    for i in lab1 
    do
        ansible-playbook -i "config/cluster/$i/inventory" playbooks/cluster_app_provisioning/prepare_node_all.yml -e "lab_name=$i"
    done

    for i in lab1 
    do
        ansible-playbook -i "config/cluster/$i/inventory" playbooks/cluster_app_provisioning/prepare_node_storage.yml -e "lab_name=$i"
    done

## Prepare kolla-ansible environment

    virtualenv --python=python3 /venv_centos8
    source /venv_centos8/bin/activate 
    sudo pip3 install docker
    pip3 install "kolla-ansible==9.3.2"
    yum install libselinux-python3
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1
    pip install python-openstackclient

    vi /etc/kolla/config/nfs_shares
    storage-1:/kolla_nfs

    cp -u ml2_conf.ini /etc/kolla/config/neutron/ml2_conf.ini 
    cp -u globals.basic_setup.yml /etc/kolla/globals.yml
    cp -u passsword.yml /etc/kolla/passsword.yml
    cp kolla/globals.cent7.train.rating.yml kolla/globals.yml

### Provisioning Openstack for cluster with kolla-ansible

    kolla-ansible -i ./kolla-ansible/environments/multinode --configdir ./kolla-ansible/config bootstrap-servers
    kolla-ansible -i ./kolla-ansible/environments/multinode --configdir ./kolla-ansible/config prechecks

    # snapshot before run install
  
    for i in lab1 
    do
        ansible-playbook -i config/inventory_all playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=create_snapshot" -e "lab_name=$i"
    done


    kolla-ansible -i ./kolla-ansible/environments/multinode --configdir ./kolla-ansible/config deploy


    # scale out openstack
    kolla-ansible -i ./kolla-ansible/environments/multinode --configdir ./kolla-ansible/config bootstrap-servers --limit storage
    kolla-ansible -i ./kolla-ansible/environments/multinode --configdir ./kolla-ansible/config prechecks --limit storage
    kolla-ansible -i ./kolla-ansible/environments/multinode --configdir ./kolla-ansible/config pull --limit storage
    kolla-ansible -i ./kolla-ansible/environments/multinode --configdir ./kolla-ansible/config deploy --limit storage
