#!/bin/bash

EASYRSA_DIR="/etc/openvpn/easy-rsa-tun1"
OUTPUT_BASE="/home/df/ovpn"
CCD_DIR="/etc/openvpn/server/ccd"
SERVER="vpn.dftechno.ar"
PORT="1194"
PROTOCOL="udp"
NETWORK="10.10.20"
DNS1="192.168.1.2"
DNS2="192.168.1.4"
SERVER_CONF="/etc/openvpn/server/server.conf"
OVPN_SERVICE="openvpn-server@server"


ACTION=$1
CLIENT=$2
PARAM3=$3
PARAM4=$4
PARAM5=$5

mkdir -p $OUTPUT_BASE
mkdir -p $CCD_DIR

get_next_ip() {
    LAST_IP=$(grep -h ifconfig-push $CCD_DIR/* 2>/dev/null | awk '{print $2}' | awk -F. '{print $4}' | sort -n | tail -1)
    if [ -z "$LAST_IP" ]; then
        echo 10
    else
        echo $((LAST_IP + 1))
    fi
}

ip_exists() {
    grep -q "$1" $CCD_DIR/* 2>/dev/null
}

create_user() {
    if [ -z "$CLIENT" ]; then
        echo "Error: Debe especificar un nombre de usuario."
        exit 1
    fi

    if [ -f "$EASYRSA_DIR/pki/issued/$CLIENT.crt" ]; then
        echo "Error: El usuario '$CLIENT' ya existe."
        exit 1
    fi

    NEXT_IP=$(get_next_ip)
    CLIENT_IP="$NETWORK.$NEXT_IP"

    if ip_exists "$CLIENT_IP"; then
        echo "Error: La IP $CLIENT_IP ya está asignada."
        exit 1
    fi

    cd $EASYRSA_DIR
    EASYRSA_BATCH=1 ./easyrsa build-client-full $CLIENT nopass > /dev/null 2>&1

    mkdir -p $OUTPUT_BASE/$CLIENT

    {
        echo "client"
        echo "dev tun"
        echo "proto $PROTOCOL"
        echo "remote $SERVER $PORT"
        echo "resolv-retry infinite"
        echo "nobind"
        echo "persist-key"
        echo "persist-tun"
        echo "remote-cert-tls server"
        echo "auth SHA256"
        echo "cipher AES-256-GCM"
        echo "verb 3"
        echo "<ca>"
        cat "$EASYRSA_DIR/pki/ca.crt"
        echo "</ca>"
        echo "<cert>"
        awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' "$EASYRSA_DIR/pki/issued/$CLIENT.crt"
        echo "</cert>"
        echo "<key>"
        cat "$EASYRSA_DIR/pki/private/$CLIENT.key"
        echo "</key>"
        echo "<tls-crypt>"
        cat "/etc/openvpn/server/tls-crypt-tun1.key"
        echo "</tls-crypt>"
    } > "$OUTPUT_BASE/$CLIENT/$CLIENT.ovpn"

    if ! grep -qi "client" "$OUTPUT_BASE/$CLIENT/$CLIENT.ovpn"; then
        echo "Error: Fallo al estructurar el archivo .ovpn"
        exit 1
    fi

    echo "ifconfig-push $CLIENT_IP 255.255.255.0" > $CCD_DIR/$CLIENT
    chown -R df:df $OUTPUT_BASE/$CLIENT

    echo "Exito: Usuario '$CLIENT' creado con la IP $CLIENT_IP."
}

revoke_user() {
    if [ -z "$CLIENT" ]; then
        echo "Error: Debe especificar un nombre de usuario."
        exit 1
    fi

    if [ ! -f "$EASYRSA_DIR/pki/issued/$CLIENT.crt" ]; then
        echo "Error: El usuario '$CLIENT' no existe."
        exit 1
    fi

    cd $EASYRSA_DIR
    EASYRSA_BATCH=1 ./easyrsa revoke $CLIENT > /dev/null 2>&1
    EASYRSA_BATCH=1 ./easyrsa gen-crl > /dev/null 2>&1
    cp pki/crl.pem /etc/openvpn/server/crl.pem

    rm -rf $OUTPUT_BASE/$CLIENT
    rm -f $CCD_DIR/$CLIENT

    echo "Exito: Usuario '$CLIENT' revocado y eliminado."
}

list_users() {
    ls $EASYRSA_DIR/pki/issued 2>/dev/null | grep -v server | sed 's/\.crt//'
}

show_ips() {
    grep -H "ifconfig-push" $CCD_DIR/* 2>/dev/null | awk -F'/' '{print $NF}' | sed 's/:ifconfig-push/ /g'
}


set_static_ip() {
    if [ -z "$CLIENT" ] || [ -z "$PARAM3" ]; then
        echo "Error: Debe especificar usuario y la IP."
        exit 1
    fi
    NEW_IP=$PARAM3
    NET_IP=$PARAM4
    NET_MASK=$PARAM5
    FILE="$CCD_DIR/$CLIENT"
    
    if [ -f "$FILE" ]; then
        # Eliminamos líneas previas de red o IP para no duplicar
        sed -i '/^ifconfig-push/d' "$FILE"
        sed -i '/^iroute/d' "$FILE"
        sed -i '/^push "route/d' "$FILE"
    fi
    
    echo "ifconfig-push $NEW_IP 255.255.255.0" >> "$FILE"
    
    # Si se especificó una red, inyectamos las rutas Site-to-Site
    if [ -n "$NET_IP" ] && [ "$NET_IP" != "null" ]; then
        if [ -z "$NET_MASK" ] || [ "$NET_MASK" == "null" ]; then NET_MASK="255.255.255.0"; fi
        echo "iroute $NET_IP $NET_MASK" >> "$FILE"
        echo "push \"route $NET_IP $NET_MASK\"" >> "$FILE"
        
        # --- AUTOMATIZACIÓN DE SERVER.CONF ---
        if [ -f "$SERVER_CONF" ]; then
            # Si la ruta no existe en el server.conf, la agregamos y reiniciamos
            if ! grep -q "^route $NET_IP $NET_MASK" "$SERVER_CONF"; then
                echo "route $NET_IP $NET_MASK" >> "$SERVER_CONF"
                systemctl restart $OVPN_SERVICE
            fi
        fi
    fi
    
    echo "Exito: IP y rutas asignadas a '$CLIENT'."
}



set_access() {
    if [ -z "$CLIENT" ] || [ -z "$PARAM3" ]; then exit 1; fi
    ACCESS=$PARAM3
    FILE="$CCD_DIR/$CLIENT"
    touch "$FILE"
    
    if [ "$ACCESS" == "deny" ]; then
        if ! grep -q "^disable" "$FILE"; then
            echo "disable" >> "$FILE"
            exec 3<>/dev/tcp/127.0.0.1/7505 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "kill $CLIENT" >&3
                exec 3<&-
            fi
        fi
    elif [ "$ACCESS" == "allow" ]; then
        sed -i '/^disable/d' "$FILE"
    fi
    echo "Exito: Acceso actualizado"
}

get_profile() {
    if [ -z "$CLIENT" ]; then exit 1; fi
    FILE="$OUTPUT_BASE/$CLIENT/$CLIENT.ovpn"
    if [ -f "$FILE" ]; then
        cat "$FILE"
    else
        echo "Error: Archivo no encontrado"
    fi
}

connected_users() {
    STATUS_FILE="/var/log/openvpn-server-status.log"
    if [ -f "$STATUS_FILE" ]; then
        awk -F',' '$1 == "CLIENT_LIST" {print $2}' "$STATUS_FILE" | sort | uniq
    fi
}

connected_details() {
    STATUS_FILE="/var/log/openvpn-server-status.log"
    if [ -f "$STATUS_FILE" ]; then
        awk -F',' '$1 == "CLIENT_LIST" {print $0}' "$STATUS_FILE"
    fi
}

case $ACTION in
    "create") create_user ;;
    "revoke") revoke_user ;;
    "list") list_users ;;
    "ips") show_ips ;;
    "setip") set_static_ip ;;
    "access") set_access ;;
    "profile") get_profile ;;
    "connected") connected_users ;;
    "details") connected_details ;;
    *) 
        echo "Uso: $0 {create|revoke|list|ips|setip|access|profile|connected|details} [parametros...]"
        exit 1 
        ;;
esac
