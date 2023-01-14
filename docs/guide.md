
# Part 2    

## Section 1 - install ceph cluster
### install ceph cluster serverc, serverd, servere

Login node serverc, install require software to bootstrap ceph cluster
    
run preflight  

    ssh-keygen

    for i in clienta.lab.example.com clientb.lab.example.com serverc.lab.example.com serverd.lab.example.com servere.lab.example.com serverf.lab.example.com serverg.lab.example.com; do 
        ssh-copy-id root@$i
    done

run preflight    

    yum install -y cephadm-ansible
    cd /usr/share/cephadm-ansible
    vi hosts
    clienta.lab.example.com
    serverc.lab.example.com
    serverd.lab.example.com
    servere.lab.example.com
    ansible-playbook -i hosts cephadm-preflight.yml --extra-vars "ceph_origin="
    
bootstrap with a yaml 

    podman login repo-2.lab.example.com --username quayadmin --password password
    
    mkdir /root/ceph;cd /root/ceph
    vi initial-config-primary-cluster.yaml

    cephadm --image repo-2.lab.example.com/quayadmin/lab/rhceph/rhceph-5-rhel8 bootstrap --mon-ip=<serverc IP> \
    --apply-spec=initial-config-primary-cluster.yaml \
    --initial-dashboard-password=redhat \
    --dashboard-password-noupdate \
    --allow-fqdn-hostname \
    --registry-url=repo-2.lab.example.com \
    --registry-username=quayadmin \
    --registry-password=password  \
    --yes-i-know

### install ceph cluster serverf

run preflight    

    yum install -y cephadm-ansible
    cd /usr/share/cephadm-ansible
    echo serverf.lab.example.com > hosts
    ssh-keygen
    ssh-copy-id -i /root/.ssh/id_rsa.pub root@serverf.lab.example.com

    systemctl list-units 'ceph*'
    ansible-playbook -i hosts cephadm-preflight.yml --extra-vars "ceph_origin="
    podman login repo-2.lab.example.com --username quayadmin --password password

bootstrap on a single mon 
https://docs.ceph.com/en/quincy/cephadm/install/#running-the-bootstrap-command

    cephadm --image repo-2.lab.example.com/quayadmin/lab/rhceph/rhceph-5-rhel8 bootstrap --mon-ip=<serverf IP> \
    --initial-dashboard-password=redhat \
    --dashboard-password-noupdate \
    --allow-fqdn-hostname \
    --registry-url=repo-2.lab.example.com \
    --registry-username=quayadmin \
    --registry-password=password  \
    --yes-i-know \
    --single-host-defaults

### Post installation

#### Install requirements tool

    dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
    yum install nload -y

#### Edit mgr config 

Enable telemetry after bootstrap
In case, node exporter is set to redhat registry. We need to reconfigure image base and re-deploy node-expoter and alertmanager

    ceph config set mgr mgr/cephadm/container_image_base repo-2.lab.example.com/quayadmin/lab/rhceph/rhceph-5-rhel8
    ceph config set mgr mgr/cephadm/container_image_alertmanager repo-2.lab.example.com/quayadmin/lab/openshift4/ose-prometheus-alertmanager
    ceph config set mgr mgr/cephadm/container_image_prometheus repo-2.lab.example.com/quayadmin/lab/openshift4/ose-prometheus
    ceph config set mgr mgr/cephadm/container_image_grafana repo-2.lab.example.com/quayadmin/lab/rhceph/rhceph-5-dashboard-rhel8
    ceph config set mgr mgr/cephadm/container_image_node_exporter repo-2.lab.example.com/quayadmin/lab/openshift4/ose-prometheus-node-exporter
    
    for i in {container_image_base,container_image_prometheus,container_image_grafana,container_image_alertmanager,container_image_node_exporter};
    do 
        ceph config get mgr mgr/cephadm/$i ;
    done  

On node clienta, serverc, serverd, serverf

    podman login repo-2.lab.example.com --username quayadmin --password password 

On node clienta

    ceph orch redeploy node-exporter
    ceph log last cephadm
    ceph telemetry on --license sharing-1-0

Disable Monitoring
To disable monitoring and remove the software that supports it, run the following commands:
    
    ceph orch rm grafana
    ceph orch rm prometheus --force
    ceph orch rm node-exporter
    ceph orch rm alertmanager
    ceph mgr module disable prometheus

To redeploy the monitoring run:

    ceph mgr module enable prometheus
    ceph orch apply node-exporter '*'
    ceph orch apply alertmanager 1
    ceph orch apply prometheus 1
    ceph orch apply grafana 1

## Section 2 - expand ceph cluster

### add OSD daemon by CLI

On node serverf, add OSD deamon to cluster by service specification file /var/lib/ceph/osd/osd_spec.yml
    
    ceph orch device ls    
    ceph orch ls
    vi /var/lib/ceph/osd/osd_spec.yml
    ceph orch apply -i /var/lib/ceph/osd/osd_spec.yml
    ceph status
    
On node serverf, add OSD deamon to cluster by CLI 

    cephadm shell -- ceph orch daemon add osd serverf.lab.example.com:/dev/sde
    cephadm shell -- ceph orch daemon add osd serverf.lab.example.com:/dev/sdf

# Part 3 - configure cluster    
## Section 1 - configuration settings

On the serverc perform config cluster configuration file for clienta
    
    cd /etc/ceph/
    scp ceph.conf  ceph.client.admin.keyring clienta:/etc/ceph

On the clienta perform, config cluster configuration file 
    ceph config dump

### Config settings debug_ms for OSD daemon

    ceph config show osd.1
    ceph config show osd.1 debug_ms
    ceph config get osd.1 debug_ms
    
    ceph config set osd.1 debug_ms 10
    ceph config show osd.1 debug_ms
    
    ceph orch daemon restart osd.1
    ceph config show osd.1 debug_ms
    ceph config get osd.1 debug_ms

### GUI 
## Section 2 - mon
## Section 3 - network

On node serverc, serverd ,servere

    nload ens224

On node clienta

    ceph config get osd public_network
    ceph config get mon public_network
    ceph config get osd cluster_network
    ceph config get mon cluster_network

    ceph config set global cluster_network 192.168.126.0/24
    ceph -s
    ceph orch ls
    ceph orch restart mon
    ceph orch restart osd.default_drive_group

# Part 4 - storage components

## Section 1 - bluestore with lvm
On clienta
    
    udevadm info /dev/sda
    ceph device ls
    ceph osd tree
    ceph orch device ls | awk /server/ | grep Yes
    ceph orch device ls --wide --refresh
### Using CLi to add OSD daemon

On clienta

    ceph orch daemon add osd serverc.lab.example.com:/dev/sde
    ceph orch daemon add osd serverc.lab.example.com:/dev/sdf
    ceph orch ps | grep -ie osd.9 -ie osd.10
    ceph df
    ceph osd tree

    
### Using spec to add OSD daemon

The effect of ceph orch apply is persistent which means that the Orchestrator automatically finds the device, adds it to the cluster, and creates new OSDs. This occurs under the following conditions:
- New disks or drives are added to the system.
- Existing disks or drives are zapped.
- An OSD is removed and the devices are zapped.


Add by service and test remove an OSD

    ceph orch apply osd --all-available-devices
    ceph orch ls
    ceph osd tree
    ceph orch ls --service-type osd --format yaml

Remove the OSD at servere.lab.example.com:sde

    ceph device ls | grep 'servere.lab.example.com:sde'
    ceph orch daemon stop osd.11
    ceph orch daemon rm osd.11 --force
    ceph osd rm 11
    ceph osd crush rm osd.11
    ceph orch osd rm status
    ceph osd tree

Zap the /dev/sde device on servere. Verify that the Orchestrator service re-adds the OSD daemon correctly

    ceph orch device zap --force servere.lab.example.com /dev/sde
    ceph orch device ls | awk /servere/
### Disable by service and test remove an OSD

    ceph orch apply osd --all-available-devices --unmanaged=true

