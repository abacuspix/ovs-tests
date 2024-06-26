#!/bin/bash
#
# Test OVS CT with vxlan traffic
#
# Require external server
#

my_dir="$(dirname "$0")"
. $my_dir/common.sh
pktgen=$DIR/scapy-traffic-tester.py

require_module act_ct
require_remote_server

IP=1.1.1.7
REMOTE=1.1.1.8

LOCAL_TUN=7.7.7.7
REMOTE_IP=7.7.7.8
VXLAN_ID=42

config_sriov
enable_switchdev
require_interfaces REP NIC
unbind_vfs
bind_vfs


function set_nf_liberal() {
    nf_liberal="/proc/sys/net/netfilter/nf_conntrack_tcp_be_liberal"
    if [ -e $nf_liberal ]; then
        echo 1 > $nf_liberal
        echo "`basename $nf_liberal` set to: `cat $nf_liberal`"
    else
        echo "Cannot find $nf_liberal"
    fi
}

function cleanup() {
    stop
    ip a flush dev $NIC
    ip netns del ns0 &>/dev/null
    cleanup_remote_vxlan
    sleep 0.5
}
trap cleanup EXIT

function config() {
    cleanup
    set_nf_liberal
    conntrack -F
    ifconfig $NIC $LOCAL_TUN/24 up
    # WA SimX bug? interface not receiving traffic from tap device to down&up to fix it.
    for i in $NIC $VF $REP ; do
            ifconfig $i down
            ifconfig $i up
            reset_tc $i
    done
    ip netns add ns0
    ip link set dev $VF netns ns0
    ip netns exec ns0 ifconfig $VF $IP/24 up
    ip netns exec ns0 ifconfig lo up

    echo "Restarting OVS"
    start_clean_openvswitch

    ovs-vsctl add-br br-ovs
    ovs-vsctl add-port br-ovs $REP
    ovs-vsctl add-port br-ovs vxlan1 -- set interface vxlan1 type=vxlan options:local_ip=$LOCAL_TUN options:remote_ip=$REMOTE_IP options:key=$VXLAN_ID options:dst_port=4789
}

function add_openflow_rules() {
    ovs-ofctl del-flows br-ovs
    ovs-ofctl add-flow br-ovs arp,actions=normal
    ovs-ofctl add-flow br-ovs icmp,actions=normal
    ovs-ofctl add-flow br-ovs "table=0, udp,ct_state=-trk actions=ct(table=1)"
    ovs-ofctl add-flow br-ovs "table=1, udp,ct_state=+trk+new actions=ct(commit),normal"
    ovs-ofctl add-flow br-ovs "table=1, udp,ct_state=+trk+est actions=normal"
    ovs-ofctl dump-flows br-ovs --color
}

function stop() {
    [ -n "$pid1" ] && kill $pid1 &>/dev/null
    [ -n "$pid2" ] && kill $pid2 &>/dev/null
    wait $pid2 $pid1 &>/dev/null
    sleep 1
}

function run() {
    config
    config_remote_vxlan
    add_openflow_rules
    sleep 2

    # icmp
    ip netns exec ns0 ping -q -c 1 -w 2 $REMOTE
    if [ $? -ne 0 ]; then
        err "ping failed"
        return
    fi

    t=25
    port_count=6000
    # traffic
    on_remote timeout $t $pktgen -i vxlan1 --src-ip $REMOTE --src-port 1000 --src-port-count $port_count --dst-port $port_count --dst-port-count 1 --pkt-count 1 --inter 0 --dst-ip $IP --time $t &
    pid1=$!
    sleep 2
    timeout $t ip netns exec ns0 $pktgen -i $VF --src-ip $IP --src-port $port_count --src-port-count 1 --dst-port 1000 --dst-port-count $port_count --pkt-count 1 --inter 0 --dst-ip $REMOTE --time $t &
    pid2=$!
    sleep 5

    # verify pids
    kill -0 $pid1 &>/dev/null
    if [ $? -ne 0 ]; then
        err "pktgen server failed"
        stop
        return
    fi
    kill -0 $pid2 &>/dev/null
    if [ $? -ne 0 ]; then
        err "pktgen client failed"
        stop
        return
    fi
    echo "pids ok"

    wait $pid2 $pid1 &>/dev/null

    echo
    echo "verify number of offload flows in connrack ~$port_count"
    count=`cat /proc/net/nf_conntrack | grep -i offload | wc -l`
    echo "flows: $count"
    # allow to miss some its not perfect tool
    let count2=count+200
    if [ "$count2" -lt $port_count ]; then
        err "Expected ~$port_count flows"
    else
        success
    fi

    echo "wait for ovs aging (10 seconds)"
    sleep 12
}

run
ovs-vsctl del-br br-ovs
test_done
