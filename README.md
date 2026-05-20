# OCI Security List Updater

Dynamically updates an OCI Security List ingress rules based on your current public IP. Preserves all existing rules and avoids duplicates.

## What it does

- Fetches your current public IP automatically
- Adds **SSH (TCP 22)** and **DNS (UDP 53)** rules restricted to your IP
- Adds **HTTP (TCP 80)** and **HTTPS (TCP 443)** rules open to all (`0.0.0.0/0`)
- Merges new rules with existing ones — nothing gets deleted
- Deduplicates rules by protocol, source, and port range
- Preserves existing tags and display name

## Prerequisites

- OCI CLI installed and configured
- `jq` installed (`apt install jq` / `dnf install jq`)
- Bash shell

## Setup

Edit the configuration block at the top of `update_security_list.sh`:

```bash
OCI_CLI="/home/youruser/path/to/oci"
OCI_CONFIG="--config-file ~/.oci/config --profile DEFAULT"
SECURITY_LIST_OCID="ocid1.securitylist.oc1.ap-singapore-2.YOUR_OCID_HERE"
REGION="ap-singapore-2"
```

Make it executable:

```bash
chmod +x update_security_list.sh
```

## Usage

```bash
./update_security_list.sh
```

## IAM permissions required

The OCI CLI profile used must have permission to read and update security lists:

```
Allow group <your-group> to manage security-lists in compartment <compartment>
```
