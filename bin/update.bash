#!/usr/bin/env bash
set -e
set -Euo pipefail

DATA_DIR="./data"
TWEETS_DIR="./tweets"
TOOTS_DIR="./toots"
TEMP_DIR=$(mktemp -d)
BLACKLIST="${DATA_DIR}/blacklist.txt"
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
	local toots_dir="${TOOTS_DIR}/${plugin}"

	echo "Processing plugin ${plugin}"
	if  [[ $# -eq 1 ]]
	then
		asdf plugin-add "${plugin}"
	else
		asdf plugin-add "${plugin}" "${2}"
	fi

	ensure_dir "${plugin_dir}"
	ensure_dir "${tweets_dir}"
	ensure_dir "${toots_dir}"

	asdf list-all "${plugin}" | sort | uniq > "${TEMP_DIR}/${plugin}-new.txt"
	if [[ ! -r "${plugin_dir}/versions.txt" ]]
	then
		touch "${plugin_dir}/versions.txt"
	fi
	comm -13 "${plugin_dir}/versions.txt" "${TEMP_DIR}/${plugin}-new.txt" | sort -V | tail -n1 > "${TEMP_DIR}/${plugin}-added.txt"

	while IFS= read -r version
	do
		echo "${plugin}: Added ${version}"

		if grep "^${plugin}$" "${BLACKLIST}"
		then
			echo "${plugin}: Not tweeting about ${plugin} ${version} because it's blacklisted"
		else
			# Sanitize version for use as file name
			version_filename=${version//\//-}

			# Tweet new plugin versions
			cat<<EOF > "${tweets_dir}/${version_filename}.tweet"
🚀 ${plugin} ${version} is now available in asdf!

💡 Run \`asdf install ${plugin} ${version}\` to install it.
EOF
			# Toot new plugin versions
			cp "${tweets_dir}/${version_filename}.tweet" "${toots_dir}/${version_filename}.toot"
		fi
	done < "${TEMP_DIR}/${plugin}-added.txt"

	sort "${TEMP_DIR}/${plugin}-new.txt" "${plugin_dir}/versions.txt" | uniq > "${TEMP_DIR}/${plugin}-merged.txt"
	diff -u "${plugin_dir}/versions.txt" "${TEMP_DIR}/${plugin}-merged.txt" || true
	mv "${TEMP_DIR}/${plugin}-merged.txt" "${plugin_dir}/versions.txt"
	rm -f "${TEMP_DIR}/${plugin}-new.txt" "${TEMP_DIR}/${plugin}-added.txt"
}

ensure_dir "${DATA_DIR}"
ensure_dir "${TWEETS_DIR}"
ensure_dir "${TOOTS_DIR}"

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
	# Toot new plugins
	cp "${TWEETS_DIR}/plugin-${plugin}.tweet" "${TOOTS_DIR}/plugin-${plugin}.toot"
done < "${TEMP_DIR}/plugins-added.txt"

sort "${DATA_DIR}/plugins.txt" "${TEMP_DIR}/plugins-new.txt" | uniq > "${TEMP_DIR}/plugins-merged.txt"
diff -u "${DATA_DIR}/plugins.txt" "${TEMP_DIR}/plugins-merged.txt" || true
mv -f "${TEMP_DIR}/plugins-merged.txt" "${DATA_DIR}/plugins.txt"
rm -f "${TEMP_DIR}/plugins-new.txt" "${TEMP_DIR}/plugins-added.txt"

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
