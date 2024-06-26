#!/bin/bash
#
# Performance test
#
# Bug SW #1251244: Poor performance with UDP traffic in HV using namespaces
#

my_dir="$(dirname "$0")"
. $my_dir/common.sh

IP1="7.7.7.1"
IP2="7.7.7.2"

function cleanup() {
    ip netns del ns0 2> /dev/null
    ip netns del ns1 2> /dev/null
}

enable_switchdev
bind_vfs

require_interfaces VF VF2 REP REP2
cleanup
start_clean_openvswitch
config_vf ns0 $VF $REP $IP1
config_vf ns1 $VF2 $REP2 $IP2
BR=ov1
ovs-vsctl add-br $BR
ovs-vsctl add-port $BR $REP
ovs-vsctl add-port $BR $REP2

function check_bw() {
    SUM=`cat $TMPFILE | grep ",-1,0.0-10." | tail -n1`
    BW=${SUM##*,}

    if [ -z "$SUM" ]; then
        cat $TMPFILE
        err "Missing sum line"
        return
    fi

    if [ -z "$BW" ]; then
        err "Missing bw"
        return
    fi

    min_expected1=`numfmt --to=iec $min_expected`
    bw1=`numfmt --to=iec $BW`
    log "Min expected BW $min_expected1"

    if (( $BW < $min_expected )); then
        err "Expected minimum BW of $min_expected1 and got $bw1"
    else
        success
    fi
}

function test_tcp() {
    # on inbox kernels we get 40+ but on custom kernels with min-config we compile we get 20+
    let min_expected=20*1024*1024*1024
    title "Test iperf tcp $VF($IP1) -> $VF2($IP2)"
    TMPFILE=/tmp/iperf.log
    ip netns exec ns0 timeout 11 iperf -s &
    sleep 0.5
    ip netns exec ns1 timeout 11 iperf -c $IP1 -i 5 -t 10 -y c -P2 > $TMPFILE &
    sleep 11
    killall -9 iperf &>/dev/null
    sleep 0.5
}

function test_udp() {
    # we usually get ~9 but with min-config we use we get sometimes 7+
    let min_expected=7*1024*1024*1024
    title "Test iperf udp $VF($IP1) -> $VF2($IP2)"
    TMPFILE=/tmp/iperf.log
    ip netns exec ns0 timeout 11 iperf -u -s &
    sleep 0.5
    ip netns exec ns1 timeout 11 iperf -u -c $IP1 -i 5 -t 10 -y c -b10G -P2 > $TMPFILE &
    sleep 11
    killall -9 iperf &>/dev/null
    sleep 0.5
}

test_tcp
check_bw

test_udp
check_bw

ovs_clear_bridges
cleanup
test_done
