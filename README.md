# dp-adot-collector

AWS Distro for Opentelemetry is used to collect distributed tracing information of applications and export them to aws xray for observability. This repository includes the opentelemetry config and the nomad plan to deploy the collector onto Nomad through Concourse CI. 


## Configuring the OpenTelemetry collector
A custom opentelemetry config file (config.yml) is used to configure the components for the collector which includes receivers, processors and exporters. A healthcheck extension is added that responds to health check requests and the PProf extension allows fetching the collector's performance profile.

### Processors
This config makes use of the tail sampling processor where sampling is done at the end of a trace. This sampling is done based on two policies: 
1. All spans with status_code=ERROR

2. Probabilistically sampling 10% of all spans


### Exporters
The telemetry data is then exported to AWS Xray for visualisation and analysis. 

## Creating the OpenTelemetry collector in an environment
Following the creating a [new app guide,](https://github.com/ONSdigital/dp/blob/main/guides/NEW_APP.md) this is a concise version of the steps needed to create the collector in an environment. 

### Repositories
As well as this repository, the repositories stated below also need to be cloned in the same local root directory: 

[dp-setup](https://github.com/ONSdigital/dp-setup)

* Includes the terraform, nginx routing as well as the nomad acl

[dp-configs](https://github.com/ONSdigital/dp-configs/tree/main)
* Contains the secrets and manifests file

[dp-ci](https://github.com/ONSdigital/dp-ci/tree/main)
* This repository is needed for any gpg keys and the Concourse CI pipelines


### Installations
* [Ansible](https://github.com/ONSdigital/dp-operations/blob/main/guides/ansible.md#install-ansible)
* [fly cli](https://github.com/ONSdigital/dp-ci/blob/main/pipelines/README.md#bootstrapping-the-pipelines)
* [gnupg@2.2](https://github.com/ONSdigital/dp-operations/blob/76bc43c1ce92f1e89d080e0b6e36101fb3e88221/guides/gpg.md)
* yq
* awscli
* session-manager-plugin
* bash - Mac comes with an older version but a new version of bash is required for things such as encryption/decryption
* colordiff
* Terraform version 0.14.10

# GPG Keys and environmnet keys
Environment keys are needed to decrypt/encrypt files. A senior ONS staff member will provide you with a passphrase file for each of the environment keys. Decrypt and extract this file to get the passphrase. 
The public and private keys for each environment can be found in the [dp-ci repo](https://github.com/ONSdigital/dp-ci/tree/main/gpg-keys)

From the gpg-keys/<environment> directory, run:
`gpg -d privkey.asc > privkey` and enter the passphrase when prompted
Import the keys to your keyring:
```
gpg --import privkey
gpg --list-keys
rm privkey
```

The prod key is in prod directory, not production. 

You would also need the concourse key to run pipelines which is in the ci directory: https://github.com/ONSdigital/dp-ci/tree/main/gpg-keys/ci 

## AWS Setup
* Install [dp-cli](https://github.com/ONSdigital/dp-cli)

* Uncomment all the AWS accounts you have access to on ~/.dp-cli-config.yml


* Once you have been granted access to the AWS accounts (ons-dp-sandbox|staging|prod|ci), add the following to ~/.aws/config file for each environment. 
```
[profile dp-XXXXXXXX] #replace this with correct profile name
sso_start_url = https://ons.awsapps.com/start
sso_region = eu-west-2
sso_account_id = xxxxxxxxx #replace this with correct account id and remove this comment!
sso_role_name = AdministratorAccess
region = eu-west-2
output = json
```
* Export the environment and allow single sign on
```
export AWS_PROFILE=dp-sandbox && export ONS_DP_ENV=sandbox
aws sso login --profile $AWS_PROFILE 
```


## Nomad
1. [Sandbox URL](https://nomad.dp.aws.onsdigital.uk/)
2. [Staging URL](https://nomad.dp-staging.aws.onsdigital.uk/)
3. [Prod URL](https://nomad.dp-prod.aws.onsdigital.uk/)

You would need to decrypt the nomad acl token to gain access to the nomad jobs. In this example, the sandbox environment is used. To decrypt the token, follow these steps:
* install slurp: `cpan install File::Slurp`
* From dp-setup/ansible directory:
```
gpg -d .sandbox.sandbox.asc > .sandbox.pass

yq e .nomad_acl_token inventories/prod/group_vars/all | ansible-vault decrypt --vault-id=sandbox@.sandbox.pass
```

The acl token is shown with % at the end, this is not part of the token. You can then add this token on the UI. 

Run `dp remote allow sandbox` after you have exported the environment as stated in AWS Setup.  
More info: https://github.com/ONSdigital/dp-setup/blob/main/scripts/README.md#decrypt_inline_vault 

### Rolling deploy 

On the Nomad UI, in dp-adot-collector job, click on the definition, edit, find the CPU count and increment it by 1 for web, publishing and management. Plan and Run to complete the rolling deploy. 

## Pipeline
The concourse pipeline is set up in dp-ci and this application uses [docker-deploy.yml](https://github.com/ONSdigital/dp-ci/blob/main/pipelines/pipeline-generator/pipelines/docker-deploy.yml) pipeline to deploy the collector to sandbox, staging and prod (manually triggered). 

Ensure ansible is provisioned for Digital Publishing using [this guide](https://github.com/ONSdigital/dp-setup/blob/awsb/ansible/README.md#prerequisites)
The pipeline will be triggered to deploy to sandbox when merged to develop branch on this repository. Master branch will deploy to staging and prod (manually triggered). 
If any changes related to the collector are added on any other repository, the pipeline would need to be destroyed and recreated using the fly cli tool to pick up the latest changes, it does not update without recreating. 

```
PIPELINE=dp-adot-collector make destroy
PIPELINE=dp-adot-collector make set
```

If there are any changes in the [secrets](https://github.com/ONSdigital/dp-configs/tree/main/secrets), it would need a rolling deploy on nomad even if the pipeline has been destroyed and recreated. 

### Terraform and nginx routing
These are found in dp-setup repository. The routing for opentelemetry is added to the [management](https://github.com/ONSdigital/dp-setup/blob/awsb/ansible/templates/consul-template/management-nginx.http.conf.tpl.j2), [web](https://github.com/ONSdigital/dp-setup/blob/awsb/ansible/templates/consul-template/web-nginx.http.conf.tpl.j2) and [publishing](https://github.com/ONSdigital/dp-setup/blob/awsb/ansible/templates/consul-template/publishing-nginx.http.conf.tpl.j2) routing template. 

This takes this format
```
(( scratch.MapSet "<YOUR_APP_NAME>" "listen" "<YOUR_APP_PORT>" ))
(( scratch.MapSet "<YOUR_APP_NAME>" "upstream" "<YOUR_APP_NAME>" ))
(( template "server" scratch.Get "<YOUR_APP_NAME>" ))
```
where <YOUR_APP_NAME> corresponds to the service name configured in the nomad plan and <YOUR_APP_PORT> is the [magic port](https://github.com/ONSdigital/dp-setup/blob/awsb/PORTS.md) (12850) assigned to the collector.


This is found in dp-setup/terraform. In the app-users directory is the terraform code which creates the adot-collector user and outputs the aws access and secret key for the user. The xray policy is also created through terraform which allows the adot-collector user to write telemetry and trace data to xray and read sampling configuration from xray. 

#### Terraform commands
In dp-steup/terraform/app-users:
* `terraform init -backend-config=$ONS_DP_ENV.backend.tfvars` to initialise
* `terraform plan -var-file=$ONS_DP_ENV.tfvars` - double check the plan to make sure it will do what you expect
* `terraform apply -var-file=$ONS_DP_ENV.tfvars` - to apply the changes on aws. 


To decrypt the aws secret key and access key, run the following in dp-steup/terraform/app-users: 

`app=dp-adot-collector; echo -e "AWS_ACCESS_KEY_ID: $(terraform output -raw $app-id)\nAWS_SECRET_ACCESS_KEY: $(terraform output -raw $app-secret-encrypted | base64 --decode | gpg -qd)"`

You would need to run this command before the above everytime you require the credentials for a different environmnet

`terraform init -backend-config=$ONS_DP_ENV.backend.tfvars -reconfigure`

These credentials are added to the [secrets](https://github.com/ONSdigital/dp-configs/tree/main/secrets) so that the collector is able to use that policy and write to xray. 

### Secrets and manifests
These are in the dp-configs repo. The secrets contain the AWS credentials for the adot-collector user for each environment. Before the secrets are added, you would need to allow the app access to the secrets, check that the vault policy contains the adot-collector - https://github.com/ONSdigital/dp-setup/blob/awsb/ansible/files/vault-policies/dp-adot-collector.hcl and the adot-collector is added to https://github.com/ONSdigital/dp-setup/blob/awsb/ansible/files/vault-policies/dp-deployer.hcl. 

To decrypt and encrypt the [secrets](https://github.com/ONSdigital/dp-configs/blob/main/secrets/sandbox/dp-adot-collector.json.asc)
```
git switch main
git pull
make check-dirty-secrets
```
`make check-dirty-secrets` command is used encrypt and decrypt. Once pushed and merged to main, it will run a secrets concourse pipeline to add those secrets to vault

More info found [here](https://github.com/ONSdigital/dp-configs/tree/main/secrets#to-compare-secrets-files-with-any-local-decrypted-copies-check-dirty-secrets)

#### Manifests
The [adot-collector manifests file](https://github.com/ONSdigital/dp-configs/blob/main/manifests/dp-adot-collector.yml) defines the number of instances in each subnet and the instance configuration. Currently there is 1 instance in each subnet for every environmnet. 

## Important points
* Do not merge using the github UI, use the commandline instead. Instructions can be found next to merge button on the UI

