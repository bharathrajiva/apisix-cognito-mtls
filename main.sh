#!/usr/bin/bash

echo -e "\n\033[1;34m=============================\033[0m"
echo -e "\033[1;32m   API Gateway Setup Script   \033[0m"
echo -e "\033[1;34m=============================\033[0m\n"
sudo apt-get install jq -y > /dev/null 2>&1
sudo snap install yq > /dev/null 2>&1
print_success() {
    echo -e "\033[1;32m✔️  $1\033[0m"
}
print_error() {
    echo -e "\033[1;31m✖️  $1\033[0m"
}
print_info() {
    echo -e "\033[1;34mℹ️  $1\033[0m"
}
print_read() {
    echo -ne "\033[1;36m❓  $1\033[0m"
}
print_read "Would you like to initiate a fresh setup for redeployment? Respond 'yes' for fresh setup, 'no' for redeployment. : " 
read setup

if  [ "$setup" == "yes" ]; then
    print_read "Please enter the AWS region ID (e.g., us-east-1): " 
    read aws_region_id
    print_read "Please enter the AWS Cognito Pool ID (e.g., us-east-1-XXXXX): " 
    read aws_cognito_pool_id
    # print_read "Please enter the AWS Cognito Client ID (e.g., your-client-id): " 
    # read aws_client_id
    # print_read "Please enter the AWS Cognito Client Secret (e.g., your-client-secret): " 
    # read aws_client_secret
    print_read "Please enter the domain name (e.g., bharathrajiv.org): " domain_name
    read domain_name
    print_info "Are you sure you want to set the values?"
    print_info "aws-cognito-pool-id: $aws_cognito_pool_id"
    print_info "aws-region-id: $aws_region_id"
    print_info "domain-name: $domain_name"
    print_read "Type "yes" to confirm: "
    read confirm
    if [ "$confirm" == "yes" ]; then
        echo -ne "\033[1;34mℹ️ Setting the values. \033[0m\r"
        sleep 2
        echo -ne "\033[1;34mℹ️ Setting the values.. \033[0m\r"
        sleep 2
        echo -ne "\033[1;34mℹ️ Setting the values... \033[0m\r"
        echo -ne '\n'
        sed -i "s/pool_id = { type = \"string\", default = \"aws-cognito-pool-id\" }/pool_id = { type = \"string\", default = \"$aws_cognito_pool_id\" }/g" ./bauth.lua
        sed -i "s/region = { type = \"string\", default = \"aws-region-id\" }/region = { type = \"string\", default = \"$aws_region_id\" }/g" ./bauth.lua
        print_success "The values were set successfully"
        echo -ne "\033[1;34mℹ️ Generating mTLS certificates. \033[0m\r"
        echo -ne "\033[1;34mℹ️ Generating mTLS certificates.. \033[0m\r"
        sleep 5
        echo -ne "\033[1;34mℹ️ Generating mTLS certificates... \033[0m\r"
        echo -ne '\n'
        mkdir -p ./mtls-apisix-etcd
        ############################################################################################################
        ### ca
        openssl genpkey -algorithm RSA -out ./mtls-apisix-etcd/ca.key -pkeyopt rsa_keygen_bits:2048 > /dev/null 2>&1
        openssl req -x509 -new -key ./mtls-apisix-etcd/ca.key -out ./mtls-apisix-etcd/ca.crt -days 365 -subj "/CN=Private CA" > /dev/null 2>&1
        ### etcd
        openssl genpkey -algorithm RSA -out ./mtls-apisix-etcd/etcd.key -pkeyopt rsa_keygen_bits:2048 > /dev/null 2>&1
        openssl req -new -key ./mtls-apisix-etcd/etcd.key -out ./mtls-apisix-etcd/etcd.csr -subj "/CN=etcd-server" -reqexts san -config <(cat /etc/ssl/openssl.cnf <(printf "[san]\nsubjectAltName=DNS:etcd,DNS:127.0.0.1")) > /dev/null 2>&1
        openssl x509 -req -in ./mtls-apisix-etcd/etcd.csr -CA ./mtls-apisix-etcd/ca.crt -CAkey ./mtls-apisix-etcd/ca.key -CAcreateserial -out ./mtls-apisix-etcd/etcd.crt -days 365 -sha256 -extfile <(printf "subjectAltName=DNS:etcd,DNS:127.0.0.1") > /dev/null 2>&1
        ### apisix
        openssl genpkey -algorithm RSA -out ./mtls-apisix-etcd/apisix.key -pkeyopt rsa_keygen_bits:2048 > /dev/null 2>&1
        openssl req -new -key ./mtls-apisix-etcd/apisix.key -out ./mtls-apisix-etcd/apisix.csr -subj "/CN=apisix" -reqexts san -config <(cat /etc/ssl/openssl.cnf <(printf "[san]\nsubjectAltName=DNS:apisix,DNS:127.0.0.1")) > /dev/null 2>&1
        openssl x509 -req -in ./mtls-apisix-etcd/apisix.csr -CA ./mtls-apisix-etcd/ca.crt -CAkey ./mtls-apisix-etcd/ca.key -CAcreateserial -out ./mtls-apisix-etcd/apisix.crt -days 365 -sha256 -extfile <(printf "subjectAltName=DNS:apisix,DNS:127.0.0.1") > /dev/null 2>&1
        ### apisix-dashboard
        openssl genpkey -algorithm RSA -out ./mtls-apisix-etcd/apisix-dashboard.key -pkeyopt rsa_keygen_bits:2048 > /dev/null 2>&1
        openssl req -new -key ./mtls-apisix-etcd/apisix-dashboard.key -out ./mtls-apisix-etcd/apisix-dashboard.csr -subj "/CN=apisix-dashboard" -reqexts san -config <(cat /etc/ssl/openssl.cnf <(printf "[san]\nsubjectAltName=DNS:apisix-dashboard,DNS:DNS:127.0.0.1")) > /dev/null 2>&1
        openssl x509 -req -in ./mtls-apisix-etcd/apisix-dashboard.csr -CA ./mtls-apisix-etcd/ca.crt -CAkey ./mtls-apisix-etcd/ca.key -CAcreateserial -out ./mtls-apisix-etcd/apisix-dashboard.crt -days 365 -sha256 -extfile <(printf "subjectAltName=DNS:apisix-dashboard,DNS:DNS:127.0.0.1") > /dev/null 2>&1
        ############################################################################################################
        if [ -f /etc/letsencrypt/live/$domain_name/fullchain.pem ] && [ -f /etc/letsencrypt/live/$domain_name/privkey.pem ]; then
            sudo cp /etc/letsencrypt/live/$domain_name/fullchain.pem ./mtls-apisix-etcd/fullchain.pem
            sudo cp /etc/letsencrypt/live/$domain_name/privkey.pem ./mtls-apisix-etcd/privkey.pem
            sudo chmod 644 ./mtls-apisix-etcd/*
            sudo chown -R ubuntu:ubuntu ./mtls-apisix-etcd
            sudo chmod -R a+r ./mtls-apisix-etcd
            print_success "Successfully copied Let's Encrypt certificates."
        else
            print_error "Let's Encrypt certificates not found for domain: $domain_name."
            exit 0
        fi
        print_success "Successfully generated mTLS certificates."
        docker stack deploy swarm --compose-file ./apiGateway.yml > /dev/null 2>&1
        echo -ne '\033[1;34mℹ️ Deploying the API Gateway services. (33%)\033[0m\r'
        sleep 1
        echo -ne '\033[1;34mℹ️ Deploying the API Gateway services.. (66%)\033[0m\r'
        sleep 2
        echo -ne '\033[1;34mℹ️ Deploying the API Gateway services... (100%)\033[0m\r'
        echo -ne '\n'
        print_success "The API Gateway services were deployed successfully."
        APISIX_ADMIN_API="http://127.0.0.1:9180"
        CERT_FILE="./mtls-apisix-etcd/fullchain.pem"
        KEY_FILE="./mtls-apisix-etcd/privkey.pem"
        SNI_LIST=("$domain_name")
        CERT_CONTENT=$(<"$CERT_FILE")
        KEY_CONTENT=$(<"$KEY_FILE")
        admin_key=$(cat ./config.yaml | yq eval -o=json - | jq -r '.deployment.admin.admin_key[0].key')
        apisix_dashboard_key=$(cat ./conf.yaml | yq eval -o=json - | jq -r '.authentication.users[0].password')
        apisix_dashboard_username=$(cat ./conf.yaml | yq eval -o=json - | jq -r '.authentication.users[0].username')
        SNI_JSON=$(printf '%s\n' "${SNI_LIST[@]}" | jq -R . | jq -s .)
        JSON_PAYLOAD=$(jq -n \
        --arg cert "$CERT_CONTENT" \
        --arg key "$KEY_CONTENT" \
        --argjson snis "$SNI_JSON" \
        '{cert: $cert, key: $key, snis: $snis}')
        loading_spinner() {
        local delay=0.1
        local spin=('|' '/' '-' '\')
        while true; do
            for i in "${spin[@]}"; do
                echo -ne "\033[1;34mℹ️ Adding certificate to APISIX SNI: $SNI_LIST $i \033[0m\r" 
                sleep $delay
            done
        done
        }
        loading_spinner &
        spinner_pid=$!
        sleep 10  
        kill $spinner_pid
        wait $spinner_pid 2>/dev/null
        echo -ne "\033[1;34mℹ️ Adding certificate to APISIX SNI: $SNI_LIST Done! \n\033[0m"
        response=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$APISIX_ADMIN_API/apisix/admin/ssls/1" \
        -H "Content-Type: application/json" \
        -H "X-API-KEY: $admin_key"\
        -d "$JSON_PAYLOAD")
        if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
            print_success "Certificate successfully added to APISIX SNI: $SNI_LIST."
        else
            print_error "Failed to add certificate. HTTP status code: $response"
        fi
        print_info "apiGateway services credentials" > ./apiGateway-credentials.txt
        print_info "aws-pool-id: $aws_pool_id" >> ./apiGateway-credentials.txt
        print_info "aws-region-id: $aws_region_id" >> ./apiGateway-credentials.txt
        print_info "domain-name: $domain_name" >> ./apiGateway-credentials.txt
        print_info "APISIX Dashboard: https://$domain_name:7777" >> ./apiGateway-credentials.txt
        print_info "APISIX Admin API: https://$domain_name:9080/apisix/admin" >> ./apiGateway-credentials.txt
        print_info "APISIX Admin API secret: $admin_key (default)" >> ./apiGateway-credentials.txt
        print_info "APISIX Dashboard username: $apisix_dashboard_username" >> ./apiGateway-credentials.txt
        print_info "APISIX Dashboard password: $apisix_dashboard_key" >> ./apiGateway-credentials.txt
    else
        print_error "Aborted."
    fi

elif [ "$setup" == "no" ]; then 
    print_read "Type 'yes' to confirm: " 
    read confirm
    if [ "$confirm" == "yes" ]; then
        if grep -q "aws-region-id" "./bauth.lua"; then
            print_info "The API Gateway services need to be set up from scratch prior to redeployment."
            print_error "Aborted"
            exit 0
        else
            echo -ne '\033[1;34mℹ️ Removing the API Gateway services. \033[0m\r'
            sleep 2
            echo -ne '\033[1;34mℹ️ Removing the API Gateway services.. \033[0m\r'
            sleep 2
            echo -ne '\033[1;34mℹ️ Removing the API Gateway services... \033[0m\r'
            echo -ne '\n'
            docker service rm swarm_apisix swarm_apisix-dashboard swarm_etcd > /dev/null 2>&1
            echo -ne '\033[1;34mℹ️ Removing swarm_apisix (33%)\033[0m\r'
            sleep 1
            echo -ne '\033[1;34mℹ️ Removing swarm_apisix, swarm_apisix-dashboard (66%)\033[0m\r'
            sleep 4
            echo -ne '\033[1;34mℹ️ Removing swarm_apisix, swarm_apisix-dashboard, swarm_etcd (100%)\033[0m\r'
            echo -ne '\n'
            print_success "apiGateway services were removed successfully"
            docker stack deploy swarm --compose-file ./apiGateway.yml > /dev/null 2>&1
            echo -ne '\033[1;34mℹ️ Deploying swarm_etcd  (33%)\033[0m\r'
            sleep 1
            echo -ne '\033[1;34mℹ️ Deploying swarm_etcd , swarm_apisix-dashboard (66%)\033[0m\r'
            sleep 3
            echo -ne '\033[1;34mℹ️ Deploying swarm_etcd , swarm_apisix-dashboard, swarm_apisix (100%)\033[0m\r'
            echo -ne '\n'
            print_success "The API Gateway services were deployed successfully."
        fi
    else
        print_error "Aborted."
    fi
else
    print_error "Invalid input. Please enter 'yes' or 'no'."
    exit 0
fi