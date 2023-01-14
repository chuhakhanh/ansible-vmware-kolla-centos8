# vmware-ceph-rhcs-5



## Introduction

# Reference


# Description

Lab environment is provisioning for 10 people. Each people will use a resource pool with the same name. 

deploy-1 is a deploy server, which contains preconfigured container to run ansible playbook
repo-2 is a webserver contains, QuayIO server:
- config/ : configuration files
- 2022_07/<repo ID>: repository 
- :443/ : images to deploy

172.11.0.0/24
172.12.0.0/24

## Setup cluster

### Prepare the template Virtual machine

    Edit Settings>VM Options>Advanced>Edit Configuration in Configuration Parameters>Add parameter
    disk.EnableUUID = TRUE
          
### Deploy virtual machines cluster

From repo-1 export images

    docker save -o centos-source-deploy.tar 4b4369be8793

From deploy-1 
Create a Virtual machine cluster 

    podman load -i centos-source-deploy.tar
    podman run -d --name deploy-2 4b4369be8793
    podman exec -it deploy-2 /bin/bash; 
    vi ~/.bashrc 
    alias ll='ls -lG'
    dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
    yum install sshpass
    yum install tmux

    
    docker exec -it deploy-2 -u0 /bin/bash;
    git clone https://github.com/chuhakhanh/vmware-ceph-rhcs-5
    cd /root/vmware-ceph-rhcs-5
    git checkout lab-9-2022

    ansible-playbook -i config/inventory/lab setup_vmware_cluster.yml -e "action=create" -e "lab_name=lab1"
    ansible-playbook -i config/inventory/lab setup_vmware_cluster.yml -e "action=destroy" -e "lab_name=lab1"
    ansible-playbook -i config/inventory/lab setup_vmware_cluster.yml -e "action=poweroff" -e "lab_name=lab15"
    ansible-playbook -i config/inventory/lab setup_vmware_cluster.yml -e "action=poweron" -e "lab_name=lab15"
    ansible-playbook -i config/inventory/lab setup_vmware_cluster.yml -e "action=create_snapshot" -e "lab_name=lab15"
    ansible-playbook -i config/inventory/lab setup_vmware_cluster.yml -e "action=remove_snapshot" -e "lab_name=lab15"

    for i in lab1 lab2 lab3 lab4 lab5 lab6 lab7 lab8 lab9 lab10 lab11 lab12 lab13 lab14
    do
        ansible-playbook -i config/inventory/lab setup_vmware_cluster.yml -e "action=create" -e "lab_name=$i"
    done

### Push public ssh key into this machines due to predefined password (i=lab#)
    
    ssh-keygen
    chmod u+x ./script/key_copy.sh
    
For all cluster 
    
    for i in lab1 lab2 lab3 lab4 lab5 lab6 lab7 lab8 lab9 lab10 lab11 lab12 lab13 lab14
    do
        ./script/key_copy.sh config/inventory/$i
    done
    
For 1 cluster     

    for i in lab15
    do
        chmod u+x ./script/key_copy.sh; ./script/key_copy.sh config/inventory/$i
    done
    
    sshpass -p "alo1234" ssh-copy-id -f -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@10.1.17.117
    
### Then apply prequisite for virual machines

For all cluster 

    for i in lab1 lab2 lab3 lab4 lab5 lab6 lab7 lab8 lab9 lab10 lab11 lab12 lab13 lab14
    do
        ansible-playbook -i config/inventory/$i prepare_vmware_cluster.yml -e "lab_name=$i"
    done

For 1 cluster 

    for i in lab15
    do
        ansible-playbook -i config/inventory/$i prepare_vmware_cluster.yml -e "lab_name=$i"
    done


### Fully provisioning all lab

    for i in lab1 lab2 lab3 lab4 lab5 lab6 lab7 lab8 lab9 lab10
    do
        ansible-playbook -i config/inventory/lab setup_vmware_cluster.yml -e "action=create" -e "lab_name=$i"
        chmod u+x ./script/key_copy.sh; ./script/key_copy.sh config/inventory/$i
        ansible-playbook -i config/inventory/$i prepare_vmware_cluster.yml -e "lab_name=$i"
    done
    

### Configure quayio as default insecure local registry 

Check local quayio

    podman login repo-2.lab.example.com --username quayadmin --password password
    podman system info

[Following steps in docs/gudie.md to work on ceph cluster](docs/guide.md)
