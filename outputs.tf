output "lb_address_consul_nomad" {
  value = "http://${aws_instance.server[0].public_ip}:4646"
}



output "IP_Addresses" {
  value = <<CONFIGURATION

Nomad Cluster installed
SSH default user: ubuntu

Server public IPs: ${join(", ", aws_instance.server[*].public_ip)}
Client public IPs: ${join(", ", aws_instance.client[*].public_ip)}

If ACL is enabled:
To get the nomad bootstrap token, run the following on the leader server
export NOMAD_TOKEN=$(cat /home/ubuntu/nomad_bootstrap)

CONFIGURATION
}
