# API Gateway Ecosystem
## Overview

This script automates the deployment of an API Gateway using **APISIX**, **APISIX Dashboard**, and **etcd**. It also facilitates the management of mTLS certificates and a custom APISIX plugin that integrates with AWS Cognito for JWT authentication and RBAC.

## Prerequisites

Before running the script, ensure you have:
- **Docker** and **Docker Compose** installed.
- **Docker Swarm** must be initialized and actively running.
- All services will be deployed in Docker Swarm as a service with a default configuration of one replica. 
- OpenSSL installed for generating mTLS certificates.
- The required permissions to execute Docker commands.
- A valid certificate and keys for the domain pointing to this server from Let's Encrypt are located at **/etc/letsencrypt/live/{domain_name}**.

## Installation and Setup

### Step 1: Run the Script

1. Clone the repository containing this script and navigate to the directory.
2. Make the script executable:
   ```bash
   chmod +x main.sh
   ```
3. Execute the script:
   ```bash
   sudo ./main.sh
   ```

### Step 2: Fresh Setup or Redeployment

The script prompts whether to initiate a fresh setup or redeploy existing services:

- **Fresh Setup**: 
  - Input the required values:
    - AWS Cognito Pool ID (`aws-cognito-pool-id`)
    - AWS Region ID (`aws-region-id`)
    - Domain Name (e.g., `bharathrajiv.org`)
  - Confirm the values. The script will then generate mTLS certificates and deploy the API Gateway services.

- **Redeployment**:
  - Confirm to redeploy existing services. If previous configurations are found, the script will remove existing services before deploying again.

### Step 3: mTLS Certificates Generation

If a fresh setup is selected, the script generates mTLS certificates for:
- **CA**
- **etcd**
- **APISIX**
- **APISIX Dashboard**

Certificates are saved in the `./mtls-apisix-etcd` directory.

### Step 4: Deployment

The script uses a Docker stack to deploy the following services:
- **etcd**
- **APISIX**
- **APISIX Dashboard**

Deployment progress is shown in the terminal.

### Step 5: Credentials

After successful deployment, the script generates a `apiGateway-credentials.txt` file containing:
- AWS Pool ID
- AWS Region ID
- Domain Name
- APISIX Dashboard URI
- APISIX Admin API URI
- APISIX Admin Secret

## Error Handling

If the script encounters an invalid input or an error during setup, it will print an error message and abort the operation.

## Cleanup

To clean up services manually, use the following Docker commands:
```bash
docker service rm swarm_apisix swarm_apisix-dashboard swarm_etcd
```

## Notes

- Ensure that your domain is correctly configured in your DNS settings.
- Update your `bauth.lua` file with any required configurations for your specific use case.

---
## Visuals
![alt text](image.png)

## API Gateway Sync etcd Database Utility Tool

This script provides a utility for managing and synchronizing etcd database snapshots from a local instance to a remote server using SSH. It ensures your etcd data is properly backed up and restored across environments, allowing for seamless recovery and deployment.

### Features

- Installs required dependencies (`jq`, `yq`).
- Takes a snapshot of the etcd database on the local server.
- Copies the snapshot to a remote server via SSH.
- Takes of the etcd database on the  remote server.
- Restarts the etcd service on the remote server after restoring the snapshot.
- Provides a user-friendly interface with color-coded messages for success, error, and informational messages.

### Prerequisites

Before running the script, ensure that the following dependencies are installed:

- **curl**: For API requests.
- **ssh**: For secure communication with the remote server.
- **jq**: For processing JSON data.
- **yq**: For processing YAML data.
- **docker**: For managing containers on the local and remote server.

To install `jq` and `yq`, use the following commands:

```bash
sudo apt-get install jq -y
sudo snap install yq -y
```

### Usage

1. **Make the script executable:**
   ```bash
   chmod +x sync_db.sh
   ```

2. **Run the script:**
   ```bash
   sudo bash sync_db.sh
   ```

