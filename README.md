# Script to upload certificate to FRITZ!Box

This scripts allows to upload a certificate and a private key to a FRITZ!Box via curl. It can be used after a new certificate was obtained via Let's Encrypt for example.

The idea was taken from https://gist.github.com/wikrie/f1d5747a714e0a34d0582981f7cb4cfb

## Usage

You have to provide a baseurl for your FRITZ!Box, a username, a password, and a certpath to contain `fullchain.pem` and `privkey.pem`. This can be done using environment variables or command line options. Command line options have a higher precedence.

| Parameter | Environment         | Command line option |
| --------- | ------------------- | ------------------- |
| baseurl   | `FRITZBOX_BASEURL`  | `-b`                |
| username  | `FRITZBOX_USERNAME` | `-u`                |
| password  | `FRITZBOX_PASSWORD` | `-p`                |
| certpath  | `FRITZBOX_CERTPATH` | `-c`                |

## Examples

Using command line options:

```shell
./fritzbox_upload_certificate.sh -b http://fritz.box -u admin -p secret -c ./certificates/fritz.box
```

Using environment variables:

```shell
export FRITZBOX_BASEURL=http://fritz.box
export FRITZBOX_USERNAME=admin
export FRITZBOX_PASSWORD=secret
export FRITZBOX_CERTPATH=./certificates/fritz.box
./fritzbox_upload_certificate.sh
```

![GitHub](https://img.shields.io/github/license/franzs/fritzbox_upload_certificate)
