#!/bin/bash
set -e
DRY_RUN=true

while getopts "y" opt
do
  case "$opt" in
    "y") DRY_RUN=false ;;
  esac
done

! $DRY_RUN || echo "!! This is a dry run. Use -y for wet run. !!"

for REGION in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do 
  echo "REGION: $REGION"
  for AMI in $(aws ec2 describe-images --region $REGION --owners self --filter Name=state,Values=available --query "Images[].ImageId" --output text); do
    echo "- AMI: $AMI"
    $DRY_RUN || (aws ec2 deregister-image --region $REGION --image-id $AMI && echo "  Deleted")
  done
done