## Section 2 - pool

    ceph osd lspools
    ceph osd pool create replpool1 64 64
    ceph osd pool get replpool1 pg_autoscale_mode
    ceph config get mon osd_pool_default_pg_autoscale_mode

    ceph osd pool autoscale-status
    ceph osd pool set replpool1 size 4
    ceph osd pool set replpool1 min_size 2
    ceph osd pool application enable replpool1 rbd
    ceph osd pool ls detail
    ceph osd pool get replpool1 size

    ceph osd pool rename replpool1 newpool
    ceph osd pool delete newpool
    ceph osd pool delete newpool newpool --yes-i-really-really-mean-it
    ceph tell mon.* config get mon_allow_pool_delete 
    ceph tell mon.* config set mon_allow_pool_delete true
    ceph osd pool delete newpool newpool --yes-i-really-really-mean-it

    ceph osd erasure-code-profile ls
    ceph osd erasure-code-profile get default
    ceph osd erasure-code-profile set ecprofile-k4-m2 k=4 m=2

    ceph osd pool create ecpool1 64 64 ecprofile-k4-m2
    ceph osd pool application enable ecpool1 rgw
    ceph osd pool ls detail
    ceph osd pool set ecpool1 allow_ec_overwrites true
    ceph osd pool delete ecpool1 ecpool1 --yes-i-really-really-mean-it

## Section 3 - authentication   

    export CEPH_ARGS="--id cephuser"

On clienta

    ceph osd pool create replpool1 64 64
    cephadm shell -- ceph auth get-or-create client.docedit mon 'allow r' osd 'allow rw pool=replpool1 namespace=docs' | sudo tee /etc/ceph/ceph.client.docedit.keyring
    cephadm shell -- ceph auth get-or-create client.docget mon 'allow r' osd 'allow r pool=replpool1 namespace=docs' | sudo tee /etc/ceph/ceph.client.docget.keyring

    cephadm shell --mount /etc/ceph/:/etc/ceph
    rados --id docedit -p replpool1 -N docs put adoc /etc/hosts
    rados --id docget -p replpool1 -N docs get adoc /tmp/test
    cat /tmp/test
    rados --id docget -p replpool1 -N docs put mywritetest /etc/hosts

    ceph auth caps client.docget mon 'allow r' osd 'allow rw pool=replpool1 namespace=docs, allow rw pool=docarchive'
    rados --id docget -p replpool1 -N docs put mywritetest /etc/hosts


# Part 5 - storage map

## Prepare

    Remove the OSD at ceph cluster
    
    for id in 9 10 12 13 14 15 16 17 18 19
    do
        ceph orch daemon stop osd.$id
        ceph orch daemon rm osd.$id --force
        ceph osd rm $id
        ceph osd crush rm osd.$id
    done 
    
    ceph orch osd rm status
    ceph osd tree
## Section 1 - crush map
On clienta

Created class ssd with id 1 to crush map 
    
    ceph osd crush class ls
    ceph osd crush class create hdd 
    ceph osd crush class create ssd 
    
Set new device class to "ssd" on serverc, serverd, servere

    for id in 6 7 8
    do
    ceph osd crush rm-device-class osd.$id
    ceph osd crush set-device-class ssd osd.$id
    done

### Create crush rule with pool belong ssd 

    
    [root@clienta /root]# ceph osd tree
    ID  CLASS  WEIGHT   TYPE NAME         STATUS  REWEIGHT  PRI-AFF
    -1         0.08817  root default                               
    -9               0      host clienta                           
    -5         0.02939      host serverc                           
    0    hdd  0.00980          osd.0         up   1.00000  1.00000
    4    hdd  0.00980          osd.4         up   1.00000  1.00000
    7    ssd  0.00980          osd.7         up   1.00000  1.00000
    -7         0.02939      host serverd                           
    1    hdd  0.00980          osd.1         up   1.00000  1.00000
    5    hdd  0.00980          osd.5         up   1.00000  1.00000
    6    ssd  0.00980          osd.6         up   1.00000  1.00000
    -3         0.02939      host servere                           
    2    hdd  0.00980          osd.2         up   1.00000  1.00000
    3    hdd  0.00980          osd.3         up   1.00000  1.00000
    8    ssd  0.00980          osd.8         up   1.00000  1.00000

Create a crush rule by command line

    ceph osd crush rule ls
    ceph osd crush rule create-replicated onssd default host ssd
    ceph osd pool create myfast 32 32 onssd
    ceph osd lspools
    8 myfast

    [root@clienta /root]# ceph pg dump pgs_brief | grep "^8."
    dumped pgs_brief
    8.4      active+clean  [7,8,6]           7  [7,8,6]               7
    8.7      active+clean  [7,8,6]           7  [7,8,6]               7
    8.6      active+clean  [6,8,7]           6  [6,8,7]               6
    8.1      active+clean  [7,8,6]           7  [7,8,6]               7
    8.0      active+clean  [7,8,6]           7  [7,8,6]               7
    8.3      active+clean  [6,7,8]           6  [6,7,8]               6
    8.2      active+clean  [8,6,7]           8  [8,6,7]               8
    8.d      active+clean  [7,8,6]           7  [7,8,6]               7
    8.c      active+clean  [7,8,6]           7  [7,8,6]               7
    8.f      active+clean  [6,7,8]           6  [6,7,8]               6

### Create crush rule with pool with 1 ssd and 2 osd
On clienta
    
    yum install ceph-base

Create a tree structure to move SSD to a node hostc

    ceph osd crush add-bucket default-cl260 root
    ceph osd crush add-bucket rack1 rack
    ceph osd crush add-bucket rack2 rack
    ceph osd crush add-bucket rack3 rack
    ceph osd crush add-bucket hostc host
    ceph osd crush add-bucket hostd host
    ceph osd crush add-bucket hoste host

    ceph osd crush move rack1 root=default-cl260
    ceph osd crush move rack2 root=default-cl260
    ceph osd crush move rack3 root=default-cl260
    ceph osd crush move hostc rack=rack1
    ceph osd crush move hostd rack=rack2
    ceph osd crush move hoste rack=rack3
    ceph osd crush move hostd rack=rack2 
    
    [root@clienta /root]#  ceph osd crush tree
    ID   CLASS  WEIGHT   TYPE NAME         
    -16               0  root default-cl260
    -17               0      rack rack1    
    -20               0          host hostc
    -18               0      rack rack2    
    -21               0          host hostd
    -19               0      rack rack3    
    -22               0          host hoste
    -1         0.08817  root default      
    -9               0      host clienta  
    -5         0.02939      host serverc  
    0    hdd  0.00980          osd.0     
    4    hdd  0.00980          osd.4     
    7    ssd  0.00980          osd.7     
    -7         0.02939      host serverd  
    1    hdd  0.00980          osd.1     
    5    hdd  0.00980          osd.5     
    6    ssd  0.00980          osd.6     
    -3         0.02939      host servere  
    2    hdd  0.00980          osd.2     
    3    hdd  0.00980          osd.3     
    8    ssd  0.00980          osd.8 

    ceph osd crush set osd.6 1.0 root=default-cl260 rack=rack1 host=hostc
    ceph osd crush set osd.7 1.0 root=default-cl260 rack=rack1 host=hostc
    ceph osd crush set osd.8 1.0 root=default-cl260 rack=rack1 host=hostc
    ceph osd crush set osd.0 1.0 root=default-cl260 rack=rack2 host=hostd
    ceph osd crush set osd.1 1.0 root=default-cl260 rack=rack2 host=hostd
    ceph osd crush set osd.2 1.0 root=default-cl260 rack=rack2 host=hostd
    ceph osd crush set osd.3 1.0 root=default-cl260 rack=rack3 host=hoste
    ceph osd crush set osd.4 1.0 root=default-cl260 rack=rack3 host=hoste
    ceph osd crush set osd.5 1.0 root=default-cl260 rack=rack3 host=hoste

    [root@clienta ~]# ceph osd tree
    ID   CLASS  WEIGHT   TYPE NAME           STATUS  REWEIGHT  PRI-AFF
    -16         9.00000  root default-cl260                           
    -17         3.00000      rack rack1                               
    -20         3.00000          host hostc                           
    6    ssd  1.00000              osd.6       up   1.00000  1.00000
    7    ssd  1.00000              osd.7       up   1.00000  1.00000
    8    ssd  1.00000              osd.8       up   1.00000  1.00000
    -18         3.00000      rack rack2                               
    -21         3.00000          host hostd                           
    0    hdd  1.00000              osd.0       up   1.00000  1.00000
    1    hdd  1.00000              osd.1       up   1.00000  1.00000
    2    hdd  1.00000              osd.2       up   1.00000  1.00000
    -19         3.00000      rack rack3                               
    -22         3.00000          host hoste                           
    3    hdd  1.00000              osd.3       up   1.00000  1.00000
    4    hdd  1.00000              osd.4       up   1.00000  1.00000
    5    hdd  1.00000              osd.5       up   1.00000  1.00000
    -1               0  root default                                 
    -9               0      host clienta                             
    -5               0      host serverc                             
    -7               0      host serverd                             
    -3               0      host servere     

