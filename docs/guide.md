
# Opearation  

## infra vsphere cluster
### operation
    
Snapshot all VM to snap1

    for i in lab1 
    do
        ansible-playbook -i config/cluster/$i/inventory playbooks/cluster_infra_vsphere/setup_vmware_cluster.yml -e "action=create_snapshot" -e "lab_name=$i"
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

