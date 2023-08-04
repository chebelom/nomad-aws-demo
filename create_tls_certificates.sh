#!/bin/bash

set -e
set -o pipefail


pushd certificates
# mkdir ca servers clients cli
# generate CA
nomad tls ca create
mv nomad-agent-ca-key.pem nomad-agent-ca.pem ca/
# generate server certificate 
nomad tls cert create -ca ./ca/nomad-agent-ca.pem -key ./ca/nomad-agent-ca-key.pem -additional-dnsname "localhost" -additional-dnsname "127.0.0.1" -server -region global
mv global-server-nomad.pem global-server-nomad-key.pem servers/

nomad tls cert create -ca ./ca/nomad-agent-ca.pem -key ./ca/nomad-agent-ca-key.pem -additional-dnsname "localhost" -additional-dnsname "127.0.0.1" -client
mv global-client-nomad.pem global-client-nomad-key.pem clients

nomad tls cert create -ca ./ca/nomad-agent-ca.pem -key ./ca/nomad-agent-ca-key.pem -additional-dnsname "localhost" -additional-dnsname "127.0.0.1" -cli
mv global-cli-nomad.pem global-cli-nomad-key.pem cli
popd