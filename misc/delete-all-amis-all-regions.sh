for REGION in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do 
  echo "REGION: $REGION"
  for AMI in $(aws ec2 describe-images --region $REGION --owners self --query "Images[].ImageId" --output text); do
    echo "- AMI: $AMI"
    aws ec2 deregister-image --region $REGION --image-id $AMI
  done
done