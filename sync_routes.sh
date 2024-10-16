#!/usr/bin/bash
sudo apt-get install jq -y > /dev/null 2>&1
sudo snap install yq -y > /dev/null 2>&1
echo -e "\n\033[1;34m=========================================\033[0m"
echo -e "\033[1;32m   API Gateway Sync Routes Utility Tools   \033[0m"
echo -e "\033[1;34m=========================================\033[0m\n"
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
check_dependencies() {
    for cmd in curl ssh jq; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd is not installed. Please install it."
            exit 1
        fi
    done
}

LOCAL_APISIX_ADMIN_URL="http://127.0.0.1:9180/apisix/admin"
REMOTE_APISIX_ADMIN_URL="http://127.0.0.1:9180/apisix/admin"
LOCAL_APISIX_TOKEN=$(cat ./config.yaml | yq eval -o=json - | jq -r '.deployment.admin.admin_key[0].key')
REMOTE_APISIX_TOKEN=$(cat ./config.yaml | yq eval -o=json - | jq -r '.deployment.admin.admin_key[0].key')

print_read "Enter the remote server IP: " 
read REMOTE_SERVER_IP
print_read "Enter the path to your SSH PEM key: "
read SSH_PEM
print_info "Are you sure you want to set the values?"
print_info "REMOTE_SERVER_IP: $REMOTE_SERVER_IP"
print_info "SSH_PEM: $SSH_PEM"
print_read "Type 'yes' to confirm: " 
read confirm

SSH_USER="ubuntu"

check_dependencies

get_local_routes() {
    print_info "Fetching routes from local APISIX..."
    routes=$(curl -s -H "X-API-KEY: $LOCAL_APISIX_TOKEN" "$LOCAL_APISIX_ADMIN_URL/routes")

    if [[ -z "$routes" || "$routes" == *"error_msg"* ]]; then
        print_error "Error: Failed to fetch routes from local APISIX."
        exit 1
    fi

    print_success "Routes fetched successfully."
    print_info "$routes"
}

check_remote_apisix() {
    print_info "Checking if APISIX is running on the remote server..."

    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "curl -s -o /dev/null -w '%{http_code}' -H 'X-API-KEY: $REMOTE_APISIX_TOKEN' $REMOTE_APISIX_ADMIN_URL/routes" > /tmp/remote_status_code

    local status_code=$(cat /tmp/remote_status_code)

    if [[ "$status_code" -ne 200 ]]; then
        print_error "Error: APISIX is not running or Admin API is not accessible on the remote server."
        exit 1
    fi

    print_success "APISIX is running and Admin API is accessible on the remote server."
}

apply_routes_to_remote() {
    local routes_json="$1"
    print_info "Applying routes to remote APISIX..."
    local route_ids=$(echo "$routes_json" | jq -r '.list[].value.id')
    for id in $route_ids; do
        local specific_route=$(echo "$routes_json" | jq -c --arg id "$id" '
            .list[] | select(.value.id == $id) | 
            { 
                id: .value.id, 
                uri: .value.uri, 
                methods: .value.methods, 
                upstream: .value.upstream,
                plugins: .value.plugins
                # Adjust fields as necessary
            }'
        )
        ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" \
        "curl -s -X PUT -H 'X-API-KEY: $REMOTE_APISIX_TOKEN' -H 'Content-Type: application/json' \
        -d '$specific_route' $REMOTE_APISIX_ADMIN_URL/routes/$id" > /dev/null
    done
    loading_spinner() {
    local delay=0.1
    local spin=('|' '/' '-' '\')
    while true; do
        for i in "${spin[@]}"; do
            echo -ne "\033[1;34mℹ️  Adding routes to APISIX for server: $REMOTE_SERVER_IP $i \033[0m\r"
            sleep $delay
        done
    done
    }
    loading_spinner &
    spinner_pid=$!
    sleep 10  
    kill $spinner_pid
    wait $spinner_pid 2>/dev/null
    echo -ne "\033[1;34mℹ️  Adding routes to APISIX for server: $REMOTE_SERVER_IP Done! \n\033[0m"
    print_success "Routes applied successfully to the remote server $REMOTE_SERVER_IP."
}




if [ "$confirm" == "yes" ]; then
    get_local_routes
    check_remote_apisix
    apply_routes_to_remote "$routes"
else
    print_error "Aborted."
fi

rm /tmp/remote_status_code
print_success "All tasks completed successfully!"
