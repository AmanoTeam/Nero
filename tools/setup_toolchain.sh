#!/bin/bash

set -eu

declare -r RAIDEN_HOME='/tmp/raiden-toolchain'

if [ -d "${RAIDEN_HOME}" ]; then
	PATH+=":${RAIDEN_HOME}/bin"
	export RAIDEN_HOME \
		PATH
	return 0
fi

declare -r RAIDEN_CROSS_TAG="$(jq --raw-output '.tag_name' <<< "$(curl --retry 10 --retry-delay 3 --silent --url 'https://api.github.com/repos/AmanoTeam/Raiden/releases/latest')")"
declare -r RAIDEN_CROSS_TARBALL='/tmp/raiden.tar.xz'
declare -r RAIDEN_CROSS_URL="https://github.com/AmanoTeam/Raiden/releases/download/${RAIDEN_CROSS_TAG}/x86_64-unknown-linux-gnu.tar.xz"

curl --connect-timeout '10' --retry '15' --retry-all-errors --fail --silent --location --url "${RAIDEN_CROSS_URL}" --output "${RAIDEN_CROSS_TARBALL}"
tar --directory="$(dirname "${RAIDEN_CROSS_TARBALL}")" --extract --file="${RAIDEN_CROSS_TARBALL}"

rm "${RAIDEN_CROSS_TARBALL}"

mv '/tmp/raiden' "${RAIDEN_HOME}"

PATH+=":${RAIDEN_HOME}/bin"

export RAIDEN_HOME \
	PATH