3. **Follow the prompts:**
   - Enter the **remote server IP**.
   - Enter the **path to your SSH PEM key**.


## Adding domain certificates to APISIX
```
curl -i http://127.0.0.1:9180/apisix/admin/ssls/1 \
  -X PUT \
  -H "X-API-KEY: SuperSecureAPIKey-b" \
  -d '{
  "cert": "-----BEGIN CERTIFICATE-----XXXXX-----END CERTIFICATE-----",
  "key": "-----BEGIN PRIVATE KEY-----XXXXX-----END PRIVATE KEY-----",
  "snis": [
    "bharathrajiv.org"
  ]
}'
```
## Adding Routes via API
```
curl -X PUT "http://127.0.0.1:9180/apisix/admin/routes/test" \
-H "X-API-KEY: SuperDuperAPIKey" \
-d '{
  "hosts": ["bharathrajiv.org"],
  "uri": "/test",
  "upstream": {
    "nodes": {
      "app:8000": 1  
    },
    "type": "roundrobin"
  },
  "plugins": {
        "bauth": {
            "region": "us-east-1",
            "pool_id": "us-east-1_XXXXX",
            "header": "Authorization",
            "ssl_verify": false,
            "timeout": 3000,
            "cache_ttl_seconds": 86400,
            "keepalive": true,
            "keepalive_timeout": 60000,
            "groups": ["Generic", "Host"]
        }
  },
  "methods": ["GET", "POST", "PUT", "DELETE"],
  "status": 1,
  "priority": 0
}'
```
## Sample Response from APISIX to Backend
```
Headers: { host: 'bharathrajiv.org',
  'x-real-ip': '172.18.0.1',
  'x-forwarded-for': '172.18.0.1',
  'x-forwarded-proto': 'https',
  'x-forwarded-host': 'bharathrajiv.org',
  'x-forwarded-port': '9443',
  'content-length': '0',
  authorization:
   'Bearer XXXXX',
  'user-agent': 'PostmanRuntime/7.42.0',
  accept: '*/*',
  'postman-token': 'XXXXX',
  'accept-encoding': 'gzip, deflate, br',
  'x-userprofile':
   '{"origin_jti":"XXXXX","token_use":"access","username":"bharathrajiv","cognito:groups":["Admin","Generic"],"iat":XXXXX,"jti":"XXXXX","auth_time":XXXXX,"iss":"https://cognito-idp.us-east-1.amazonaws.com/XXXXX","version":2,"exp":XXXXX,"scope":"aws.cognito.signin.user.admin openid","sub":"XXXXX","client_id":"XXXXX"}',
  'x-username': 'bharathrajiv',
  'x-groups': 'Admin, Generic' }
```
## API Gateway Sync Routes Utility Tool

This tool provides a utility for synchronizing API routes from a local Apache APISIX instance to a remote one via SSH. It ensures that your API configurations are consistent across different environments, allowing for seamless deployments.

## Features

- Fetches routes from a local APISIX instance.
- Checks the status of a remote APISIX instance.
- Applies the fetched routes to the remote instance via SSH.
- User-friendly interface with color-coded messages.

## Prerequisites

Before using this script, ensure you have the following installed:

- **curl**: For making HTTP requests.
- **ssh**: For secure communication with remote servers.
- **jq**: For processing JSON data.
- **yq**: For processing YAML data.

You can install `jq` and `yq` using the following command:

```bash
sudo apt-get install jq -y
sudo snap install yq -y
```
## Usage
1. Make the script executable:
   ```bash
   chmod +x sync_routes.sh
   ```

2. Run the script:
   ```bash
   ./sync_routes.sh
   ```

3. Follow the prompts:
   - Enter the **remote server IP**.
   - Enter the **path to your SSH PEM key**.

The script will fetch routes from the local APISIX instance and apply them to the specified remote instance.

## Authors
``` Bharath Rajiv A ```

## Project status
``` Closed ```
