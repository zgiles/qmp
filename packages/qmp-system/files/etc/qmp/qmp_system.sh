#!/bin/sh
QMP_PATH="/etc/qmp"
SOURCE_SYS=1

. $QMP_PATH/qmp_common.sh
[ -z "$SOURCE_GW" ] && . $QMP_PATH/qmp_gw.sh
[ -z "$SOURCE_NET" ] && . $QMP_PATH/qmp_network.sh

qmp_configure_system() {

	if [ -n "$(qmp_uci_get node.community_node_id)" ]; then
		local community_node_id=$(qmp_uci_get node.community_node_id)
	else
		local community_node_id=$(qmp_get_id_hostname)
		qmp_uci_set node.community_node_id $community_node_id
	fi

	# check if community_node_id is hexadecimal and get last 4 characters
	community_node_id="$(echo -n $community_node_id | tr -cd 'ABCDEFabcdef0123456789' | tail -c 4)"

	[ $(echo -n $community_node_id | wc -c) -lt 4 ] && {
		qmp_log "Warning, community_node_id not defined properly, using failsafe 0000"
		community_node_id=0000
	}

	local community_id="$(qmp_uci_get node.community_id)"
	[ -z "$community_id" ] && community_id="qmp" && qmp_uci_set node.community_id $community_id

	# set hostname
	uci set system.@system[0].hostname="${community_id}-${community_node_id}"
	uci commit system
	echo "${community_id}-${community_node_id}" > /proc/sys/kernel/hostname

	uci set uhttpd.main.listen_http="80"
	uci set uhttpd.main.listen_https="443"
	uci commit uhttpd
	/etc/init.d/uhttpd restart

	# configuring hosts
	qmp_set_hosts

	# configure maps
	qmp_set_maps
}

qmp_set_hosts() {
	qmp_log "Configuring /etc/hosts file with qmpadmin entry"

	local ip=$(uci get bmx7.general.tun4Address | cut -d'/' -f1)
	local hn=$(uci get system.@system[0].hostname)

	if [ -z "$ip" -o -z "$hn" ]; then
		echo "Cannot get IP or HostName"
		return
	fi

	if [ $(cat /etc/hosts | grep -c "^$ip.*qmpadmin") -eq 0 ]; then
		cat /etc/hosts | grep -v qmpadmin > /tmp/hosts.tmp
		echo "$ip $hn admin.qmp qmpadmin" >> /tmp/hosts.tmp
		cp /tmp/hosts.tmp /etc/hosts
	fi
}

qmp_set_maps() {
	[ $(qmp_uci_get services.libremap) -eq 1 ] && {
		qmp_uci_get_raw libremap.location && {
			local lat="$(qmp_uci_get node.latitude)"
			local lon="$(qmp_uci_get node.longitude)"
			local elev="$(qmp_uci_get node.elevation)"
			[ -n "$lat" ] && [ -n "$lon" ] && {
				elev=${elev:-0}
				qmp_uci_set_raw libremap.location.latitude="$lat"
				qmp_uci_set_raw libremap.location.longitude="$lon"
				qmp_uci_set_raw libremap.location.elev="$elev"
			}
		}
	}


}

# -----------------------------------
#          Services section
# -----------------------------------

qmp_enable_netserver() {
	qmp_log Enabling service netserver
	qmp_disable_service netserver
	killall -9 netserver 2>/dev/null
	netserver -6 -p 12865
	return 0
}

qmp_disable_netserver() {
	qmp_log Disabling service netserver
	qmp_disable_service netserver
	killall -9 netserver 2>/dev/null
	return 0
}

qmp_enable_service() {
	qmp_log Enabling service $1
	/etc/init.d/$1 start
	/etc/init.d/$1 enable
	return 0
}

qmp_disable_service() {
	qmp_log Disabling service $1
	/etc/init.d/$1 stop 2>/dev/null
	/etc/init.d/$1 disable
	return 0
}

qmp_list_services() {
	echo "$(uci show qmp.services | cut -d. -f3 | cut -d= -f1 | grep .)"
}

qmp_set_services() {
	local s
	for s in $(qmp_list_services); do

		[ "$s" == "vpn" ] && [ -e /etc/init.d/synctincvpn ] && {
			[ $(qmp_uci_get services.$s) -eq 1 ] &&
			qmp_enable_service synctincvpn || qmp_disable_service synctincvpn

		}

		[ "$s" == "captive_portal" ] && [ -e /etc/init.d/tinyproxy ] && {
			[ $(qmp_uci_get services.$s) -eq 1 ] &&
			qmp_enable_service tinyproxy || qmp_disable_service tinyproxy
		}

		[ "$s" == "libremap" ] && [ -e /etc/init.d/libremap ] && {
			[ $(qmp_uci_get services.$s) -eq 1 ] &&
			qmp_enable_service libremap || qmp_disable_service libremap
		}

		[ "$s" == "b6m" ] && [ -e /etc/init.d/b6m-spread ] && {
			[ $(qmp_uci_get services.$s) -eq 1 ] &&
			qmp_enable_service b6m-spread || qmp_disable_service b6m-spread
		}

		[ "$s" == "gwck" ] && [ -e /etc/init.d/gwck ] && {
			[ $(qmp_uci_get services.$s) -eq 1 ] &&
			qmp_enable_service gwck || qmp_disable_service gwck
		}

		[ "$s" == "auto_upgrade" ] && {
			true
		}

		[ "$s" == "mesh_dns" ] && [ -e /etc/init.d/mdns ] && {
			[ $(qmp_uci_get services.$s) -eq 1 ] &&
			qmp_enable_service mdns || qmp_disable_service mdns
		}

		[ "$s" == "bwtest" ] && [ -n "$(which netserver)" ] && {
			[ $(qmp_uci_get services.$s) -eq 1 ] &&
			qmp_enable_netserver || qmp_disable_netserver
		}

		[ "$s" == "munin" ] && [ -e /etc/init.d/munin ] && {
			[ $(qmp_uci_get services.$s) -eq 1 ] &&
			qmp_enable_service munin || qmp_disable_service munin
		}

		done
	uci commit qmp
}
