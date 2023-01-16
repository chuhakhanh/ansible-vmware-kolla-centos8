
# Opearation  

## infra vsphere cluster
### operation
    
Snapshot all VM to snap1

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=create_snapshot" -e "lab_name=$i"
    done

Remove all snapshot snap1 

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=remove_snapshot" -e "lab_name=$i"
    done


Revert all VM to snap1

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=revert_snapshot" -e "lab_name=$i"
    done

Power on all VM

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=poweron" -e "lab_name=$i"
    done

Power off all VM

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=poweroff" -e "lab_name=$i"
    done


Power on all VM

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=destroy" -e "lab_name=$i"
    done

Run playbook at task 

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_app_provisioning/prepare_node_storage.yml -e "lab_name=$i" --start-at-task="install nfs-utils"
    done    

## application cluster
### operation

scale out openstack

    kolla-ansible -i ./config/kolla/multinode bootstrap-servers --limit storage
    kolla-ansible -i ./config/kolla/multinode prechecks --limit storage
    kolla-ansible -i ./config/kolla/multinode pull --limit storage
    kolla-ansible -i ./config/kolla/multinode deploy --limit storage
    kolla-ansible -i ./config/kolla/multinode reconfigure --limit compute


### OS

Set static ip on cirros 

    sudo ifconfig eth0 192.168.126.80 netmask 255.255.255.0

### Perform debug 

On compute node 

    ip link set dev br-ex up
    ip link set dev br-int up
    ip link set dev br-tun up

    docker exec -it openvswitch_vswitchd tcpdump -nei qvoeb1d5f52-d6
    docker exec -it openvswitch_vswitchd tcpdump -nei qvo39ce7cf7-5c
    docker exec -it openvswitch_vswitchd tcpdump -nei br-ex
    docker exec -it openvswitch_vswitchd tcpdump -nei br-int

    docker exec -it openvswitch_vswitchd /bin/bash ovs-appctl ofproto/trace br-ex 
    