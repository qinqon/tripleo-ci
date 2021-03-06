#!/bin/bash

sudo bash <<-EOF &> /var/log/host_info.txt
set -x
export PATH=\$PATH:/sbin
ps -eaufxZ
ls -Z /var/run/
df -h
uptime
sudo netstat -lpn
sudo iptables-save
sudo ip6tables-save
sudo ovs-vsctl show
ip addr
ip route
ip -6 route
free -h
top -n 1 -b -o RES
rpm -qa | sort
yum repolist -v
sudo os-collect-config --print
which pcs &> /dev/null && sudo pcs status --full
which pcs &> /dev/null && sudo pcs constraint show --full
which pcs &> /dev/null && sudo pcs stonith show --full
which crm_verify &> /dev/null && sudo crm_verify -L -VVVVVV
which ceph &> /dev/null && sudo ceph status
sudo facter
find ~jenkins -iname tripleo-overcloud-passwords -execdir cat '{}' ';'
sudo systemctl list-units --full --all
EOF

if [ -e ~/stackrc ] ; then
    source ~/stackrc

    nova list | tee /tmp/nova-list.txt
    openstack workflow list
    openstack workflow execution list
    # If there's no overcloud then there's no point in continuing
    openstack stack show --no-resolve-outputs --format yaml overcloud || (echo 'No active overcloud found' && exit 0)
    openstack stack resource list -n5 --format yaml overcloud
    openstack stack event list overcloud
    # --nested-depth 2 seems to get us a reasonable list of resources without
    # taking an excessive amount of time
    openstack stack event list --nested-depth 2 -f json overcloud | $TRIPLEO_ROOT/tripleo-ci/scripts/heat-deploy-times.py | tee /var/log/heat-deploy-times.log || echo 'Failed to process resource deployment times. This is expected for stable/liberty.'
    # useful to see what failed when puppet fails
    # NOTE(bnemec): openstack stack failures list only exists in Newton and above.
    # On older releases we still need to manually query the deployments.
    openstack stack failures list --long overcloud || for failed_deployment in $(heat resource-list --nested-depth 5 overcloud | grep FAILED | grep 'StructuredDeployment ' | cut -d '|' -f3); do heat deployment-show $failed_deployment; done;
fi
