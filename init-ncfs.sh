#!/bin/bash

# based on https://github.com/barbarbar338/ncfs.git

setup_ngrok () {
    echo "[$(date +"%T") INFO]: Starting NGROK to Cloudflare Forwarding Script..."

    # Starting ngrok
    echo "[$(date +"%T") INFO]: Starting NGROK..."

    # Set NGROK auth token
    echo "[$(date +"%T") INFO]: Setting NGROK auth token..."

    ngrok config add-authtoken "${NGROK_AUTH_TOKEN}" &> /dev/null

    # Run NGROK on background
    echo "[$(date +"%T") INFO]: Starting NGROK on background..."

    ngrok tcp 127.0.0.1:25565 > /dev/null &

    # Wait for NGROK to start
    echo "[$(date +"%T") INFO]: Waiting for NGROK to start..."

    while ! curl -s localhost:4040/api/tunnels | grep -q "tcp://"; do
        sleep 1
    done

    echo "[$(date +"%T") INFO]: NGROK started successfully"

    # Get NGROK URL
    echo "[$(date +"%T") INFO]: Getting NGROK URL..."

    ngrok_url=$(curl -s localhost:4040/api/tunnels | grep -o "tcp://[0-9a-z.-]*:[0-9]*")
    parsed_ngrok_url=${ngrok_url/tcp:\/\//}

    IFS=':' read -ra ADDR <<< "$parsed_ngrok_url"
    ngrok_host=${ADDR[0]}
    ngrok_port=${ADDR[1]}

    if [[ -n "${CF_AUTH_EMAIL}" || -n "${CF_API_KEY}" || -n "${CF_ZONE_ID}" || -n "${CF_CNAME_RECORD}" || -n "${CF_SRV_RECORD}" ]]; then
        setup_cloudflare
        echo "[$(date +"%T") SUC]: Done! Your server is now available at ${CF_SRV_RECORD}"
    else
        echo "[$(date +"%T") SUC]: Done! Your server is now available at $parsed_ngrok_url"
        echo "Please remember, that this URL will change everytime you restart your server"
    fi
}

setup_cloudflare () {
    # Checking cloudflare config
    echo "[$(date +"%T") INFO]: Checking Cloudflare config..."

    # Get CNAME record from Cloudflare
    echo "[$(date +"%T") INFO]: Getting CNAME record from Cloudflare..."

    cname_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=CNAME&name=${CF_CNAME_RECORD}" \
                        -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                        -H "X-Auth-Key: ${CF_API_KEY}" \
                        -H "Content-Type: application/json")

    # Check if record exists
    if [[ $cname_record == *"\"count\":0"* ]]; then
        echo "[$(date +"%T") ERR]: CNAME record does not exist in Cloudflare. You have to create it manually. Create a CNAME record in your Cloudflare dashboard and set the name to ${CF_CNAME_RECORD} (you can put example.com to content for now)"
        exit 1
    fi

    # Get CNAME record id
    cname_record_id=$(echo "$cname_record" | sed -E 's/.*"id":"(\w+)".*/\1/')

    # Get SRV record from Cloudflare
    echo "[$(date +"%T") INFO]: Getting SRV record from Cloudflare..."

    srv_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=SRV&name=_minecraft._tcp.${CF_SRV_RECORD}" \
                        -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                        -H "X-Auth-Key: ${CF_API_KEY}" \
                        -H "Content-Type: application/json")

    # Check if record exists
    if [[ $srv_record == *"\"count\":0"* ]]; then
        echo "[$(date +"%T") ERR]: SRV record does not exist in Cloudflare. You have to create it manually. Create a SRV record in your Cloudflare dashboard and set the name to ${CF_SRV_RECORD} (you can put ${CF_CNAME_RECORD} to content for now)"
        exit 1
    fi

    # Get SRV record id
    srv_record_id=$(echo "$srv_record" | sed -E 's/.*"id":"(\w+)".*/\1/')

    # Update Cloudflare records
    echo "[$(date +"%T") INFO]: Updating Cloudflare records..."

    # Update CNAME record
    echo "[$(date +"%T") INFO]: Updating CNAME record..."

    update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/$cname_record_id" \
                         -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                         -H "X-Auth-Key: ${CF_API_KEY}" \
                         -H "Content-Type: application/json" \
                         --data "{\"type\":\"CNAME\",\"name\":\"${CF_CNAME_RECORD}\",\"content\":\"$ngrok_host\"}")

    # Check if update is successful
    case "$update" in
        *"\"success\":false"*)
            echo "[$(date +"%T") ERR]: CNAME record could not be updated in Cloudflare. $update"
            exit 1
        ;;
        *)
            echo "[$(date +"%T") INFO]: CNAME record updated in Cloudflare. $ngrok_host - ${CF_CNAME_RECORD}"
        ;;
    esac

    # Update SRV record
    echo "[$(date +"%T") INFO]: Updating SRV record..."

    update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/$srv_record_id" \
                         -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                         -H "X-Auth-Key: ${CF_API_KEY}" \
                         -H "Content-Type: application/json" \
                         --data "{\"type\":\"SRV\",\"name\":\"_minecraft._tcp.${CF_SRV_RECORD}\",\"data\": {\"name\":\"${CF_SRV_RECORD}\",\"port\":$ngrok_port,\"proto\":\"_tcp\",\"service\":\"_minecraft\",\"target\":\"${CF_CNAME_RECORD}\"}}")

    # Check if update is successful
    case "$update" in
        *"\"success\":false"*)
            echo "[$(date +"%T") ERR]: SRV record could not be updated in Cloudflare. $update"
            exit 1
        ;;
        *)
            echo "[$(date +"%T") INFO]: SRV record updated in Cloudflare. $ngrok_host - _minecraft._tcp.${CF_SRV_RECORD}"
        ;;
    esac
}

setup_ngrok