Create a crush rule by to take first replicate from rack1

    ceph osd getcrushmap -o /root/crushmap-org.bin
    crushtool -d /root/crushmap-org.bin -o /root/crushmap-org.txt
    echo $?
    0

    cp /root/crushmap-org.txt /root/crushmap-new.txt
    cat /root/crushmap-new.txt
    ...output omitted...
    
    rule onssd {
    id 3
    type replicated
    min_size 1
    max_size 10
    step take default class ssd
    step chooseleaf firstn 0 type host
    step emit
    }

    rule ssd-first {
        id 5
        type replicated
        min_size 1
        max_size 10
        step take rack1
        step chooseleaf firstn 1 type host
        step emit
        step take default-cl260 class hdd
        step chooseleaf firstn -1 type rack
        step emit
    }

Create a new crushmap rule and test 

    crushtool -c /root/crushmap-new.txt -o /root/crushmap-new.bin
    crushtool -i /root/crushmap-new.bin --test --show-mappings --rule=5 --num-rep 3 > /root/test_rule5_rep3.txt
    more /root/test_rule5_rep3.txt
    

    ceph osd setcrushmap -i /root/crushmap-new.bin
    ceph osd crush rule ls
    ceph osd pool create testcrush 32 32 ssd-first
    ceph osd lspools
    ...output omitted...
    6 myfast
    7 testcrush
    ceph pg dump pgs_brief | grep ^6
    dumped pgs_brief
    7.b active+clean [1,8,3] 1 [1,8,3] 1
    7.8 active+clean [5,3,7] 5 [5,3,7] 5
    7.9 active+clean [5,0,7] 5 [5,0,7] 5
    7.e active+clean [1,2,4] 1 [1,2,4] 1

Remap 1 HDD OSD (id=3) of pg 7.8 to other HDD OSD (id=0): 
from state:  7.8 active+clean [5,3,7] 5 [5,3,7] ->  7.8 (7.8) 
  to state:                up [5,0,7] acting [5,0,7]
    
    ceph osd pg-upmap-items 7.8 3 0
    ceph pg map 7.8

### Create a replicated rule (maybe conflict with previous test)

Edit the crush structure

    ceph osd crush add-bucket dc1 datacenter
    ceph osd crush add-bucket dc2 datacenter
    ceph osd crush move dc1 root=review-cl260
    ceph osd crush move dc2 root=review-cl260
    ceph osd crush move rack2 datacenter=dc1
    ceph osd crush move rack3 datacenter=dc2

    [root@clienta ~]# ceph osd tree
    ID   CLASS  WEIGHT   TYPE NAME               STATUS  REWEIGHT  PRI-AFF
    -39         6.00000  root review-cl260                                
    -37         3.00000      datacenter dc1                               
    -18         3.00000          rack rack2                               
    -21         3.00000              host hostd                           
    0    hdd  1.00000                  osd.0       up   1.00000  1.00000
    1    hdd  1.00000                  osd.1       up   1.00000  1.00000
    2    hdd  1.00000                  osd.2       up   1.00000  1.00000
    -38         3.00000      datacenter dc2                               
    -19         3.00000          rack rack3                               
    -22         3.00000              host hoste                           
    3    hdd  1.00000                  osd.3       up   1.00000  1.00000
    4    hdd  1.00000                  osd.4       up   1.00000  1.00000
    5    hdd  1.00000                  osd.5       up   1.00000  1.00000
    -16         3.00000  root default-cl260                               
    -17         3.00000      rack rack1                                   
    -20         3.00000          host hostc                               
    6    ssd  1.00000              osd.6           up   1.00000  1.00000
    7    ssd  1.00000              osd.7           up   1.00000  1.00000
    8    ssd  1.00000              osd.8           up   1.00000  1.00000
    -1               0  root default                                     
    -9               0      host clienta                                 
    -5               0      host serverc                                 
    -7               0      host serverd                                 
    -3               0      host servere   

Create a replicated pool and verify object replicas in different Datacenter
ceph osd crush rule create-replicated <name> <root> <type> [<class>]
    
    ceph osd crush rule create-replicated replicated-rule1 default-cl260 datacenter
    ceph osd crush rule create-replicated replicated-rule2 review-cl260 datacenter
    ceph osd crush rule dump | grep -B2 -A 20 replicated-rule1
    ceph osd crush rule dump | grep -B2 -A 20 replicated-rule2
    ceph osd getcrushmap -o /root/crushmap-review.bin
    crushtool -i /root/crushmap-review.bin --test --show-mappings --rule=2 --num-rep 2 | more
    
    ceph osd pool create review-pool1 64 64 replicated replicated-rule1
    ceph osd pool create review-pool2 64 64 replicated replicated-rule2
    [root@clienta ~]# ceph osd pool ls detail | grep review-pool
    pool 11 'review-pool1' replicated size 3 min_size 2 crush_rule 2 object_hash rjenkins pg_num 64 pgp_num 64 autoscale_mode on last_change 544 flags hashpspool,creating stripe_width 0
    pool 12 'review-pool2' replicated size 3 min_size 2 crush_rule 3 object_hash rjenkins pg_num 64 pgp_num 64 autoscale_mode on last_change 547 flags hashpspool stripe_width 0
    
    ceph pg dump pgs_brief | grep ^11
    ceph pg dump pgs_brief | grep ^12

    ceph osd crush tunables optimal
## Section 2 - manage OSD map

Get epoch time, set-full-ratio, set-nearfull-ratio

    ceph osd dump
    ceph osd set-full-ratio 0.9
    ceph osd set-nearfull-ratio 0.9
    ceph osd dump


Export and import maps, verify epoch changed

    ceph osd getmap -o osdmap.bin
    osdmaptool --print osdmap.bin
    osdmaptool --export-crush crushmap.bin osdmap.bin
    crushtool -d crushmap.bin -o crushmap.txt 
 
    crushtool -c crushmap.txt -o crushmap-new.bin
    cp osdmap.bin osdmap-new.bin
    osdmaptool --import-crush crushmap-new.bin osdmap-new.bin
    
    osdmaptool --test-map-pgs-dump osdmap-new.bin

### Revert everything
Delete pool

Delete rule
    ceph osd crush rule rm onssd
    ceph osd crush rule rm replicated-rule1
    ceph osd crush rule rm replicated-rule2
    ceph osd crush rule rm ssd-first


    [root@clienta /root]# ceph osd tree
    ID  CLASS  WEIGHT   TYPE NAME         STATUS  REWEIGHT  PRI-AFF
    -1         0.08817  root default                               
    -9               0      host clienta                           
    -5         0.02939      host serverc                           
    0    hdd  0.00980          osd.0         up   1.00000  1.00000
    4    hdd  0.00980          osd.4         up   1.00000  1.00000
    7    ssd  0.00980          osd.7         up   1.00000  1.00000
    -7         0.02939      host serverd                           
    1    hdd  0.00980          osd.1         up   1.00000  1.00000
    5    hdd  0.00980          osd.5         up   1.00000  1.00000
    6    ssd  0.00980          osd.6         up   1.00000  1.00000
    -3         0.02939      host servere                           
    2    hdd  0.00980          osd.2         up   1.00000  1.00000
    3    hdd  0.00980          osd.3         up   1.00000  1.00000
    8    ssd  0.00980          osd.8         up   1.00000  1.00000

    ceph osd crush set osd.0 1.0 root=default host=serverc
    ceph osd crush set osd.4 1.0 root=default host=serverc
    ceph osd crush set osd.7 1.0 root=default host=serverc
    ceph osd crush set osd.1 1.0 root=default host=serverd
    ceph osd crush set osd.5 1.0 root=default host=serverd
    ceph osd crush set osd.6 1.0 root=default host=serverd
    ceph osd crush set osd.2 1.0 root=default host=servere
    ceph osd crush set osd.3 1.0 root=default host=servere
    ceph osd crush set osd.8 1.0 root=default host=servere

    for id in 6 7 8
    do
    ceph osd crush rm-device-class osd.$id
    ceph osd crush set-device-class hdd osd.$id
    done

    ceph osd crush remove hostc
    ceph osd crush remove hostd
    ceph osd crush remove hoste
    ceph osd crush remove rack1
    ceph osd crush remove rack2
    ceph osd crush remove rack3
    ceph osd crush remove dc1
    ceph osd crush remove dc2
    ceph osd crush remove review-cl260
    ceph osd crush remove default-cl260 
    
    [root@clienta ~]# ceph osd tree
    ID   CLASS  WEIGHT   TYPE NAME           STATUS  REWEIGHT  PRI-AFF
    -39               0  root review-cl260                            
    -16               0  root default-cl260                           
    -1         9.00000  root default                                 
    -9               0      host clienta                             
    -5         3.00000      host serverc                             
    0    hdd  1.00000          osd.0           up   1.00000  1.00000
    4    hdd  1.00000          osd.4           up   1.00000  1.00000
    7    hdd  1.00000          osd.7           up   1.00000  1.00000
    -7         3.00000      host serverd                             
    1    hdd  1.00000          osd.1           up   1.00000  1.00000
    5    hdd  1.00000          osd.5           up   1.00000  1.00000
    6    hdd  1.00000          osd.6           up   1.00000  1.00000
    -3         3.00000      host servere                             
    2    hdd  1.00000          osd.2           up   1.00000  1.00000
    3    hdd  1.00000          osd.3           up   1.00000  1.00000
    8    hdd  1.00000          osd.8           up   1.00000  1.00000
