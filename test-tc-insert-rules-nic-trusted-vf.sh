#!/bin/bash
#
# Test rules on nic mode. i.e. VF.
# Expected to support prios 1-16. so can't use default prio 0 which makes the kernel generate a prio
# which could be higher.
#
# Bug SW #2859923: [Upstream] Failed to create chains table err -22 for prios 3-16 on nic mode

my_dir="$(dirname "$0")"
. $my_dir/common.sh


function test_basic_L2() {
    tc_filter_success add dev $VF protocol ip parent ffff: \
            prio 1 flower \
                    skip_sw \
                    dst_mac e4:11:22:11:4a:51 \
                    src_mac e4:11:22:11:4a:50 \
            action drop
}

function test_basic_L2_redirect() {
    tc_filter_success add dev $VF protocol ip parent ffff: \
            prio 1 flower \
                    skip_sw \
                    dst_mac e4:11:22:11:4a:51 \
                    src_mac e4:11:22:11:4a:50 \
            action mirred egress redirect dev $NIC
}

function test_basic_L3() {
    tc_filter_success add dev $VF protocol ip parent ffff: \
            prio 1 flower \
                    skip_sw \
                    dst_mac e4:11:22:11:4a:51 \
                    src_mac e4:11:22:11:4a:50 \
                    src_ip 1.1.1.1 \
                    dst_ip 2.2.2.2 \
            action drop
}

function test_basic_L3_ipv6() {
    tc_filter_success add dev $VF protocol ipv6 parent ffff: \
            prio 1 flower \
                    skip_sw \
                    dst_mac e4:11:22:11:4a:51 \
                    src_mac e4:11:22:11:4a:50 \
                    src_ip 2001:0db8:85a3::8a2e:0370:7334\
                    dst_ip 2001:0db8:85a3::8a2e:0370:7335 \
            action drop
}

function test_basic_L4() {
    tc_filter_success add dev $VF protocol ip parent ffff: \
            prio 1 flower \
                    skip_sw \
                    dst_mac e4:11:22:11:4a:51 \
                    src_mac e4:11:22:11:4a:50 \
                    ip_proto tcp \
                    src_ip 1.1.1.1 \
                    dst_ip 2.2.2.2 \
            action drop
}

function test_prio1_to_prio16() {
    local prio
    for prio in `seq 1 16`; do
        tc_filter_success add dev $VF protocol ip parent ffff: \
                prio $prio flower \
                        skip_sw \
                        dst_mac e4:11:22:11:4a:51 \
                        src_mac e4:11:22:11:4a:50 \
                        ip_proto tcp \
                        src_ip 1.1.1.1 \
                        dst_ip 2.2.2.2 \
                action drop
    done
}


require_mlxreg
config_sriov
enable_legacy
unbind_vfs
title "Set vf trusted mode"
set_trusted_vf_mode $NIC
bind_vfs
reset_tc $VF

# Execute all test_* functions
for i in `declare -F | awk {'print $3'} | grep ^test_ | grep -v test_done` ; do
    title $i
    eval $i
    reset_tc $VF
done

# reload modules to clear trusted vf mode
reload_modules

test_done
