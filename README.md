# boincme

## What is boincme?

boincme allows you to easily and cheapily run [BOINC][1] on the AWS cloud. BOINC
is an application that allows you to donate CPU time to various scientific 
projects. boincme deploys the infrastructure and provides a VM image to 
automatically deploy and run BOINC on cheap [AWS Spot Instances][2].

## Where is boincme?

boincme is still under development. 

So far we have a [Packer][3] template that builds a BOINC AMI that can configure
itself from [SSM Parameter Store][4].

Soon there will also be CloudFormation templates to create the infrastructure 
and Spot fleet to automatically deploy this AMI.

## Usage

You will need a BOINC account manager like [BAM][5].

1. Build the packer template:
   ```bash
   packer build "packer"
   ```
1. Configure the following SSM Parameter store paramaters.
   |Name|Use|Default|
   |-|-|-|
   |`boinc/manager_username`|Your username on your account manager.|-|
   |`boinc/manager_password`|Your password for your account manager. Make sure you set this as a SecureString in SSM.|-|
   |`boinc/manager_url`|URL of your account manager.|"https://bam.boincstats.com/"|

1. Start an instance from your generated AMI. Ensure it has internet access and 
   has a role attached that allows it to read the SSM parameters you configured 
   earlier. For a quickstart you can use the "AmazonSSMManagedInstanceCore" policy
   provided by AWS.

[1]: https://boinc.berkeley.edu/
[2]: https://aws.amazon.com/ec2/spot/
[3]: https://www.packer.io/
[4]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
[5]: https://www.boincstats.com/bam