# Part 6 - block storage - basic

## Section 1 - rbd

### Prepare
On clienta

    ceph osd pool create test_pool 32 32
    rbd pool init test_pool
    ceph df
    ceph auth get-or-create client.test_pool.clientb mon 'profile rbd' osd 'profile rbd' -o /etc/ceph/ceph.client.test_pool.clientb.keyring
    cat /etc/ceph/ceph.client.test_pool.clientb.keyring
    ceph auth get client.test_pool.clientb
    scp /etc/ceph/{ceph.conf,ceph.client.test_pool.clientb.keyring} root@clientb:/etc/ceph

On clientb

    yum install -y ceph-common
    export CEPH_ARGS='--id=test_pool.clientb'
    rbd ls test_pool

    rbd create test_pool/test --size=128M
    rbd ls test_pool
    rbd info test_pool/test
    rbd map test_pool/test
    /dev/rbd0
    rbd showmapped
    mkfs.xfs /dev/rbd0
    mkdir /mnt/rbd
    mount /dev/rbd0 /mnt/rbd
    chown root:root /mnt/rbd
    df /mnt/rbd
    dd if=/dev/zero of=/mnt/rbd/test1 bs=10M count=1
    ls /mnt/rbd
    df /mnt/rbd
    ceph df
    umount /mnt/rbd
    rbd unmap /dev/rbd0
    rbd showmapped

### Mount on a /etc/fstab

    echo "test_pool/test                  id=test_pool.clientb,keyring=/etc/ceph/ceph.client.test_pool.clientb.keyring" >> /etc/ceph/rbdmap 
    cat /etc/ceph/rbdmap
    # RbdDevice                     Parameters
    #poolname/imagename             id=client,keyring=/etc/ceph/ceph.client.keyring
    test_pool/test                  id=test_pool.clientb,keyring=/etc/ceph/ceph.client.test_pool.clientb.keyring

    echo "/dev/rbd/test_pool/test /mnt/rbd xfs noauto 0 0" >> /etc/fstab
    cat /etc/fstab
    /dev/rbd/test_pool/test /mnt/rbd xfs noauto 0 0
    
    rbdmap map
    rbd showmapped
    rbdmap unmap /dev/rbd0
    rbd showmapped
    systemctl enable rbdmap
    reboot
    df /mnt/rbd
    
Clear lab

    rbdmap unmap
    df | grep rbd
    rbd showmapped
    vi /etc/fstab
    # /dev/rbd/test_pool/test /mnt/rbd xfs noauto 0 0
    vi /etc/ceph/rbdmap
    # test_pool/test                  id=test_pool.clientb,keyring=/etc/ceph/ceph.client.test_pool.clientb.keyring
    
    rbd rm test_pool/test --id test_pool.clientb
    rados -p test_pool ls --id test_pool.clientb
    ceph osd pool rm test_pool test_pool --yes-i-really-really-mean-it

## Section 2 - snapshot

### Test image and snapshot on 2 client

On node clienta

    ceph osd pool create rbd 32 32
    ceph osd pool application enable rbd rbd
    rbd pool init -p rbd

    rbd ls rbd
    rbd create rbd/image1 --size=128M

    rbd map rbd/image1
    /dev/rbd0
    mkfs.xfs /dev/rbd0

    ceph auth get-or-create client.rbd.clientb mon 'profile rbd' osd 'profile rbd' -o /etc/ceph/ceph.client.rbd.clientb.keyring
    scp /etc/ceph/ceph.client.rbd.clientb.keyring root@clientb:/etc/ceph

Confirm that the /dev/rbd0 device is writable.

    blockdev --getro /dev/rbd0
    0

Create a snapshot, mount on clientb and confirm snapshot is readonly

    rbd snap create rbd/image1@firstsnap
    rbd disk-usage --pool rbd image1
    NAME PROVISIONED USED
    image1@firstsnap 128 MiB 36 MiB
    image1 128 MiB 36 MiB
    <TOTAL> 128 MiB 72 MiB

On node clientb

    export CEPH_ARGS='--id=rbd.clientb'
    rbd map --pool rbd image1@firstsnap
    rbd showmapped

Confirm that /dev/rbd0 is a read-only block device

    blockdev --getro /dev/rbd0
    1

Write data to image and verify there's no data in snapshot on clientb 
On node clienta, 

    mkdir /mnt/image
    mount /dev/rbd0 /mnt/image
    cp /etc/ceph/ceph.conf /mnt/image/file0
    df /mnt/image/
    Filesystem 1K-blocks Used Available Use% Mounted on
    /dev/rbd0 123584 7944 115640 7% /mnt/image

On node clientb
Check snapshot blockdevice

    mkdir /mnt/snapshot/
    mount /dev/rbd0 /mnt/snapshot/
    df /mnt/snapshot/
    Filesystem 1K-blocks Used Available Use% Mounted on
    /dev/rbd0 123584 480 123104 1% /mnt/snapshot
    
    ls -l /mnt/snapshot/
    umount /mnt/snapshot
    rbd unmap --pool rbd image1@firstsnap
    rbd showmapped

### Test image and clone on 2 client

On node clienta

    rbd snap protect rbd/image1@firstsnap
    rbd clone rbd/image1@firstsnap rbd/clone1
    rbd children rbd/image1@firstsnap
    rbd/clone1

On node clientb

    mkdir /mnt/clone
    rbd map --pool rbd clone1
    /dev/rbd0
    mount /dev/rbd0 /mnt/clone
    dd if=/dev/zero of=/mnt/clone/file1 bs=1M count=10
    ls -l /mnt/clone/

Clean up

On node clientb

    umount /mnt/clone
    rbd unmap --pool rbd clone1
    rbd showmapped
    unset CEPH_ARGS

On node clienta

    umount /mnt/image
    rbd unmap --pool rbd image1
    rbd showmapped



## Section 3 - import/export 

