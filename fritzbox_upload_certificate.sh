#!/bin/bash

# Copyright (C) 2020 Franz Schwartau
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# default parameters from environment
baseurl="${FRITZBOX_BASEURL:-}"
certpath="${FRITZBOX_CERTPATH:-}"
password="${FRITZBOX_PASSWORD:-}"
username="${FRITZBOX_USERNAME:-}"
debug="${FRITZBOX_DEBUG:-}"

CURL_CMD="curl"
ICONV_CMD="iconv"
OPENSSL_CMD="openssl"

SUCCESS_MESSAGES="^ *(Das SSL-Zertifikat wurde erfolgreich importiert|Import of the SSL certificate was successful|El certificado SSL se ha importado correctamente|Le certificat SSL a été importé|Il certificato SSL è stato importato( correttamente)?|Import certyfikatu SSL został pomyślnie zakończony)\.$"

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
  if command -v "${cmd}" >/dev/null 2>&1; then
    md5cmd=${cmd}
    break
  fi
done

if [ -z "${md5cmd}" ]; then
  error "Missing command for calculating MD5 hash"
fi

exit_code=0

for cmd in ${CURL_CMD} ${ICONV_CMD} ${OPENSSL_CMD}; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Please install ${cmd}" >&2
    exit_code=1
  fi
done

[ ${exit_code} -ne 0 ] && exit ${exit_code}

while getopts ":b:c:dp:u:h" opt; do
  case ${opt} in
    b)
      baseurl=$OPTARG
      ;;
    c)
      certpath=$OPTARG
      ;;
    d)
      debug="true"
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

shift $((OPTIND - 1))

exit_code=0

for var in baseurl certpath username password; do
  if [ -z "${!var}" ]; then
    echo "Please set ${var}" >&2
    exit_code=1
  fi
done

[ ${exit_code} -ne 0 ] && exit ${exit_code}

# strip trailing slash
baseurl="${baseurl%/}"

fullchain="${certpath}/fullchain.pem"
privkey="${certpath}/privkey.pem"

if [ ! -r "${fullchain}" ] || [ ! -r "${privkey}" ]; then
  error "Certpath ${certpath} must contain fullchain.pem and privkey.pem"
fi

if ! ${OPENSSL_CMD} rsa -in "${privkey}" -check -noout &>/dev/null; then
  error "FRITZ!OS only supports RSA private keys."
fi

if [ -n "${debug}" ]; then
  debug_output="$(mktemp -t fritzbox_debug.XXXXXX)"

  curl_opts="-v -s --stderr -"

  function process_curl_output {
    grep -v '^[*{}]' | sed -e '1i\
' | tee -a "${debug_output}"
  }

  echo "Debug output will be written to ${debug_output}"
else
  curl_opts="-sS"

  function process_curl_output {
    cat
  }
fi

request_file="$(mktemp -t XXXXXX)"
cleanup() {
  rm -f "${request_file}"

  if [ -n "${sid:-}" ] && [ "${sid}" != "0000000000000000" ]; then
    # shellcheck disable=SC2086
    ${CURL_CMD} ${curl_opts} "${baseurl}/login_sid.lua?logout=1&sid=${sid}" | process_curl_output >/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

# login to the box and get a valid SID
# shellcheck disable=SC2086
challenge="$(${CURL_CMD} ${curl_opts} "${baseurl}/login_sid.lua" | process_curl_output | sed -ne 's/^.*<Challenge>\([0-9a-f][0-9a-f]*\)<\/Challenge>.*$/\1/p')"
if [ -z "${challenge}" ]; then
  error "Invalid challenge received."
fi

md5hash="$(echo -n "${challenge}-${password}" | ${ICONV_CMD} -f ASCII -t UTF-16LE | ${md5cmd} | awk '{print $1}')"

# shellcheck disable=SC2086
sid="$(${CURL_CMD} ${curl_opts} "${baseurl}/login_sid.lua?username=${username}&response=${challenge}-${md5hash}" | process_curl_output | sed -ne 's/^.*<SID>\([0-9a-f][0-9a-f]*\)<\/SID>.*$/\1/p')"
if [ -z "${sid}" ] || [ "${sid}" = "0000000000000000" ]; then
  error "Login failed."
fi

certbundle=$(cat "${fullchain}" "${privkey}" | grep -v '^$')

# generate our upload request
boundary="---------------------------$(date +%Y%m%d%H%M%S)"

cat <<EOD >>"${request_file}"
--${boundary}
Content-Disposition: form-data; name="sid"

${sid}
--${boundary}
Content-Disposition: form-data; name="BoxCertImportFile"; filename="BoxCert.pem"
Content-Type: application/octet-stream

${certbundle}
--${boundary}--
EOD

# upload the certificate to the box
# shellcheck disable=SC2086
${CURL_CMD} ${curl_opts} -X POST "${baseurl}/cgi-bin/firmwarecfg" -H "Content-type: multipart/form-data boundary=${boundary}" --data-binary "@${request_file}" | process_curl_output | grep -qE "${SUCCESS_MESSAGES}"
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
  error "Could not import certificate."
fi
