#!/usr/bin/env bash

set -e
readonly DEBUG=${DEBUG:-false}
${DEBUG} && set -x

readonly ME=$(realpath $(which "${0}"))
readonly MYREALDIR=$(dirname "${ME}")

[ ${#} -eq 0 ] && set -- ls

while [ ${#} -gt 0 ]; do
	case ${1} in
		'-v')
			shift # past param
			set -x
		;;
		'ls')
			
		*)
                        shift # past action
		;;
	esac
done
