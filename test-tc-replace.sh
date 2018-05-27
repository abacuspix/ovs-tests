#!/bin/bash
#
# Test that verified tc replace flower rule cause syndrome
#
# Bug SW #988519: Trying to replace a flower rule cause a syndrome and rule to be deleted
#

NIC=${1:-ens5f0}

my_dir="$(dirname "$0")"
. $my_dir/common.sh


title "Test tc filter replace"
start_check_syndrome
reset_tc_nic $NIC

for i in `seq 10`; do
    tc filter replace dev $NIC protocol 0x806 parent ffff: prio 8 handle 0x1 flower  dst_mac e4:11:22:11:4a:51 src_mac e4:11:22:11:4a:50 action drop
done

check_syndrome || err "Failed"
tc filter show dev $NIC ingress | egrep -z "not_in_hw" && err "Expected in_hw rule"

reset_tc_nic $NIC
test_done
