# NOMAD AWS DEMO

This repo creates a **demo** Nomad cluster (OSS or ENT) on AWS.

**This is not production ready and does not follow the security best practices!  
Use for demo and testing purposes only**

Features:
- native service discovery (no consul)
- AWS Cloud Auto-join
- acl (disabled by default)
- TLS (disabled by default)


Most of the heavy litfing is performed by user_data, that renders two template files: one for the [servers](config/install-server.sh.tpl) and one of the [clients](config/install-client.sh.tpl)
These scripts perform the installation, configuration and initialization of the cluster.


## Configuration
Defaults (see variables.tf for the full list):
- server_count: `3`
- client_count: `3`
- nomad_ent: `true`
- nomad_version: `1.6.1+ent-1`
- retry_join: `"provider=aws tag_key=NomadAutoJoin tag_value=auto-join"`
- nomad_acl_enabled: `false`
- nomad_tls_enabled: `false`

A ".auto.tfvars" file is used to override the required values. (this way terraform loads it automatically)  
To start, copy the `terraform.auto.tfvars.example` file and name it `terraform.auto.tfvars` , then input the values.

### Mandatory variables:

- `key_name`: the name of an existing SSH keypair in AWS
- `nomad_gossip_key`: generate one following [this guide](https://developer.hashicorp.com/nomad/tutorials/transport-security/security-gossip-encryption)
- `nomad_license`: the Nomad Enterprise license (only if using ENT version)

### Optional configuration
#### enable ACL  
to enable and bootstrap the ACL system set  
`nomad_acl_enabled`: `true` 

This enables authentication, therefore you'll need a token to make requests to Nomad.  
Terraform performs the acl boostrap during the initial cluster creation and generates two tokens.  
*These tokens are saved on the server leader at these paths:*  
    - /home/ubuntu/nomad_bootstrap: the bootstap token  
    - /home/ubuntu/nomad_user_token: a token with a limited scope

To get the nomad bootstrap token, run the following on the leader server  
`export NOMAD_TOKEN=$(cat /home/ubuntu/nomad_bootstrap)`


#### enable TLS  
Before being able to use this feature, you need to generate the CA and certificates required by Nomad.  
The `create_tls_certificates.sh` script can do this for you, but you might need to add more [-additional-dnsname](https://developer.hashicorp.com/nomad/docs/commands/tls/cert-create#additional-dnsname) or [-additional-ipaddress](https://developer.hashicorp.com/nomad/docs/commands/tls/cert-create#additional-ipaddress) to match your environment.


If you are using different names or paths for your certificates, change the related variables accordingly.

set `nomad_tls_enabled: true` to enable TLS on the nomad cluster

Follow then this [section of the guide](https://developer.hashicorp.com/nomad/tutorials/transport-security/security-enable-tls#running-with-tls) to configure your CLI (or set nomad_tls_verify_https_client to false)      

## Run!
to provision the cluster run  
`terraform apply`

The `user_data` execution on the remote servers and clients takes a few minutes to complete.  
To check the progress ssh into the instance and `tail -f /var/log/cloud-init-output.log`
