#!/usr/bin/env bash
set -e
set -Euo pipefail

DATA_DIR="./data"
TWEETS_DIR="./tweets"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf ${TEMP_DIR}' EXIT

function ensure_dir {
	if [[ ! -d "${1}" ]]
	then
		mkdir -p "${1}"
	fi
}

function update_plugin_versions {
	local plugin=$1
	local plugin_dir="${DATA_DIR}/${plugin}"
	local tweets_dir="${TWEETS_DIR}/${plugin}"

	echo "Processing plugin ${plugin}"
	if  [[ $# -eq 1 ]]
	then
		asdf plugin-add "${plugin}"
	else
		asdf plugin-add "${plugin}" "${2}"
	fi

	ensure_dir "${plugin_dir}"
	ensure_dir "${tweets_dir}"

	asdf list-all "${plugin}" | sort > "${TEMP_DIR}/${plugin}-new.txt"
	if [[ ! -r "${plugin_dir}/versions.txt" ]]
	then
		touch "${plugin_dir}/versions.txt"
	fi
	comm -13 "${plugin_dir}/versions.txt" "${TEMP_DIR}/${plugin}-new.txt" | sort > "${TEMP_DIR}/${plugin}-added.txt"

	while IFS= read -r version
	do
		echo "${plugin}: Added ${version}"

		# Tweet new plugin versions
		cat<<EOF > "${TWEETS_DIR}/${version}.tweet"
🚀 ${plugin} ${version} is now available in asdf!

💡 Run \`asdf install ${plugin} ${version}\` to install it.
EOF
	done < "${TEMP_DIR}/${plugin}-added.txt"

	diff -u "${plugin_dir}/versions.txt" "${TEMP_DIR}/${plugin}-new.txt" || true
	mv -f "${TEMP_DIR}/${plugin}-new.txt" "${plugin_dir}/versions.txt"
	rm -f "${TEMP_DIR}/${plugin}-added.txt"
}

ensure_dir "${DATA_DIR}"
ensure_dir "${TWEETS_DIR}"

find asdf-plugins/plugins -type f -exec basename "{}" \; | sort > "${TEMP_DIR}/plugins-new.txt"
if [[ ! -r "${DATA_DIR}/plugins.txt" ]]
then
	touch "${DATA_DIR}/plugins.txt"
fi
comm -13 "${DATA_DIR}/plugins.txt" "${TEMP_DIR}/plugins-new.txt" | sort > "${TEMP_DIR}/plugins-added.txt"

while IFS= read -r plugin
do
	echo "Added plugin ${plugin}"

	# Tweet new plugins
	cat<<EOF > "${TWEETS_DIR}/plugin-${plugin}.tweet"
💥 ${plugin} is now supported by asdf!

💡 Run \`asdf plugin-add ${plugin}\` to install it.
EOF
done < "${TEMP_DIR}/plugins-added.txt"

diff -u "${DATA_DIR}/plugins.txt" "${TEMP_DIR}/plugins-new.txt" || true
mv -f "${TEMP_DIR}/plugins-new.txt" "${DATA_DIR}/plugins.txt"
rm -f "${TEMP_DIR}/plugins-added.txt"

for plugin_path in asdf-plugins/plugins/*
do
	plugin=$(basename "${plugin_path}")
	update_plugin_versions "${plugin}"
done

while IFS= read -r plugin_row
do
	plugin=$(cut -f1 <<< "${plugin_row}")
	plugin_url=$(cut -f2 <<< "${plugin_row}")
	update_plugin_versions "${plugin}" "${plugin_url}"
done < "${DATA_DIR}/additional-plugins.tsv"
