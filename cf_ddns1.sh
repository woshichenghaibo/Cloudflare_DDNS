#!/bin/bash

# Grant execution permission to the script
if [ ! -x "$0" ]; then
    echo "Adding execution permission to the script..."
    chmod +x "$0"
    echo "Execution permission added, continuing to run the script..."
fi

# Check and install jq if not installed
if ! command -v jq &> /dev/null
then
    echo "jq is not installed, installing now..."
    if [ -f /etc/debian_version ]; then
        # If it's a Debian/Ubuntu system
        apt update
        apt install -y jq
    elif [ -f /etc/redhat-release ]; then
        # If it's a CentOS/Red Hat system
        yum install -y jq
    else
        echo "Unable to determine system type, please install jq manually."
        exit 1
    fi
fi

# Configuration file path
CONFIG_FILE="/root/CF-DDNS.txt"

# Read parameters from the configuration file
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Function: Prompt user to input Cloudflare API information
function input_parameters() {
    # Prompt for input only if these parameters are not in the config file
    if [ -z "$CF_API_TOKEN" ]; then
        read -p "Please enter your Cloudflare API token: " CF_API_TOKEN
    fi
    if [ -z "$CF_EMAIL" ]; then
        read -p "Please enter your Cloudflare account email: " CF_EMAIL
    fi
    if [ -z "$DNS_NAME" ]; then
        read -p "Please enter your domain (e.g., example.com): " DNS_NAME
    fi
    if [ -z "$DNS_RECORD" ]; then
        read -p "Please enter the DNS record to update (e.g., www.example.com): " DNS_RECORD
    fi

    # Save the input parameters to the configuration file
    echo "CF_API_TOKEN=$CF_API_TOKEN" > "$CONFIG_FILE"
    echo "CF_EMAIL=$CF_EMAIL" >> "$CONFIG_FILE"
    echo "DNS_NAME=$DNS_NAME" >> "$CONFIG_FILE"
    echo "DNS_RECORD=$DNS_RECORD" >> "$CONFIG_FILE"
}

# Function: Display the current input parameters
function display_parameters() {
    echo "---------------------------------------"
    echo "Current input parameters are as follows:"
    echo "Cloudflare API token: $CF_API_TOKEN"
    echo "Cloudflare account email: $CF_EMAIL"
    echo "Domain: $DNS_NAME"
    echo "DNS record: $DNS_RECORD"
    echo "---------------------------------------"
}

# Function: Modify parameters
function modify_parameters() {
    echo "Please select the parameter to modify:"
    echo "1) Cloudflare API token"
    echo "2) Cloudflare account email"
    echo "3) Domain"
    echo "4) DNS record"
    echo "5) Do not modify, continue running the script"
    read -p "Please enter your choice (1-5): " choice

    case $choice in
        1) read -p "Please enter the new Cloudflare API token: " CF_API_TOKEN ;;
        2) read -p "Please enter the new Cloudflare account email: " CF_EMAIL ;;
        3) read -p "Please enter the new domain (e.g., example.com): " DNS_NAME ;;
        4) read -p "Please enter the new DNS record (e.g., www.example.com): " DNS_RECORD ;;
        5) return ;;
        *) echo "Invalid option, please choose again." ;;
    esac

    # Save the modified parameters to the configuration file
    echo "CF_API_TOKEN=$CF_API_TOKEN" > "$CONFIG_FILE"
    echo "CF_EMAIL=$CF_EMAIL" >> "$CONFIG_FILE"
    echo "DNS_NAME=$DNS_NAME" >> "$CONFIG_FILE"
    echo "DNS_RECORD=$DNS_RECORD" >> "$CONFIG_FILE"

    # Display the modified parameters
    display_parameters
    modify_parameters  # Ask if further modifications are needed
}

# Main program: Determine if running in an interactive terminal
if [ -t 0 ]; then
    # If running interactively, prompt for input or modification of parameters
    input_parameters
    display_parameters

    # Ask if modifications are needed
    read -p "Do you need to modify the parameters? (y/n): " modify_choice
    if [[ $modify_choice == "y" || $modify_choice == "Y" ]]; then
        modify_parameters
    fi
else
    # If running as a cron job, use the parameters from the configuration file
    echo "Script is running in non-interactive mode, using parameters from the configuration file."
fi

# Get Zone ID
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DNS_NAME" \
     -H "X-Auth-Email: $CF_EMAIL" \
     -H "X-Auth-Key: $CF_API_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

# Check if Zone ID was successfully retrieved
if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "null" ]; then
    echo "Failed to retrieve Zone ID, please check the domain or API configuration."
    exit 1
fi

# Get DNS record ID
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$DNS_RECORD" \
     -H "X-Auth-Email: $CF_EMAIL" \
     -H "X-Auth-Key: $CF_API_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

# Check if DNS record ID was successfully retrieved
if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" == "null" ]; then
    echo "Failed to retrieve DNS record ID, please check if the DNS record is correct."
    exit 1
fi

# Get the current external IP
CURRENT_IP=$(curl -s https://ifconfig.co)

# Get the existing IP address in Cloudflare
OLD_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
     -H "X-Auth-Email: $CF_EMAIL" \
     -H "X-Auth-Key: $CF_API_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result.content')

# Debug output: Show IP addresses
echo "Current server's external IP: $CURRENT_IP"
echo "DNS record IP on Cloudflare: $OLD_IP"

# Check if the IP has changed
if [ "$CURRENT_IP" != "$OLD_IP" ]; then
    echo "IP address has changed, updating Cloudflare DNS record..."

    # Update DNS record
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"AAAA\",\"name\":\"$DNS_RECORD\",\"content\":\"$CURRENT_IP\",\"proxied\":true}")

    # Output API response
    echo "API response: $RESPONSE"

    if [[ $RESPONSE == *"\"success\":true"* ]]; then
        echo "DNS record updated successfully, new IP: $CURRENT_IP"
    else
        echo "Failed to update DNS record, please check the response content."
    fi
else
    echo "IP address has not changed, no update needed."
fi
