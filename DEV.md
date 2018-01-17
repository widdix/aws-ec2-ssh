# Developer notes

## Region Maps

To update the region maps execute the following lines in your terminal:

```
$ regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)
```

### RegionMapAmazonLinux

Default user: ec2-user

```
$ for region in $regions; do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=amzn-ami-hvm-2017.09.1.20180115-x86_64-gp2" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapAmazonLinux2

Default user: ec2-user

```
$ for region in $regions; do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=amzn2-ami-hvm-2017.12.0.20180115-x86_64-gp2" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapUbuntu

Default user: ubuntu

```
$ for region in $regions; do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20180109" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapSUSELinuxEnterpriseServer

Default user: ec2-user

```
$ for region in $regions; do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=suse-sles-12-sp3-v20180104-hvm-ssd-x86_64" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapRHEL

Default user: ec2-user

```
$ for region in $regions; do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=RHEL-7.4_HVM_GA-20170808-x86_64-2-Hourly2-GP2" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```

### RegionMapCentOS

Default user: centos

```
$ for region in $regions; do ami=$(aws --region $region ec2 describe-images --filters "Name=name,Values=CentOS Linux 7 x86_64 HVM EBS 1708_11.01" --query "Images[0].ImageId" --output "text"); printf "'$region':\n  AMI: '$ami'\n"; done
```
