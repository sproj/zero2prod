#!/bin/bash
cd terraform
terraform init
terraform plan
read -p "Do you want to apply these changes? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  terraform apply
  
  # Get the public IP of the running task
  echo "Waiting for task to start..."
  sleep 30 # Wait for task to start
  eval $(terraform output -raw public_ip_command)
fi