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
| debug     | `FRITZBOX_DEBUG`    | `-d`                |

For debugging set the environment variable `FRITZBOX_DEBUG` to any non-empty string or use the command line option `-d`. The HTTP requests and responses will be written to `/tmp/fritzbox.debug` then.

## Limitations

Only RSA keys are [supported by FRITZ!OS](https://en.avm.de/service/knowledge-base/dok/FRITZ-Box-7590/1525_Importing-your-own-certificate-to-the-FRITZ-Box/).

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

## Tested with

| Device                    | FRITZ!OS | works? |
| ------------------------- | -------- | ------ |
| FRITZ!Box 5530 Fiber      | 7.81     | ✓      |
| FRITZ!Box 6490 Cable      | 7.20     | ✓      |
| FRITZ!Box 6660 Cable      | 7.57     | ✓      |
| FRITZ!Box 7360            | 6.86     | ✓      |
| FRITZ!Box 7490            | 7.12     | ✓      |
| FRITZ!Box 7490            | 7.57     | ✓      |
| FRITZ!Box 7530 AX         | 7.57     | ✓      |
| FRITZ!Box 7580            | 7.30     | ✓      |
| FRITZ!Box 7590            | 7.29     | ✓      |
| FRITZ!Repeater 1200 AX    | 7.57     | ✕      |
| FRITZ!WLAN Repeater DVB-C | 7.01     | ✓      |

Let me know what your results are.

![GitHub](https://img.shields.io/github/license/franzs/fritzbox_upload_certificate)
