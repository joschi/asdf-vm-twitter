#!/usr/bin/env bash
set -e
set -Euo pipefail

DATA_DIR="./data"
TWEETS_DIR="./tweets"
TOOTS_DIR="./toots"
TEMP_DIR=$(mktemp -d)
BIN_DIR=$(dirname "$0")
trap 'rm -rf ${TEMP_DIR}' EXIT

function ensure_dir {
	if [[ ! -d "${1}" ]]
	then
		mkdir -p "${1}"
	fi
}

ensure_dir "${DATA_DIR}"
ensure_dir "${TWEETS_DIR}"
ensure_dir "${TOOTS_DIR}"

# Initialize plugin repository
asdf plugin list all > /dev/null 2>&1
asdf plugin list all | awk '{ print $1 }' | sort > "${TEMP_DIR}/plugins-new.txt"
if [[ ! -r "${DATA_DIR}/plugins.txt" ]]
then
	touch "${DATA_DIR}/plugins.txt"
fi
comm -13 "${DATA_DIR}/plugins.txt" "${TEMP_DIR}/plugins-new.txt" | sort > "${TEMP_DIR}/plugins-added.txt"
comm -23 "${DATA_DIR}/plugins.txt" "${TEMP_DIR}/plugins-new.txt" | sort > "${TEMP_DIR}/plugins-removed.txt"

while IFS= read -r plugin
do
	echo "Added plugin ${plugin}"

	PLUGIN_REPO="$(sed -e 's/repository = //' "${HOME}/.asdf/repository/plugins/${plugin}")"

	# Tweet new plugins
	cat<<EOF > "${TWEETS_DIR}/plugin-${plugin}.tweet"
💥 ${plugin} is now supported by asdf!

💡 Run \`asdf plugin-add ${plugin}\` to install it.
🔗 ${PLUGIN_REPO}
EOF
	# Toot new plugins
	cp "${TWEETS_DIR}/plugin-${plugin}.tweet" "${TOOTS_DIR}/plugin-${plugin}.toot"
done < "${TEMP_DIR}/plugins-added.txt"

diff -u "${DATA_DIR}/plugins.txt" "${TEMP_DIR}/plugins-new.txt" || true
mv -f "${TEMP_DIR}/plugins-new.txt" "${DATA_DIR}/plugins.txt"
rm -f "${TEMP_DIR}/plugins-added.txt"

parallel -a "${DATA_DIR}/plugins.txt" -j 4 "${BIN_DIR}"/update-plugin.bash

while IFS= read -r plugin_row
do
	plugin=$(cut -f1 <<< "${plugin_row}")
	plugin_url=$(cut -f2 <<< "${plugin_row}")
	"${BIN_DIR}"/update-plugin.bash "${plugin}" "${plugin_url}"
done < "${DATA_DIR}/additional-plugins.tsv"
