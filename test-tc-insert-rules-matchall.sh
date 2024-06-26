#!/bin/bash
#
# Test basic matchall rule
#
# Bug SW #1909500: Rate limit is not working in openstack ( tc rule not in hw)

my_dir="$(dirname "$0")"
. $my_dir/common.sh

require_module cls_matchall act_police

function test_basic_matchall_rep() {
    title "Test matchall rule on REP $REP"

    reset_tc $REP
    tc_filter_success add dev $REP ingress prio 1 protocol ip matchall skip_sw action police rate 1mbit burst 20k conform-exceed drop/continue
    reset_tc $REP
}

function test_basic_matchall_uplink_rep() {
    title "Test matchall rule on uplink rep $NIC - expected to fail"

    reset_tc $NIC
    tc filter add dev $NIC ingress prio 1 protocol ip matchall skip_sw action police rate 1mbit burst 20k conform-exceed drop/continue &>/tmp/log
    [ $? -ne 0 ] && success && return
    err "Expected to fail on uplink rep"
    reset_tc $NIC
}


enable_switchdev
test_basic_matchall_rep
test_basic_matchall_uplink_rep
test_done
