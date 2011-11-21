# Copyright (C) 2011 Fundacio Privada per a la Xarxa Oberta, Lliure i Neutral guifi.net
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#    The full GNU General Public License is included in this distribution in
#    the file called "COPYING".

QMP_PATH="/etc/qmp"

. $QMP_PATH/qmp_common.sh
. $QMP_PATH/qmp_functions.sh
. $QMP_PATH/qmp_gw.sh
. $QMP_PATH/qmp_wireless.sh
. $QMP_PATH/qmp_network.sh

offer_default_gw() {
	qmp_gw_offer_default
	qmp_gw_apply
}

search_default_gw() {
	qmp_gw_search_default
	qmp_gw_apply
}

apply_wifi() {
	qmp_configure_wifi_initial 
	qmp_configure_wifi
	wifi
}

apply_netserver() {                                                                                    
        [ "$(qmp_uci_get networks.netserver)" == "1" ] && qmp_enable_netserver || qmp_disable_netserver
}  

apply_network() {
	qmp_configure
	/etc/init.d/network restart
	ifup -a
	/etc/init.d/olsrd restart
	/etc/init.d/bmx6 restart
	/etc/init.d/dnsmasq restart
	/etc/init.d/firewall restart
	apply_netserver
}

help() {
	echo "Use: $0 <function> [params]"
	echo ""
	echo "Available functions:"
	echo "  offer_default_gw  : Offers default gw to the network"
	echo "  search_default_gw : Search for a default gw in the network" 
	echo "  apply_wifi        : Apply current wifi configuration"
	echo "  apply_network     : Apply current network configuration"
	echo "  apply_netserver   : Start/stop nerserver depending on qmp configuration"
	echo ""
}


[ -z "$1" ] && { help; exit 0; }

echo "executing function $1"
$@

