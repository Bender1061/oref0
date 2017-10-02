#!/bin/bash

main() {
    MACs = $@
    echo; echo Starting oref0-online.
    # if we are connected to wifi but don't have an IP, try to get one
    if iwgetid -r wlan0 | egrep -q "[A-Za-z0-9_]+"; then
        if ! ip route | grep default | grep -q wlan0; then
            echo Attempting to renew wlan0 IP
            sudo dhclient wlan0
        fi
    fi
    echo -n "At $(date) my local IP is: "
    print_local_ip wlan0
    print_local_ip bnep0
    echo
    print_wifi_name
    if check_ip; then
        # if we are back on wifi (and have connectivity to checkip.amazonaws.com), shut down bluetooth
        if has_addr wlan0 && has_addr bnep0; then
            bt_disconnect
        fi
    else
        echo
        print_wifi_name
        if ! check_ip; then
            bt_connect
        fi
        print_wifi_name
        if check_ip; then
            # if we're online after activating bluetooth, shut down any local-access hotspot we're running
            stop_hotspot
        else
            # if we can't get online via wifi or bluetooth, start our own local-access hotspot
            start_hotspot
            # if we still can't get online, try cycling networking as a last resort
            #restart_networking
        fi
    fi
    echo Finished oref0-online.
}

function print_wifi_name {
    echo -n "At $(date), my wifi network name is "
    iwgetid -r wlan0 | tr -d '\n'
    echo -n ", and my public IP is: "
}

function print_local_ip {
    ip -4 -o addr show dev $1 | awk '{split($4,a,"/");print a[1]}'
}

function check_ip {
    curl --compressed -4 -s -m 15 checkip.amazonaws.com | awk -F , '{print $NF}' | egrep "^[12]*[0-9]*[0-9]\.[12]*[0-9]*[0-9]\.[12]*[0-9]*[0-9]\.[12]*[0-9]*[0-9]$"
}

function has_addr {
    ifconfig | grep -A1 $1 | grep -q "inet addr"
}

function bt_connect {
    # loop over as many MACs as are provided as arguments
    echo
    for MAC in MACs; do
        echo -n "At $(date) my public IP is: "
        if ! check_ip; then
            echo; echo -n "Error, connecting BT to $MAC"
            oref0-bluetoothup
            sudo bt-pan client $MAC -d
            sudo bt-pan client $MAC
            echo -n ", getting bnep0 IP"
            sudo dhclient bnep0
            # if we couldn't reach the Internet over wifi, but (now) have a bnep0 IP, release the wifi IP/route
            if has_addr wlan0 && has_addr bnep0; then
                echo -n " and releasing wifi IP"
                sudo dhclient wlan0 -r
                echo
                echo Sleeping for 2 minutes before trying wifi again
                sleep 120
            fi
            echo
        fi
    done
    echo
}

function bt_disconnect {
    echo "Back online via wifi; disconnecting BT $MAC"
    ifdown bnep0
    # loop over as many MACs as are provided as arguments
    for MAC in MACs; do
        sudo bt-pan client $MAC -d
    done
    echo "and getting new wlan0 IP"
    ps aux | grep -v grep | grep -q "dhclient wlan0" && sudo killall dhclient
    sudo dhclient wlan0 -r
    sudo dhclient wlan0
}

function start_hotspot {
    echo "Activating client config"
    cp /etc/network/interfaces.client /etc/network/interfaces
    echo "Attempting to stop hostapd"
    /etc/init.d/hostapd stop
    echo "Attempting to stop dnsmasq"
    /etc/init.d/dnsmasq stop
    echo "Renewing IP Address for $Interface"
    dhclient_restart
}

function stop_hotspot {
    echo "Killing wpa_supplicant"
    #killall wpa_supplicant
    wpa_cli terminate
    echo "Activating AP config"
    cp /etc/network/interfaces.ap /etc/network/interfaces
    echo "Attempting to start hostapd"
    /etc/init.d/hostapd start
    echo "Attempting to start dnsmasq"
    /etc/init.d/dnsmasq start
    echo "Stopping networking"
    /etc/init.d/networking stop
    echo "Starting networking"
    /etc/init.d/networking start
    sleep 5
    echo "Setting IP Address for wlan0"
    /sbin/ifconfig wlan0 $HostAPDIP netmask 255.255.255.0 up
}

function dhclient_restart {
    ps aux | grep -v grep | grep -q "dhclient wlan0" && sudo killall dhclient
    sudo dhclient wlan0 -r
    sudo dhclient wlan0
}

function restart_networking {
    echo; echo "Error, cycling networking "
    sudo /etc/init.d/networking stop
    sleep 5
    sudo /etc/init.d/networking start
    echo "and getting new wlan0 IP"
    dhclient_restart
}

main "$@"
