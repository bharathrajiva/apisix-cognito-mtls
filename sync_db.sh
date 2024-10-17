#!/usr/bin/bash
sudo apt-get install jq -y > /dev/null 2>&1
sudo snap install yq -y > /dev/null 2>&1
echo -e "\n\033[1;34m==============================================\033[0m"
echo -e "\033[1;32m   API Gateway Sync etcd Database Utility Tools   \033[0m"
echo -e "\033[1;34m==============================================\033[0m\n"
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


backup_etcd() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SNAPSHOT_NAME="etcd-snapshot-${TIMESTAMP}.db"
    BACKUP_DIR="./backup/etcd"
    ETCD_CONTAINER=$(docker ps -qf "name=etcd")
    [ -z "$ETCD_CONTAINER" ] && { print_error "etcd Docker container not found"; exit 1; }
    print_info "Taking etcd snapshot..."
    docker exec --user root $ETCD_CONTAINER bash -c 'echo "127.0.0.1 etcd" >> /etc/hosts' || { print_error "Failed to update /etc/hosts"; exit 1; }
    docker exec --user root $ETCD_CONTAINER etcdctl --cert /opt/bitnami/etcd/certs/etcd.crt --key /opt/bitnami/etcd/certs/etcd.key --cacert /opt/bitnami/etcd/certs/ca.crt --endpoints=https://etcd:2379 snapshot save /tmp/$SNAPSHOT_NAME || { print_error "Failed to take snapshot"; exit 1; }
    [ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"
    docker cp $ETCD_CONTAINER:/tmp/$SNAPSHOT_NAME $BACKUP_DIR || { print_error "Failed to copy snapshot"; exit 1; } 
    print_success "Snapshot saved as $BACKUP_DIR/$SNAPSHOT_NAME"

    print_info "Copying Backup snapshot to remote server..."
    scp -i "$SSH_PEM" "$BACKUP_DIR/$SNAPSHOT_NAME" "$SSH_USER@$REMOTE_SERVER_IP:/home/ubuntu/docker/api-gateway/backup/etcd/$SNAPSHOT_NAME-remote" || { print_error "Failed to backup to remote server"; exit 1; }
    print_success "Backup to remote server completed."
    print_info "Taking snapshot backup on remote server..."
    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "docker exec --user root \$(docker ps -qf 'name=etcd') bash -c 'echo \"127.0.0.1 etcd\" >> /etc/hosts'" || { print_error "Failed to update /etc/hosts on remote server"; exit 1; }
    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "docker exec --user root \$(docker ps -qf 'name=etcd') etcdctl --cert /opt/bitnami/etcd/certs/etcd.crt --key /opt/bitnami/etcd/certs/etcd.key --cacert /opt/bitnami/etcd/certs/ca.crt --endpoints=https://etcd:2379 snapshot save /tmp/$SNAPSHOT_NAME" || { print_error "Failed to take snapshot on remote server"; exit 1; }
    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "docker cp \$(docker ps -qf 'name=etcd'):/tmp/$SNAPSHOT_NAME /home/ubuntu/docker/api-gateway/backup/etcd" || { print_error "Failed to copy snapshot on remote server"; exit 1; }
    print_info "Restarting etcd Docker service on remote server..."
    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "docker stack rm swarm_etcd > /dev/null 2>&1" || { print_error "Failed to stop etcd on remote server"; exit 1; }
    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "sudo rm -rf /home/ubuntu/docker/api-gateway/etcd-data" || { print_error "Failed to remove etcd member directory on remote server"; exit 1; }
    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "mkdir -p /home/ubuntu/docker/api-gateway/etcd-data" || { print_error "Failed to create etcd member directory on remote server"; exit 1; }
    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "etcdutl snapshot restore  /home/ubuntu/docker/api-gateway/backup/etcd/$SNAPSHOT_NAME-remote --data-dir /home/ubuntu/docker/api-gateway/etcd-data" || { print_error "Failed to restore snapshot on remote server"; exit 1; }
    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "sudo chown -hR 1001:1001 /home/ubuntu/docker/api-gateway/etcd-data" || { print_error "Failed to change ownership of etcd member directory on remote server"; exit 1; }
    ssh -i "$SSH_PEM" "$SSH_USER@$REMOTE_SERVER_IP" "docker stack deploy swarm --compose-file /home/ubuntu/docker/api-gateway/apiGateway.yml > /dev/null 2>&1" || { print_error "Failed to start etcd on remote server"; exit 1; }
    print_success "Snapshot restored and service restarted on remote server."
}
if [ "$confirm" == "yes" ]; then
    backup_etcd
fi