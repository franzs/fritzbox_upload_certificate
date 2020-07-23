#!/bin/bash

# default parameters from environment
baseurl="${FRITZBOX_BASEURL:-}"
certpath="${FRITZBOX_CERTPATH:-}"
password="${FRITZBOX_PASSWORD:-}"
username="${FRITZBOX_USERNAME:-}"

CURL_CMD=curl
ICONV_CMD=iconv

function usage {
  echo "Usage: $0 [-b baseurl] [-u username] [-p password] [-c certpath]" >&2
  exit 64
}

function error {
  local msg=$1

  [ "${msg}" ] && echo "${msg}" >&2
  exit 1
}

md5cmd=

for cmd in md5 md5sum; do
  if which ${cmd} > /dev/null; then
    md5cmd=${cmd}
    break
  fi
done

if [ -z "${md5cmd}" ]; then
  error "Missing command for calculating MD5 hash"
fi

exit=0

for cmd in ${CURL_CMD} ${ICONV_CMD}; do
  if ! which ${cmd} > /dev/null; then
    echo "Please install ${cmd}" >&2
    exit=1
  fi
done

[ ${exit} -ne 0 ] && exit ${exit}

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
  error "Certpath ${certpath} must contain fullchain.pem and privkey.pem"
fi

request_file="$(mktemp -t XXXXXX)"
trap "rm -f ${request_file}" EXIT

# login to the box and get a valid SID
challenge="$(${CURL_CMD} -sS ${baseurl}/login_sid.lua | sed -ne 's/^.*<Challenge>\([0-9a-f][0-9a-f]*\)<\/Challenge>.*$/\1/p')"
if [ -z "${challenge}" ]; then
  error "Invalid challenge received."
fi

md5hash="$(echo -n ${challenge}-${password} | ${ICONV_CMD} -f ASCII -t UTF16LE | ${md5cmd} | awk '{print $1}')"

sid="$(${CURL_CMD} -sS "${baseurl}/login_sid.lua?username=${username}&response=${challenge}-${md5hash}" | sed -ne 's/^.*<SID>\([0-9a-f][0-9a-f]*\)<\/SID>.*$/\1/p')"
if [ -z "${sid}" -o "${sid}" = "0000000000000000" ]; then
  error "Login failed."
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
${CURL_CMD} -sS -X POST ${baseurl}/cgi-bin/firmwarecfg -H "Content-type: multipart/form-data boundary=${boundary}" --data-binary "@${request_file}" | grep SSL
