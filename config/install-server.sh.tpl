#!/bin/bash

set -e
set -o pipefail

# sudo -u ubuntu -i <<'EOAA'

# Docker
echo "install docker"
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Java
echo "install java"
sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt-get update 
sudo apt-get install -y openjdk-8-jdk
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")


echo "install hashicorp repo"
sudo apt update -y && sudo apt install -y gpg
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y
if ! ${NOMAD_ENT}
then 
    sudo apt-get install -y nomad=${NOMAD_VERSION}

else
    sudo apt install -y nomad-enterprise=${NOMAD_VERSION}
fi


sudo cat << EOLIC > /etc/nomad.d/license.hclic
${NOMAD_LICENSE}
EOLIC

sudo cat << EOF > /etc/nomad.d/nomad.hcl
data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
datacenter = "${DC}"

# Enable the server
server {
  enabled          = true
  bootstrap_expect = ${SERVER_NUMBER}

  server_join {
   retry_join = ["${RETRY_JOIN}"]
  }

  license_path = "/etc/nomad.d/license.hclic"
}


acl {
  enabled = ${ACL_ENABLED}
}
EOF

if ${NOMAD_TLS_ENABLED}
then

# install CA and key
sudo cat << EOF > /etc/nomad.d/nomad-agent-ca.pem
${NOMAD_CA_PEM}
EOF

# install server cert and key
sudo cat << EOF > /etc/nomad.d/global-server-nomad.pem
${NOMAD_SERVER_PEM}
EOF

sudo cat << EOF > /etc/nomad.d/global-server-nomad-key.pem
${NOMAD_SERVER_KEY}
EOF


sudo cat << EOF >> /etc/nomad.d/nomad.hcl

# Require TLS
tls {
  http = true
  rpc  = true

  ca_file   = "/etc/nomad.d/nomad-agent-ca.pem"
  cert_file = "/etc/nomad.d/global-server-nomad.pem"
  key_file  = "/etc/nomad.d/global-server-nomad-key.pem"

  verify_server_hostname = true
  verify_https_client    = ${NOMAD_TLS_VERIFY_HTTPS_CLIENT}
}
EOF


export NOMAD_ADDR=https://localhost:4646
echo "export NOMAD_ADDR=https://localhost:4646" >> ~/.bashrc

fi

systemctl daemon-reload
systemctl enable nomad
systemctl start nomad

# init ACL if enabled

if ${ACL_ENABLED}
then
  	echo "init Nomad ACL system"
  

	ACL_DIRECTORY=/tmp/
	TOKENS_BASE_PATH="/home/ubuntu/"
	NOMAD_BOOTSTRAP_TOKEN="$TOKENS_BASE_PATH/nomad_bootstrap"
	NOMAD_USER_TOKEN="$TOKENS_BASE_PATH/nomad_user_token"


sudo cat << EOPOL > $ACL_DIRECTORY/nomad-acl-user.hcl
agent {
	policy = "read"
} 

node { 
	policy = "read" 
} 

namespace "*" { 
	policy = "read" 
	capabilities = ["submit-job", "read-logs", "read-fs"]
}
EOPOL

	# Wait for nomad servers to come up and bootstrap nomad ACL
	for i in {1..12}; do
		# capture stdout and stderr
		set +e
		sleep 5
		OUTPUT=$(nomad acl bootstrap 2>&1)
		if [ $? -ne 0 ]; then
			echo "nomad acl bootstrap: $OUTPUT"
			if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
				echo "nomad no cluster leader"
				continue
			else
				echo "nomad already bootstrapped"
				exit 0
			fi
		fi
		set -e

		echo "$OUTPUT" | grep -i secret | awk -F '=' '{print $2}' | xargs | awk 'NF' > $NOMAD_BOOTSTRAP_TOKEN
		if [ -s $NOMAD_BOOTSTRAP_TOKEN ]; then
			echo "nomad bootstrapped"
			break
		fi
	done

	nomad acl policy apply -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -description "Policy to allow reading of agents and nodes and listing and submitting jobs in all namespaces." node-read-job-submit $ACL_DIRECTORY/nomad-acl-user.hcl

	nomad acl token create -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -name "read-token" -policy node-read-job-submit | grep -i secret | awk -F "=" '{print $2}' | xargs > $NOMAD_USER_TOKEN

	chown ubuntu:ubuntu $NOMAD_BOOTSTRAP_TOKEN $NOMAD_USER_TOKEN

	echo "ACL bootstrap end"
fi
