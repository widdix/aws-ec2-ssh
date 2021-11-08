# Developer notes

## Region Maps

To update the region maps execute the following lines in your terminal:

### RegionMapAmazonLinux

Default user: ec2-user

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=amzn-ami-hvm-2018.03.0.20211015.1-x86_64-gp2" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapAmazonLinux2

Default user: ec2-user

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=amzn2-ami-hvm-2.0.20211005.0-x86_64-gp2" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapUbuntu

Default user: ubuntu

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20210928" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapSUSELinuxEnterpriseServer

Default user: ec2-user

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=suse-sles-12-sp3-v20181004-hvm-ssd-x86_64" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapRHEL

Default user: ec2-user

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=RHEL-7.4_HVM_GA-20170808-x86_64-2-Hourly2-GP2" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapCentOS

Default user: centos

```bash
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=CentOS 7.9.2009 x86_64" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```
