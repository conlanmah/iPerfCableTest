#!/usr/bin/env bash

# Version 2
# this now has 5 args, 
# eth1 eth2 threadcount mtu time 
#
# eth1 and eth2 the interface names 
# 
# threadcound should be total expected bandwidth/10 then you might need to optimise, 
# going above the number of actual cores is not a great idea in general, 
# and if you are using QSF's then a minimum of 4 is recomended. 
# 10G = 1 
# 40G = 4
# 100G = 8 or 12
# 
# mtu is usually 1500 but can be set upto 9000 usually - see jumbo frames for more info online 
# not all NIC's/Networks support larger frame sizes. 
# 
# time - in seconds for longer or shorter testing. 
# 
# also added the interval of 10 for anything longer to give some feedback so you can see it's actually running. 
#
# Expected results with mtu at 1500
# 1G = 940Mb/s
# 10G = 9.3Gb/s
# 40G = 37.5 Gb/s

### TODO
# Default usage of 2 NIC's
# option processing
# pretty output
# quick failure

printUsage() {
    echo \
'
Usage: ${0} [OPTIONS] [INTERFACE_1] [INTERFACE_2] 
       ${0} [OPTIONS]

Options:
    -t  Time in seconds to test for (default 10)

    -c  Thread count, should be bandwidth / 10, but do not
        exceed amount of CPU cores available
        10G = 1, 40G = 4, 100G = 8 or 12
        (default 1)

    -m  mtu (default 1500)

    -v verbose mode

Description:
    This tool allows a device with two ethernet NIC`s to
    test a cable for reliability and speed. By default,
    the two available NIC`s are used. If there are less
    than 2, this script cannot run. If there are more
    than 2, the interfaces must be specified.
'
}

explain () {
    (( VERBOSE )) || return
    echo "${0} [verbose]: ${1}"
}

debug () {
    (( DEBUG )) || return
    for var; do printf '%s [debug]: Variable %s = "%s"\n' " ${0}" "${var}" "${!var}" >&2
    done
}

DEBUG=1

# Default values
mtu=1500
threadcount=1
duration=10

while getopts t:c:m:vh opt; do
    case "$opt" in
        t) duration="$OPTARG";;
        c) threadcount="$OPTARG";;
        m) mtu="$OPTARG";;
        v) VERBOSE=1;;
        ?) printUsage; exit 0;;
        \?) printUsage; exit 1;;
    esac
done

# Remove processed options from the arguments
shift $((OPTIND - 1))

explain "Interfaces found: $(ls /sys/class/net | grep -E '^e(n|th)' | tr '\n' ', ')"
eth_ifaces=($(ls /sys/class/net | grep -E '^e(n|th)'))

if [ "${#eth_ifaces[@]}" -lt 2 ]; then
    echo "Less than 2 interfaces found, cannot continue."
    echo "Exiting..."
    exit 1
elif [ "${#eth_ifaces[@]}" -eq 2 ]; then
    explain "Exactly 2 interfaces found."
    int1=${eth_ifaces[0]}
    int2=${eth_ifaces[1]}
else
    int1=$1
    int2=$2
fi

debug int1 int2 mtu threadcount duration

if [[ -z "$int1" || -z "$int2" ]]; then
    echo "Interfaces not specified, please specify two interfaces."
    echo "Interfaces found: $(ls /sys/class/net | grep -E '^e(n|th)' | tr '\n' ', ')"
    echo "Exiting..."
    exit 1
fi


ip link set $int1 mtu $mtu 
ip link set $int2 mtu $mtu

ip netns add ns_server
ip netns add ns_client
ip link set $int1 netns ns_server
ip link set $int2 netns ns_client
ip netns exec ns_server ip addr add dev $int1 192.168.10.1/24
ip netns exec ns_client ip addr add dev $int2 192.168.10.2/24
ip netns exec ns_server ip link set dev $int1 up
ip netns exec ns_client ip link set dev $int2 up

ip netns exec ns_server iperf -s &
ip netns exec ns_client iperf -c 192.168.10.1 -P $threadcount -t $duration -i 10

killall iperf

ip netns exec ns_client iperf -s &
ip netns exec ns_server iperf -c 192.168.10.2 -P $threadcount -t $duration -i 10

killall iperf

ip netns del ns_server
ip netns del ns_client 
