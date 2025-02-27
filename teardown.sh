#!/bin/bash
cd terraform
terraform init
terraform plan -destroy
read -p "Do you want to destroy these resources? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  terraform destroy
fi