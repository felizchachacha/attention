#!/usr/bin/env bash

set -e
readonly DEBUG=${DEBUG:-false}
${DEBUG} && set -x

readonly ME=$(realpath $(which "${0}"))
readonly MYREALDIR=$(dirname "${ME}")
readonly XATTR_DOMAIN='user.attenion'
readonly XATTR_TRACKER="${XATTR_DOMAIN}.devoted"
#readonly BACKEND=xattr # would be nice to have an option of a file-backed storing as well
readonly HELPERUTILSDIR="${MYREALDIR}"/../s/exe # assumed https://gitlab.com/8e/s is there
readonly DEFPATH='.'

"${HELPERUTILSDIR}"/apt-ensure.bash attr moreutils # xattr?

function att_list() {
	declare -a Whats=("${@:-${DEFPATH}}")
	list_deeper "${Whats[@]}"
}

function filt() {
        ifne grep -v '/.$\|/..$' | ifne sed 's|/\./|/|g'
}

function list_deeper() {
        #while read f; do
	for path in "${@}"; do
                (printf '%q\n' "${path}"/* "${path}"/.* || true) | filt
        done | while read path; do
		devoted=$(get_path_devoted "${path}")
		echo -e "${devoted}\t${path}"
	done | sort -n
}

function only_lower_value() {
	awk 'BEGIN {prev=-1} // { if ( $1>prev && prev > -1 ) exit ; else print }'
}

function no_1st_column() {
	# https://stackoverflow.com/questions/4198138/printing-everything-except-the-first-field-with-awk
	awk '{$1=""}sub(FS,"")'
}

function get_neglected() {
	declare -a Whats=("${@:-${DEFPATH}}")
	list_deeper "${Whats[@]}" | only_lower_value | no_1st_column
}

function get_path_devoted() {
	local path="${*:-${DEFPATH}}"
	local value=$(getfattr -R --name "${XATTR_TRACKER}" "${path}" 2>/dev/null | awk -vFS='"' "/^${XATTR_TRACKER}=/ {counter+=\$2} END {print counter}")
	[[ "${value}" == '' ]] && value=0
	echo $value
}

function add_path_devoted() {
	if "${HELPERUTILSDIR}"/is_posint.bash $1; then
		local addition=$1
		shift
	else
		addition=1
	fi
	local path="${*:-${DEFPATH}}"
	local old_value=$(get_path_devoted "${path}")
	local new_value=$(( old_value + addition ))
	setfattr --name "${XATTR_TRACKER}" -v "${new_value}" "${path}"
	get_path_devoted "${path}"
}

[ ${#} -eq 0 ] && set -- ls

while [ ${#} -gt 0 ]; do
	case ${1} in

		'-v')
			shift # past param
			set -x
		;;

		'get'|'g')
			shift # past param
			get_path_devoted "${*}"
		exit 0
		;;

		'neglected'|'n'|'next')
			shift # past param
			get_neglected "${@}"
		exit 0
		;;

		'list'|'ls'|'l')
			shift # past param
			att_list "${@}"
		exit 0
		;;

		'd'|'devoted'|'add'|'a')
			shift # past param
			add_path_devoted "${@}"
		exit 0
		;;

		*)
                        shift # past action
			echo 'what?'
		exit 1
		;;

	esac
done
