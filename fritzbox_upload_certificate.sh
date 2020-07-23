#!/bin/bash

# default parameters from environment
baseurl="${FRITZBOX_BASEURL:-}"
certpath="${FRITZBOX_CERTPATH:-}"
password="${FRITZBOX_PASSWORD:-}"
username="${FRITZBOX_USERNAME:-}"

function usage {
  echo "Usage: $0 [-b baseurl] [-u username] [-p password] [-c certpath]" >&2
  exit 64
}

md5cmd=

for cmd in md5 md5sum; do
  if which ${cmd} > /dev/null; then
    md5cmd=${cmd}
    break
  fi
done

if [ -z "${md5cmd}" ]; then
  echo "Missing command for calculating MD5 hash" >&2
  exit 1
fi

if ! which curl > /dev/null; then
  echo "Please install curl!" >&2
  exit 1
fi

while getopts ":b:c:p:u:h" opt; do
  case ${opt} in
    b)
      baseurl=$OPTARG
      ;;
    c)
      certpath=$OPTARG
      ;;
    p)
      password=$OPTARG
      ;;
    u)
      username=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: $OPTARG" >&2
      echo >&2
      usage
      ;;
    :)
      echo "Invalid option: $OPTARG requires an argument" >&2
      echo >&2
      usage
      ;;
  esac
done

shift $((OPTIND -1))

exit=0

for var in baseurl certpath username password; do
  if [ -z "${!var}" ]; then
    echo "Please set ${var}" >&2
    exit=1
  fi
done

[ ${exit} -ne 0 ] && exit ${exit}

if [ ! -r "${certpath}/fullchain.pem" -o ! -r "${certpath}/privkey.pem" ]; then
  echo "Certpath ${certpath} must contain fullchain.pem and privkey.pem" >&2
  exit 1
fi

request_file="$(mktemp -t XXXXXX)"
trap "rm -f ${request_file}" EXIT

# login to the box and get a valid SID
challenge="$(curl -sS ${baseurl}/login_sid.lua | sed -e 's/^.*<Challenge>//' -e 's/<\/Challenge>.*$//')"
md5hash="$(echo -n ${challenge}-${password} | iconv -f ASCII -t UTF16LE | ${md5cmd} | awk '{print $1}')"
sid="$(curl -sS "${baseurl}/login_sid.lua?username=${username}&response=${challenge}-${md5hash}" | sed -e 's/^.*<SID>//' -e 's/<\/SID>.*$//')"

if [ "${sid}" = "0000000000000000" ]; then
  echo "Login failed." >&2
  exit 1
fi

# generate our upload request
boundary="---------------------------$(date +%Y%m%d%H%M%S)"

cat <<EOD >> ${request_file}
--${boundary}
Content-Disposition: form-data; name="sid"

${sid}
--${boundary}
Content-Disposition: form-data; name="BoxCertImportFile"; filename="BoxCert.pem"
Content-Type: application/octet-stream

EOD

cat "${certpath}/fullchain.pem" "${certpath}/privkey.pem" | grep -v '^$' >> ${request_file}

cat <<EOD >> ${request_file}

--${boundary}--
EOD

# upload the certificate to the box
curl -sS -X POST ${baseurl}/cgi-bin/firmwarecfg -H "Content-type: multipart/form-data boundary=${boundary}" --data-binary "@${request_file}" | grep SSL
