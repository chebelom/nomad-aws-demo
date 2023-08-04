variable "name" {
  description = "Prefix used to name various infrastructure components. Alphanumeric characters only."
  default     = "nomad-demo-"
}

variable "region" {
  description = "The AWS region to deploy to."
}

variable "ami" {
  description = "Defaults to ubuntu 20.04 LTS on eu-west-1."
  default     = "ami-0f98d0975afb795c7"
}

variable "key_name" {
  description = "The name of the AWS SSH key to be loaded on the instance at provisioning."
}

variable "retry_join" {
  description = "Used by Nomad to automatically form a cluster."
  type        = string
  default     = "provider=aws tag_key=NomadAutoJoin tag_value=auto-join"
}

variable "allowlist_ip" {
  description = "IP to allow access for the security groups (set 0.0.0.0/0 for world)"
  default     = "172.31.32.0/20"
}

variable "server_instance_type" {
  description = "The AWS instance type to use for servers."
  default     = "t3.micro"
}

variable "client_instance_type" {
  description = "The AWS instance type to use for clients."
  default     = "t3.micro"
}

variable "server_count" {
  description = "The number of servers to provision."
  default     = "3"
}

variable "client_count" {
  description = "The number of clients to provision."
  default     = "3"
}

variable "root_block_device_size" {
  description = "The volume size of the root block device."
  default     = 16
}

variable "nomad_version" {
  default = "1.6.1+ent-1" # ENT
  # default = "1.6.1-1"   # OSS
}

variable "nomad_ent" {
  default = "true"
}

variable "nomad_license" {
  default = "123"
}

variable "nomad_acl_enabled" {
  default = false
}

variable "nomad_dc" {
  default = "dc1"
}

# nomad gossip and TLS settings
variable "nomad_gossip_key" {
  description = "https://developer.hashicorp.com/nomad/tutorials/transport-security/security-gossip-encryption"
}

variable "nomad_tls_enabled" {
  description = "enable TLS on nomad cluster"
  default     = false

}
variable "nomad_ca_pem" {
  default = "certificates/ca/nomad-agent-ca.pem"
}

variable "nomad_server_pem" {
  default = "certificates/servers/global-server-nomad.pem"
}

variable "nomad_server_key" {
  default = "certificates/servers/global-server-nomad-key.pem"
}

variable "nomad_client_pem" {
  default = "certificates/clients/global-client-nomad.pem"
}

variable "nomad_client_key" {
  default = "certificates/clients/global-client-nomad-key.pem"
}

variable "nomad_tls_verify_https_client" {
  description = "https://developer.hashicorp.com/nomad/docs/configuration/tls#verify_https_client"
  default     = "true"
}