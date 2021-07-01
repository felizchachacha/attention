#!/usr/bin/env bash

set -e
readonly DEBUG=${DEBUG:-false}
${DEBUG} && set -x

set -o pipefail
shopt -s checkwinsize
# https://unix.stackexchange.com/questions/184009/how-do-i-find-number-of-vertical-lines-available-in-the-terminal
readonly MAXLINES=${LINES}

readonly ME=$(realpath $(which "${0}"))
readonly MYREALDIR=$(dirname "${ME}")
readonly XATTR_DOMAIN='user.attenion'
readonly XATTR_TRACKER="${XATTR_DOMAIN}.devoted"
#readonly BACKEND=xattr # would be nice to have an option of a file-backed storing as well
readonly HELPERUTILSDIR="${MYREALDIR}"/../s/exe # assumed https://gitlab.com/8e/s is there
readonly DEFPATH='.'
readonly JOBS=$(grep -c processor /proc/cpuinfo)

"${HELPERUTILSDIR}"/apt-ensure.bash attr moreutils # xattr?

# get: print solo values
# show: print what is beig showd and values
# list: show descendants

function show_paths() {
	while read path; do
		show_a_path "${path}"
	done
}

function filt() {
        ifne grep -v '/.$\|/..$' | ifne sed 's|/\./|/|g'
}

function list_paths() {
        while read path; do
		if [ -L "${path}" ] || [ -d "${path}" ]; then
			(printf '%q\n' "${path}"/* "${path}"/.* || true) | filt
		fi
        done | show_paths | sort -n
}

function only_lower_value() {
	ifne awk 'BEGIN {prev=-1} // { if ( $1>prev && prev > -1 ) exit ; else print }'
}

function no_1st_column() {
	# https://stackoverflow.com/questions/4198138/printing-everything-except-the-first-field-with-awk
	ifne awk '{$1=""}sub(FS,"")'
}

function list_neglected() {
	#local depth=$1
	#local tempfile="/tmp/${ME}.${USER}.$$.tmp"
	#list_paths | only_lower_value | no_1st_column | list_paths | only_lower_value | no_1st_column | list_paths #  | tee "${depth}.log" | list_neglected $(( depth +1 ))
	list_paths | only_lower_value | no_1st_column | ifne tee >(ifne "${ME}" neglected -)
	#list_paths | only_lower_value | no_1st_column | list_paths | only_lower_value | no_1st_column | list_paths | only_lower_value | no_1st_column | list_paths | only_lower_value | no_1st_column
	#list_paths | only_lower_value | no_1st_column | list_paths | only_lower_value | no_1st_column | list_paths #  | tee "${depth}.log" | list_neglected $(( depth +1 ))
	#rm "${tempfile}"
}

function get_path_devoted() {
	local path="${*:-${DEFPATH}}"
	local value=$(getfattr -R --name "${XATTR_TRACKER}" "${path}" 2>/dev/null | awk -vFS='"' "/^${XATTR_TRACKER}=/ {counter+=\$2} END {print counter}")
	[[ "${value}" == '' ]] && value=0
	echo $value
}

function show_a_path() {
	local path="${*:-${DEFPATH}}"
	local value=$(getfattr -R --name "${XATTR_TRACKER}" "${path}" 2>/dev/null | awk -vFS='"' "/^${XATTR_TRACKER}=/ {counter+=\$2} END {print counter}")
	[[ "${value}" == '' ]] && value=0
	echo -e "${value}\t${path}"
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
			if [[ "$1" == '-' ]]; then
				shift
				#depth=${1:-0}
				#list_neglected "${depth}"
				list_neglected
			else
				#printf '%s\n' "${Paths[@]}" | list_neglected 0
				[ ${#} -eq 0 ] && set -- "${DEFPATH}"
				printf '%s\n' "${@}" | list_neglected | ifne xargs --no-run-if-empty --max-procs=${JOBS} -d "\n" "${ME}" show
			fi
		exit 0
		;;

		'list'|'ls'|'l')
			shift # past param
			[ ${#} -eq 0 ] && set -- "${DEFPATH}"
			printf '%s\n' "${@}" | list_paths
		exit 0
		;;

		'show'|'s')
			shift # past param
			[ ${#} -eq 0 ] && set -- "${DEFPATH}"
			printf '%s\n' "${@}" | show_paths
		exit 0
		;;

		'd'|'devoted'|'add'|'a')
			shift # past param
			#[ ${#} -eq 0 ] && set -- "${DEFPATH}"
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