If you are trying to create a cluster on a single node, you must change the default of the osd crush chooseleaf type setting from 1 (meaning host or node) to 0 (meaning osd) in your Ceph configuration file before you create your monitors and OSDs (https://docs.ceph.com/en/quincy/rados/troubleshooting/troubleshooting-pg/#one-node-cluster)

    ceph config get mon.* osd_crush_chooseleaf_type
    1
    ceph config set mon.* osd_crush_chooseleaf_type 0

    ceph osd getcrushmap -o comp_crush_map.cm
    crushtool -d comp_crush_map.cm -o crush_map.txt
    rule replicated_rule {
        id 0
        type replicated
        min_size 1
        max_size 10
        step take default
        step chooseleaf firstn 0 type osd <<<<
        step emit
    }
    crushtool -c crush_map.txt -o new_crush_map.cm
    ceph osd setcrushmap -i new_crush_map.cm  

On node serverf ( cluster serverf )

    ceph osd pool create rbd 32
    ceph osd pool application enable rbd rbd
    rbd pool init -p rbd
    rbd create test --size 128 --pool rbd

### export an image

On node clienta ( cluster 1)

    rbd create rbd/test --size=128M
    rbd map --pool rbd test
    mkfs.xfs /dev/rbd0
    mkdir /mnt/rbd
    mount /dev/rbd0 /mnt/rbd
    cp /etc/ceph/ceph.conf /mnt/rbd/file0
    umount /mnt/rbd

    rbd export rbd/test /mnt/export.dat
    rsync -avP /mnt/export.dat serverf:/mnt/export.dat

On node serverf ( cluster 2)  
 
    rbd --pool rbd ls
    rbd import /mnt/export.dat rbd/test
    rbd du --pool rbd test

    rbd map --pool rbd test
    mkdir /mnt/rbd
    mount /dev/rbd0 /mnt/rbd
    df -h /mnt/rbd
    cat /mnt/rbd/file0
    umount /mnt/rbd
    rbd unmap /dev/rbd0

### export an image snapshot

On node clienta ( cluster 1)

    rbd snap create rbd/test@firstsnap

On node serverf ( cluster 2)

    rbd snap create rbd/test@firstsnap

On node clienta ( cluster 1)

    rbd map --pool rbd test
    mount /dev/rbd0 /mnt/rbd
    dd if=/dev/zero of=/mnt/rbd/file1 bs=1M count=5
    rbd du --pool rbd test
    ls -l /mnt/rbd/
    umount /mnt/rbd

    [ceph: root@clienta /]# rbd du --pool rbd test
    NAME PROVISIONED USED
    test@firstsnap 128 MiB 36 MiB
    test 128 MiB 40 MiB
    <TOTAL> 128 MiB 76 MiB
    
    [ceph: root@clienta /]# rbd snap create rbd/test@secondsnap
    Creating snap: 100% complete...done.
    
    [ceph: root@clienta /]# rbd du --pool rbd test
    NAME PROVISIONED USED
    test@firstsnap 128 MiB 36 MiB
    test@secondsnap 128 MiB 40 MiB
    test 128 MiB 12 MiB
    <TOTAL> 128 MiB 88 MiB
    
    rbd export-diff --from-snap firstsnap rbd/test@secondsnap /mnt/export-diff.dat
    rsync -avP /mnt/export-diff.dat serverf:/mnt/export-diff.dat

On node serverf ( cluster 2)

    [ceph: root@serverf /]# rbd du --pool rbd test
    NAME PROVISIONED USED
    test@firstsnap 128 MiB 32 MiB
    test 128 MiB 32 MiB
    <TOTAL> 128 MiB 64 MiB
    
    rbd import-diff /mnt/export-diff.dat rbd/test
    
    rbd du --pool rbd test
    NAME PROVISIONED USED
    test@firstsnap 128 MiB 32 MiB
    test@secondsnap 128 MiB 32 MiB
    test 128 MiB 8 MiB
    <TOTAL> 128 MiB 72 MiB

    rbd map --pool rbd test
    mount /dev/rbd0 /mnt/rbd
    df /mnt/rbd
    ls -l /mnt/rbd
    total 5124
    -rw-r--r--. 1 admin users 177 Sep 30 22:02 file0
    -rw-r--r--. 1 admin users 5242880 Sep 30 23:15 file1

Cleanup

On node clienta ( cluster 1)
    rbd --pool rbd ls

    umount /mnt/rbd
    rbd unmap /dev/rbd0
    rbd --pool rbd snap purge test
    rbd rm test --pool rbd

    rbd --pool rbd snap unprotect rbd/image1@firstsnap
    rbd --pool rbd snap purge rbd/image1
    rbd --pool rbd rm image1

On node serverf ( cluster 2)

    umount /mnt/rbd
    rbd unmap /dev/rbd0
    rbd --pool rbd snap purge test
    rbd rm test --pool rbd
# Part 7 - block storage - advanced

## Section 1 - rbd mirrors


Create prepare mirror 
On node clienta 
    
    ceph orch apply rbd-mirror --placement=serverc.lab.example.com
    ceph orch ls

    ceph daemon rbd mirror config set debug_osd 0/5

On node serverf
    
    ceph orch apply rbd-mirror --placement=serverf.lab.example.com
    ceph orch ls

Create pool and mirror using pool mode

Prepare to debug mirror mode
    
    ceph tell type.id config set debug_subsystem debug-level
    ceph config set osd.0 debug_rbd_mirror 5/5
    ceph config set global debug_rbd_mirror 5/5
    ceph tell mon.0 config show | grep rbd| grep debug
    "debug_rbd": "0/5",
    "debug_rbd_mirror": "5/5",
    ceph tell mon.* config set debug_rbd_mirror 5/5

On node clienta, create rbd pool if neccessary 

    ceph osd lspools
    ceph osd pool create rbd 32
    ceph osd pool application enable rbd rbd
    rbd pool init -p rbd
    
    rbd create image1 --size 1024 --pool rbd --image-feature=exclusive-lock,journaling
    rbd -p rbd ls
    rbd --image image1 info
    rbd mirror pool enable rbd pool
    rbd --image image1 info
        journal: 519f0f4f981fb
        mirroring state: enabled
        mirroring mode: journal
        mirroring global id: b72af73a-3a7c-4178-b7a8-81e82d39533f
        mirroring primary: true
    
    rbd mirror pool status
    rbd mirror pool peer bootstrap create --site-name primary rbd > /mnt/bootstrap_token_prod
    rsync -avP /mnt/bootstrap_token_prod serverf:/mnt/bootstrap_token_prod
    scp  /mnt/bootstrap_token_prod serverf:/mnt/bootstrap_token_prod

On node serverf

    ceph osd lspools
    ceph osd pool create rbd 32
    ceph osd pool application enable rbd rbd
    rbd pool init -p rbd

    rbd -p rbd ls
    rbd mirror pool peer bootstrap import --site-name secondary --direction rx-only rbd /mnt/bootstrap_token_prod
    
Verify mirror status 

On node clienta, serverf
    
    rbd mirror image status rbd/image1
    rbd mirror pool info rbd
    rbd mirror pool status

    rbd create image2 --size 128 --pool rbd --image-feature=exclusive-lock,journaling
    rbd -p rbd ls

Test 1: switch the image between cluster

On node clienta
    rbd mirror image demote rbd/image1
    rbd mirror image status rbd/image1

On node serverf
    rbd mirror image promote rbd/image1
    rbd mirror image status rbd/image1
    description: local image is primary

Fallback

On node serverf
    rbd mirror image demote rbd/image1
    rbd mirror image status rbd/image1

On node clienta
    rbd mirror image promote rbd/image1
    rbd mirror image status rbd/image1

Test 2: remove the image on primary cluster

On node clienta

    rbd rm image1 -p rbd
    rbd -p rbd ls

On node serverf

    rbd -p rbd ls

    ceph tell mon.* config set mon_allow_pool_delete true
    ceph osd pool delete rbd rbd --yes-i-really-really-mean-it

## Section 2 - iscsi

On node clienta 
As warning message come with iscsi configured as https://bugzilla.redhat.com/show_bug.cgi?id=2018906
A workaround is to silence CEPHADM_STRAY_DAEMON
    
    ceph config get osd osd_heartbeat_interval
    ceph config get osd osd_heartbeat_grace 
    ceph config get osd osd_client_watch_timeout
    ceph config get mgr mgr/cephadm/warn_on_stray_daemons 
    
    ceph config set osd osd_heartbeat_interval 5
    ceph config set osd osd_heartbeat_grace 20
    ceph config set osd osd_client_watch_timeout 15
    ceph config set mgr mgr/cephadm/warn_on_stray_daemons false

    ceph osd pool create iscsipool1 32
    ceph osd pool application enable iscsipool1 rbd
    rbd pool init -p iscsipool1

    vi /etc/ceph/iscsi-gateway.yaml
    ceph orch apply -i /etc/ceph/iscsi-gateway.yaml
    ceph dashboard iscsi-gateway-list

    rbd create image1 --size 128 --pool iscsipool1 

 Create a target on GUI

    Block>iSCSI>Targets>Create
    a. Modify the Target IQN (optional).
    b. Click +Add portal and select the first of at least two gateways: 10.1.17.113
    c. Click +Add image and select an image for the target to export: iscsipool.image1
    d. Click Create Target:     
    User: cl260-admin
    Password: redhat-password
   
Configure an iSCSI Initiator
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/configuring_device_mapper_multipath/index
    yum install iscsi-initiator-utils device-mapper-multipath
    mpathconf --enable --with_multipathd y
    vi /etc/multipath.conf
    
devices {
        device {
                vendor                 "LIO-ORG"
                product                "TCMU device"
                hardware_handler       "1 alua"
                path_grouping_policy   "failover"
                path_selector          "queue-length 0"
                failback               60
                path_checker           tur
                prio                   alua
                prio_args              exclusive_pref_bit
                fast_io_fail_tmo       25
                no_path_retry          queue
        }
}

    systemctl reload multipathd
    vi /etc/iscsi/iscsid.conf
    node.session.auth.authmethod = CHAP
    node.session.auth.username = admin
    node.session.auth.password = redhat
    iscsiadm -m discovery -t st -p 10.1.17.113
    10.1.17.113:3260,1 iqn.2001-07.com.ceph:1662815569595
    iscsiadm -m node -T iqn.2001-07.com.ceph:1662815569595 -l
    lsblk
    multipath -ll

# Part 8 - rgw

## Section 1 - deploy rgw

Clear and create prepare rgw 
    
    ceph orch ls
    ceph orch ls --service-type rgw
    NAME            PORTS  RUNNING  REFRESHED  AGE  PLACEMENT                                        
    rgw.realm.zone  ?:80       2/2  2m ago     10d  serverc.lab.example.com;serverd.lab.example.com  
    ceph orch rm rgw.realm.zone

Configure rgw service myrealm.myzone to start 2 RGW instances in serverd and servere, port 8080    
    
    vi /tmp/rgw_service.yaml
    ceph orch apply -i /tmp/rgw_service.yaml    
    ceph orch ps --daemon-type rgw
    NAME HOST STATUS
    REFRESHED AGE PORTS ...
    rgw.myrealm.myzone.serverd.tknapl serverd.lab.example.com running (14s) 0s ago
    14s *:8080 ...
    rgw.myrealm.myzone.serverd.xpabfe serverd.lab.example.com running (6s) 0s ago
    6s *:8081 ...
    rgw.myrealm.myzone.servere.lwusbq servere.lab.example.com running (18s) 0s ago
    17s *:8080 ...
    rgw.myrealm.myzone.servere.uyginy servere.lab.example.com running (10s) 0s ago
    10s *:8081 ...

On node serverd, servere

    podman ps -a --format "{{.ID}} {{.Names}}" | grep rgw
    ss -tupln | grep 80

On clienta

    curl http://serverd:8080
    curl http://serverd:8081

## Section 2 - deploy rgw - multisite

Setup realm, zonegroup, zone 
- Each realm has an associated period, and each period has an associated epoch. A period is used to track the configuration state of the realm, zone groups, and zones at a particular time. 
- Epochs are version numbers to track configuration changes for a particular realm period.
- Each period has a unique ID, contains realm configuration, and knows the previous period ID.
##  realm: cl260
### zonegroup: classroom, zone: us-east-1

Realm: cl260
    
    radosgw-admin realm create --rgw-realm=cl260 --default

Zonegroup: classroom

    radosgw-admin zonegroup create --rgw-zonegroup=classroom --endpoints=http://serverc.lab.example.com:80 --master --default

Zone: us-east-1

    radosgw-admin zone create --rgw-zonegroup=classroom --rgw-zone=us-east-1 --endpoints=http://serverc.lab.example.com:80 --master --default --access-key=replication --secret=secret

User: repl.user

    radosgw-admin user create --uid="repl.user" --system --display-name="Replication User" --secret=secret --access-key=replication
    
Commit:

    radosgw-admin period update --commit

Service: cl260-1

    ceph orch apply rgw cl260-1 --realm=cl260 --zone=us-east-1 --placement="1 serverc.lab.example.com"
    ceph orch ps --daemon-type rgw
    NAME HOST STATUS REFRESHED AGE PORTS ...
    rgw.cl260-1.serverc.sxsntj serverc.lab.example.com running (6m) 6m ago 6m
    *:80 ...

Update zone name:

    ceph config get client.rgw rgw_zone
    ceph config set client.rgw rgw_zone us-east-1

 View:

    radosgw-admin realm pull --url=http://serverc.lab.example.com:80 --access-key=replication --secret-key=secret
    radosgw-admin period get-current
    {
    "current_period": "7cdc83cf-69d8-478e-b625-d5250ac4435b"
    }

https://bugzilla.redhat.com/show_bug.cgi?id=1894190#c5
The decision of removing RGW multisite support form cephadm comes from Sage and Casey Bodley (RGW team).
They decide to remove it from cephadm because a complex RGW multisite configuration requires a "sequential" process with interactive checks that is not possible to implement properly.

Ceph ansible had also this functionality but it seems that only work well for simple use cases. We commented with consultants and it seems that the usual way to do the RGW multisite configuration is manual using rados admin commands.
### Dashboard
    echo "password" > pass.txt
    ceph dashboard ac-user-create serverworld -i pass.txt administrator

    radosgw-admin sync status
    radosgw-admin zone list
    radosgw-admin zonegroup list

    radosgw-admin user info --uid="repl.user"
    ceph dashboard set-rgw-credentials
    
create file: 

access_key    

    {"us-east-1.serverc.lab.example.com": "replication"} 

create file: 
    
secret_key

    {"us-east-1.serverc.lab.example.com": "secret"} 
    
    ceph dashboard set-rgw-api-access-key -i access_key
    ceph dashboard set-rgw-api-secret-key -i secret_key
    ceph dashboard set-rgw-api-ssl-verify false
### zonegroup: classroom, zone: us-east-2
On serverf

Realm: cl260
    
    radosgw-admin realm pull --url=http://serverc.lab.example.com:80 --access-key=replication --secret-key=secret
    radosgw-admin period pull --url=http://serverc.lab.example.com:80 --access-key=replication --secret-key=secret
    radosgw-admin period get-current

    radosgw-admin realm list
    radosgw-admin realm default --rgw-realm=cl260


Zonegroup: classroom

    radosgw-admin zonegroup default --rgw-zonegroup=classroom 

Zone: us-east-2

    radosgw-admin zone create --rgw-zonegroup=classroom --rgw-zone=us-east-2 --endpoints=http://serverf:80 --default --default --access-key=replication --secret=secret

Commit:

    radosgw-admin period update --commit --rgw-zone=us-east-2
    {
    "id": "7cdc83cf-69d8-478e-b625-d5250ac4435b",
    }

Update zone name:

    ceph config set client.rgw rgw_zone us-east-2

Service: cl260-2

    ceph orch apply rgw cl260-2 --realm=cl260 --zone=us-east-2 --placement="1 serverf"
    ceph orch ps --daemon-type rgw
    NAME HOST STATUS REFRESHED AGE PORTS ...
    rgw.east.serverf.zgkgem serverf.lab.example.com running (37m) 6m ago 37m
    *:80 ...


 View:

    radosgw-admin realm pull --url=http://serverc:80 --access-key=replication --secret-key=secret
    radosgw-admin period get-current
    {
    "current_period": "7cdc83cf-69d8-478e-b625-d5250ac4435b"
    }

    radosgw-admin sync status

##  realm: prod

### zonegroup: us-west, zone: us-west-1

    radosgw-admin realm create --rgw-realm=prod --default
    radosgw-admin zonegroup create --rgw-zonegroup=us-west --endpoints=http://serverc:8080 --master --default
    radosgw-admin zone create --rgw-zonegroup=us-west --rgw-zone=us-west-1 --endpoints=http://serverc:8080 --master --access-key=admin --secret=secure --default
    radosgw-admin user create --uid="admin.user" --system --display-name="Admin User" --access-key=admin --secret=secure
    radosgw-admin period update --commit
    radosgw-admin period get-current
    ceph orch apply rgw prod-object --realm=prod --zone=us-west-1 --port 8080 --placement="2 serverc.lab.example.com servere.lab.example.com"


# Part 9 - rgw - rest API service

## Section 1 - Amazon S3

On clienta as S3 client

    sudo cephadm shell -- radosgw-admin user create --uid="operator" --display-name="S3 Operator" --email="operator@example.com" --access_key="12345" --secret="67890"
    radosgw-admin user list

    dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
    yum install awscli -y
    
    aws configure --profile=ceph
    AWS Access Key ID [None]: 12345
    AWS Secret Access Key [None]: 67890
    Default region name [None]: Enter
    Default output format [None]: Enter

    aws --profile=ceph --endpoint=http://serverc.lab.example.com:80 s3 mb s3://testbucket
    aws --profile=ceph --endpoint=http://serverc.lab.example.com:80 s3 ls
    dd if=/dev/zero of=/tmp/10MB.bin bs=1024K count=10
    aws --profile=ceph --endpoint=http://serverc.lab.example.com:80 --acl=public-read-write s3 cp /tmp/10MB.bin s3://testbucket/10MB.bin
    
On clienta as ceph admin    

    wget -O /dev/null http://serverc.lab.example.com:80/testbucket/10MB.bin
    cephadm shell -- radosgw-admin bucket list
    cephadm shell -- radosgw-admin metadata get bucket:testbucket

## Section 2 - Amazon Swift

On node clienta

    cephadm shell -- radosgw-admin subuser create --uid="operator" --subuser="operator:swift" --access="full" --secret="opswift"

On clienta as Swift client   

    sudo pip3 install --upgrade python-swiftclient

    swift -A http://serverc.lab.example.com:80/auth/1.0 -U operator:swift -K opswift stat
    swift -A http://serverc.lab.example.com:80/auth/1.0 -U operator:swift -K opswift list
    testbucket
    swift -A http://serverc.lab.example.com:80/auth/1.0 -U operator:swift -K opswift post testcontainer
    swift -A http://serverc.lab.example.com:80/auth/1.0 -U operator:swift -K opswift list
    testbucket
    testcontainer
    dd if=/dev/zero of=/tmp/swift.dat bs=1024K count=10
    swift -A http://serverc.lab.example.com:80/auth/1.0 -U operator:swift -K opswift upload testcontainer /tmp/swift.dat
    tmp/swift.dat
    
    swift -A http://serverc.lab.example.com:80/auth/1.0 -U operator:swift -K opswift stat
    swift -A http://serverc.lab.example.com:80/auth/1.0 -U operator:swift -K opswift stat testcontainer

## Section 3 - Access in multisite 

On node servera

    swift -V 1.0 -A http://serverf.lab.example.com:80/auth/v1 -U operator:swift -K opswift stat testcontainer    
    swift -V 1.0 -A http://serverf.lab.example.com:80/auth/v1 -U operator:swift -K opswift download testcontainer tmp/swift.dat

# Part 10 - cephfs (ceph file share)

## Section 1 - cephfs - Deploy

### client to ceph : admin

On clienta as ceph admin

    ceph osd pool create mycephfs_data
    ceph osd pool create mycephfs_metadata
    ceph fs new mycephfs mycephfs_metadata mycephfs_data
    ceph orch apply mds mycephfs --placement="1 serverc.lab.example.com"
    ceph mds stat
    ceph status
    ceph df
    ls -l /etc/ceph
    -rw-r--r--. 1 root root 63 Sep 17 21:42 ceph.client.admin.keyring

On clienta as cephfs client - admin user

    yum install ceph-common -y
    mkdir /mnt/mycephfs
    [root@clienta /root]# ls -l /etc/ceph
    -rw-r--r--. 1 root root 63 Sep 17 21:42 ceph.client.admin.keyring
    mount.ceph serverc.lab.example.com:/ /mnt/mycephfs -o name=admin
    
    df -h
    mkdir /mnt/mycephfs/dir1
    mkdir /mnt/mycephfs/dir2
    ls -al /mnt/mycephfs/
    touch /mnt/mycephfs/dir1/atestfile
    dd if=/dev/zero of=/mnt/mycephfs/dir1/ddtest bs=1024 count=10000
    umount /mnt/mycephfs

On clienta as ceph admin

    cephadm shell -- ceph fs status

### client to ceph : restricted user

On clienta as cephfs admin

    cephadm shell --mount /etc/ceph
    ceph fs authorize mycephfs client.restricteduser / r /dir2 rw
    ceph auth get client.restricteduser -o /etc/ceph/ceph.client.restricteduser.keyring

On clienta as cephfs client - restricted user
    
    mount.ceph serverc.lab.example.com:/ /mnt/mycephfs -o name=restricteduser,fs=mycephfs
    tree /mnt
    /mnt
    └── mycephfs
        ├── dir1
        │ ├── atestfile
        │ └── ddtest
        └── dir2
    touch /mnt/mycephfs/dir1/restricteduser_file1
    Permission denied
    touch /mnt/mycephfs/dir2/restricteduser_file2
    umount /mnt/mycephfs
### cephfuse

On clienta as cephfs client - restricted user
    
    yum install ceph-fuse
    mkdir /mnt/mycephfuse
    ceph-fuse -n client.restricteduser --client_fs mycephfs /mnt/mycephfuse
    tree /mnt
    /mnt
    ├── mycephfs
    └── mycephfuse
        ├── dir1
        │ ├── atestfile
        │ └── ddtest
        └── dir2
    umount /mnt/mycephfuse

Mount at boot

    echo "serverc.lab.example.com:/ /mnt/mycephfuse fuse.ceph ceph.id=restricteduser,_netdev" >> /etc/fstab
    cat /etc/fstab
    mount -a
    df -h
    umount /mnt/mycephfuse

## Section 2 - cephfs - managing file

### setfattr

On clienta as cephfs admin - setfattr

    mount.ceph serverc.lab.example.com:/ /mnt/mycephfs -o name=admin
    tree /mnt
    touch /mnt/mycephfs/dir1/ddtest
    getfattr -n ceph.dir.layout /mnt/mycephfs/dir1
    /mnt/mycephfs/dir1: ceph.dir.layout: No such attribute
    
    setfattr -n ceph.dir.layout.stripe_count -v 2 /mnt/mycephfs/dir1
    getfattr -n ceph.dir.layout /mnt/mycephfs/dir1
    stripe_count=2
    
    getfattr -n ceph.file.layout /mnt/mycephfs/dir1/ddtest
    stripe_count=1

    touch /mnt/mycephfs/dir1/anewfile
    tree /mnt
    getfattr -n ceph.file.layout /mnt/mycephfs/dir1/anewfile
    stripe_count=2

    setfattr -n ceph.file.layout.stripe_count -v 3 /mnt/mycephfs/dir1/anewfile
    getfattr -n ceph.file.layout /mnt/mycephfs/dir1/anewfile
    stripe_count=3

    echo "Not empty" > /mnt/mycephfs/dir1/anewfile
    setfattr -n ceph.file.layout.stripe_count -v 4 /mnt/mycephfs/dir1/anewfile
    setfattr: /mnt/mycephfs/dir1/anewfile: Directory not empty

    setfattr -x ceph.dir.layout /mnt/mycephfs/dir1
    touch /mnt/mycephfs/dir1/a3rdfile
    getfattr -n ceph.file.layout /mnt/mycephfs/dir1/a3rdfile
    stripe_count=1

    umount /mnt/mycephfs

### snapshot

On clienta as cephfs admin

    mount.ceph serverc.lab.example.com:/ /mnt/mycephfs -o name=restricteduser
    ls -la /mnt/mycephfs/
    cd /mnt/mycephfs/.snap
    mkdir mysnapshot
    mkdir: cannot create directory ‘mysnapshot’: Permission denied

    ceph auth get client.restricteduser
    caps mds = "allow r fsname=mycephfs, allow rw fsname=mycephfs path=/dir2"

    ceph auth caps client.restricteduser mds 'allow rws fsname=mycephfs' mon 'allow r fsname=mycephfs' osd 'allow rw tag cephfs data=mycephfs'
    cd /root
    umount /mnt/mycephfs/
    mount.ceph serverc.lab.example.com:/ /mnt/mycephfs -o name=restricteduser
    
    tree /mnt/mycephfs
    /mnt/mycephfs
    └── dir1
        ├── a3rdfile
        ├── anewfile
        ├── atestfile
        └── ddtest

    tree /mnt/mycephfs/.snap/mysnapshot
    /mnt/mycephfs/.snap/mysnapshot
    └── dir1
        ├── a3rdfile
        ├── anewfile
        ├── atestfile
        └── ddtest
    rmdir mysnapshot
    mkdir snapshot1
    tree /mnt/mycephfs/.snap/snapshot1
    
    touch /mnt/mycephfs/dir1/a4thfile
    touch /mnt/mycephfs/dir2/a5thfile
    mkdir snapshot2
    tree /mnt/mycephfs/.snap/snapshot1
    tree /mnt/mycephfs/.snap/snapshot2

On clienta as cephfs admin

    ceph mgr module enable snap_schedule
    ceph fs snap-schedule add / 1h
    ceph fs snap-schedule status / | jq

Wait for several time

    ls /mnt/mycephfs/.snap

# Part 11 - Cluster

## Section 1 - Monitoring

Ceph module

    ceph mgr module ls | more
    ceph mgr services
    ceph osd stat
    ceph osd find 2

OSD service

    sudo systemctl list-units "ceph*"
    sudo systemctl stop ceph-ff97a876-1fd2-11ec-8258-52540000fa0c@osd.2.service
    ceph osd stat
    journalctl -u ceph-ff97a876-1fd2-11ec-8258-52540000fa 0c@osd.2.service | grep systemd
    sudo systemctl start ceph-ff97a876-1fd2-11ec-8258-52540000fa0c@osd.2.service

OSD in out

    ceph osd out 4
    ceph osd stat
    ceph osd tree
    ceph osd df tree
    
    ceph osd out 4

    33 remapped pgs
    hdd 0.00980 osd.4 up 0 1.00000
    ceph osd in 4
    ceph osd tree
    ceph osd df tree

PG stat

    ceph pg stat
    ceph osd pool create testpool 32 32
    rados -p testpool put testobject /etc/ceph/ceph.conf
    ceph osd map testpool testobject
    osdmap e332 pool 'testpool' (9) object 'testobject' -> pg 9.98824931 (9.11) -> up ([8,2,5], p8) acting ([8,2,5], p8)
    ceph pg 9.11 query
    ceph versions
    ceph tell osd.* version
    ceph balancer status

## Section 2 - Maintenance

### Cluster settings
Set the noscrub and nodeep-scrub flags to prevent the cluster from starting scrubbing
operations temporarily.

On node clienta

    ceph osd set noscrub
    ceph osd set nodeep-scrub
    ceph health detail

    ceph osd tree | grep -i down
    osd.3 down
    ceph osd find osd.3
    "osd": 3, "host": "serverd.lab.example.com",

On node serverd

    cephadm shell
    ceph-volume lvm list

    systemctl list-units --all "ceph*"
    journalctl -ru ceph-2ae6d05a-229a-11ec-925e-52540000fa0c@osd.3.service
    systemctl start ceph-2ae6d05a-229a-11ec-925e-52540000fa0c@osd.3.service

    ceph orch daemon start osd.3

 On node clienta
 
    ceph osd unset noscrub
    ceph osd unset nodeep-scrub
    ceph -w

### Cluster Scale

Add MON daemon on node serverg

    ceph orch ls --service_type=mon
    ceph cephadm get-pub-key > /root/ceph.pub
    ssh-copy-id -f -i /root/ceph.pub root@serverg.lab.example.com

On serverc run preflight    

    yum install -y cephadm-ansible
    cd /usr/share/cephadm-ansible
    vi hostserverg
    serverg.lab.example.com
    ansible-playbook -i hostserverg cephadm-preflight.yml --extra-vars "ceph_origin="

On clienta, add HOST serverg

    ceph orch host ls
    ceph orch host add serverg.lab.example.com

Add MON serverg    

    ceph orch apply mon --placement="clienta.lab.example.com serverc.lab.example.com serverd.lab.example.com servere.lab.example.com serverg.lab.example.com"
    ceph orch ls --service_type=mon
    ceph mon stat
    
Remove MON serverg    
    
    ceph orch apply mon --placement="clienta.lab.example.com serverc.lab.example.com serverd.lab.example.com servere.lab.example.com"
    ceph orch ls --service_type=mon
    ceph mon stat

Remove HOST serverg

    ceph orch ps serverg.lab.example.com
    ceph orch host drain serverg.lab.example.com
    ceph orch host rm serverg.lab.example.com
    ceph orch host ls

Maintenance HOST servere

    ceph orch host ok-to-stop serverg.lab.example.com
    ceph orch host maintenance enter serverg.lab.example.com
    ceph orch host ls
    ssh admin@servere sudo reboot # reboot HOST servere
    ceph orch host maintenance exit servere.lab.example.com

Maintenance OSD

Stop and start OSD

    systemctl start ceph-2ae6d05a-229a-11ec-925e-52540000fa0c@osd.6.service
    ceph -w
    ceph osd tree | grep -i down
    ceph osd find osd.6 | grep host
    ceph orch daemon start osd.6
    ceph osd tree | grep osd.6

Out OSD deamon osd.5

    ceph osd out 5
    ceph -w

Verify that all PGs have been migrated off of the OSD 5 daemon. It will take some time for the data migration to finish
    
    ceph osd df
    ceph osd in 5
    ceph osd df
    ceph balancer status
    
Object and PG

    ceph osd map pool1 data1
    (6.1c)` -> up ([8,2,3], p8) acting ([8,2,3], p8)
    ceph pg 6.1c query

# Part 12 - Tuning

## Section 1 - Performance

### Settings pg_autoscale_mode

    ceph osd pool create testpool
    ceph health detail
    ceph osd pool autoscale-status
    
    ceph osd pool set testpool pg_autoscale_mode off
    ceph osd pool set testpool pg_num 8
    ceph osd pool autoscale-status
    ceph health detail

Set the PG autoscale option to warn for the pool testpool. Verify that cluster health status is now WARN, because the recommended number of PGs is higher than the current number of PGs.

    ceph osd pool set testpool pg_autoscale_mode warn
    ceph health detail
    Pool testpool has 8 placement groups, should have 32
    
    ceph osd pool set testpool pg_autoscale_mode on
    ceph osd pool autoscale-status

    ceph tell mon.* config get mon_allow_pool_delete
    ceph tell mon.* config set mon_allow_pool_delete true
    ceph osd pool delete testpool testpool  --yes-i-really-really-mean-it
### OSD Affinity  

 Modify the primary affinity settings on an OSD so that it is more likely to be selected as primary for placement groups. 
 Set the primary affinity for OSD 7 to 0

    ceph osd tree
    ceph osd primary-affinity 7 0
    ceph osd tree
    ceph osd dump | grep affinity

    ceph osd pool create benchpool 100 100
    rbd pool init benchpool
    rados -p benchpool bench 30 write
    ceph osd perf
    osd commit_latency(ms) apply_latency(ms)
    7 94 94
    8 117 117
    6 195 195
    ceph tell osd.6 perf dump > perfdump.txt
    
## Section 2 - Tuning performance

    ceph tell osd.0 bluestore allocator score block
    ceph osd tree
    ceph tell osd.0 config get osd_max_backfills
    ceph tell osd.0 config set osd_max_backfills 2
    ceph tell osd.0 config get osd_recovery_max_active
    ceph tell osd.0 config get osd_recovery_max_active_hdd
    ceph tell osd.0 config get osd_recovery_max_active_ssd
    ceph tell osd.0 config set osd_recovery_max_active 1
    ceph tell osd.0 config get osd_recovery_max_active

## Section 3 - Troubleshooting

### Fix time issue 

On node serverd stop chroync and change date

    systemctl stop chronyd
    timedatectl set-time 02:58:30

On clienta, troubleshooting the status

    systemctl status chronyd
    ceph health detail

On serverd go to fix 

    sudo systemctl start chronyd
    systemctl status chronyd
    ceph health detail
    timedatectl  status

### Fix OSD down issue

On node serverc stop the service osd.0

    sudo systemctl stop ceph-2ae6...fa0c@osd.0.service

On clienta, troubleshooting the status

    ceph health detail
    ceph osd tree
    serverc
    0 hdd 0.00980 osd.0 down 0 1.00000
    
On node serverc    

    systemctl list-units --all 'ceph*'
    ceph-2ae6...fa0c@osd.0.service loaded inactive dead
   
    sudo systemctl start ceph-2ae6...fa0c@osd.0.service
    systemctl status ceph-2ae6...fa0c@osd.0.service
    ceph osd tree
    0 hdd 0.00980 osd.0 up 1.00000 1.00000

### Setlog file for OSD

On node servere, change the cluster of osd.4 to make it get problem
    
    ceph config set osd.4 cluster_network 192.168.0.0/24
    ceph orch daemon restart osd.4

On clienta, troubleshooting the status

    ceph osd tree
    hdd 0.00980 osd.4 down 1.00000 1.00000
    ceph orch daemon restart osd.4
    ceph tell osd.4 config show

On node servere, troubleshooting the status

    systemctl list-units --all 'ceph*'
    sudo systemctl restart ceph-2ae6d05a-229a-11ec-925e-52540000fa0c@osd.4.service

On clienta, set log

    ceph config set osd.4 log_file /var/log/ceph/myosd4.log
    ceph config set osd.4 log_to_file true
    ceph config set osd.4 debug_ms 1
    ceph orch daemon restart osd.4

On node servere, troubleshooting the status

    sudo cat /var/log/ceph/2ae6d05a-229a-11ec-925e-52540000fa0c/myosd4.log

On clienta, change cluster network of osd.4

    ceph config get osd.4 cluster_network
    172.25.249.0/24
    ceph config set osd.4 cluster_network 192.168.126.0/24
    ceph config get osd.4
    ceph orch daemon restart osd.4
    ceph osd tree

 ### Set for OSD  

    ceph tell osd.5 config set osd_op_history_size 40
    ceph tell osd.5 config set osd_op_history_duration 700
    ceph tell osd.5 dump_historic_ops | head -n 3
    ceph tell osd.* config set osd_max_backfills 3
    ceph tell osd.* config set osd_recovery_max_active 1
    

