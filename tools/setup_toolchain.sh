#!/bin/bash

set -eu

declare -r NERO_HOME='/tmp/nero-toolchain'

if [ -d "${NERO_HOME}" ]; then
	PATH+=":${NERO_HOME}/bin"
	export NERO_HOME \
		PATH
	return 0
fi

declare -r NERO_CROSS_TAG="$(jq --raw-output '.tag_name' <<< "$(curl --retry 10 --retry-delay 3 --silent --url 'https://api.github.com/repos/AmanoTeam/Nero/releases/latest')")"
declare -r NERO_CROSS_TARBALL='/tmp/nero.tar.xz'
declare -r NERO_CROSS_URL="https://github.com/AmanoTeam/Nero/releases/download/${NERO_CROSS_TAG}/x86_64-unknown-linux-gnu.tar.xz"

curl --connect-timeout '10' --retry '15' --retry-all-errors --fail --silent --location --url "${NERO_CROSS_URL}" --output "${NERO_CROSS_TARBALL}"
tar --directory="$(dirname "${NERO_CROSS_TARBALL}")" --extract --file="${NERO_CROSS_TARBALL}"

rm "${NERO_CROSS_TARBALL}"

mv '/tmp/nero' "${NERO_HOME}"

PATH+=":${NERO_HOME}/bin"

export NERO_HOME \
	PATH
