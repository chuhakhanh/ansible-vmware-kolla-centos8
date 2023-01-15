# ansible-vmware-kolla-centos8

## Introduction

### Reference


### VM 

    This setup is aim to provision for multiple lab environment for various tests. 
    deploy-1 is a VM server for deployment with Docker containers. Container deploy-1 with ansible is used to run Ansible Playbook from sources.
    repo-1 is a repository server with a httpd Package Repository, a docker registry  

### Folder 
    
    config: store on all configuration
    config/kolla: the node_config directory for Kolla Ansible ( default /etc/kolla)
    
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

    cp -f config/cluster/lab1/hosts /etc/hosts

    docker exec -it deploy-1 -u0 /bin/bash;
    git clone https://github.com/chuhakhanh/ansible-vmware-kolla-centos8
    cd /root/ansible-vmware-kolla-centos8
    git checkout poc-cgnat

    for i in lab1 
    do
        ansible-playbook -i config/inventory_all playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=create" -e "lab_name=$i"
    done

## Provisioning application(openstack with kolla ansible) cluster

### Push public ssh key into this machines due to predefined password (i=lab#)
    
    ssh-keygen
    chmod u+x ./scripts/key_copy.sh
    
For all cluster 
    
    for i in lab1
    do
        ./scripts/key_copy.sh "config/cluster/$i/inventory"
    done
    
    sshpass -p "alo1234" ssh-copy-id -f -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@10.1.17.117
    
### Install OS prequisite for cluster

For all cluster 

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_app_provisioning/prepare_node_all.yml -e "lab_name=$i"
    done

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_app_provisioning/prepare_node_storage.yml -e "lab_name=$i"
    done

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_app_provisioning/prepare_node_storage.yml -e "lab_name=$i" --start-at-task="install nfs-utils"
    done

## Prepare kolla-ansible environment

    ansible-galaxy collection install community.vmware
    pip3 install "kolla-ansible==13.0.2.dev104"

### Provisioning Openstack for cluster with kolla-ansible

    kolla-ansible -i ./config/kolla/multinode --configdir ./config/kolla/ bootstrap-servers
    kolla-ansible -i ./config/kolla/multinode --configdir ./config/kolla/ prechecks

Snapshot virtual machine cluster before run install 
    [Following steps in docs/gudie.md to work on ceph cluster](docs/guide.md)
  

There may be a bug that I cannot use a specific config_dir as below command become failed
    kolla-ansible -i ./config/kolla/multinode --configdir ./config/kolla/config deploy

So that use node_config as default : /etc/kolla (https://github.com/openstack/kolla-ansible/blob/master/ansible/group_vars/all.yml) to deploy

    cp -r ./config/kolla/ /etc/
    kolla-ansible -i ./config/kolla/multinode deploy

Create source file

    kolla-ansible post-deploy
    . /etc/kolla/admin-openrc.sh
    ./scripts/init-runonce.sh 10.1.17.150 10.1.17.180

    # scale out openstack
    kolla-ansible -i ./kolla/multinode --configdir ./kolla/config bootstrap-servers --limit storage
    kolla-ansible -i ./kolla/multinode --configdir ./kolla/config prechecks --limit storage
    kolla-ansible -i ./kolla/multinode --configdir ./kolla/config pull --limit storage
    kolla-ansible -i ./kolla/multinode --configdir ./kolla/config deploy --limit storage
