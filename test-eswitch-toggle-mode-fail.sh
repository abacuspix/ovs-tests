#!/bin/bash
#
# Test toggle e-switch mode and expect to fail
# Purpose to test the error flow. for issue, memleak, etc.
#
# Bug SW #2431774: memleak when failing to change to switchdev mode

my_dir="$(dirname "$0")"
. $my_dir/common.sh


enable_legacy
bind_vfs
__ignore_errors=1
add_expected_error_msg "Failed to create slow path FDB Table"
add_expected_error_msg "Failed creating dr flow_table"
add_expected_error_msg "0x98afbb"
switch_mode_switchdev
__ignore_errors=0

m=`get_eswitch_mode`
if [ "$m" == "legacy" ]; then
    success "Expected to fail"
else
    err "Expected to fail"
fi

if is_ofed ; then
    reload_modules
    config_sriov
fi

test_done
