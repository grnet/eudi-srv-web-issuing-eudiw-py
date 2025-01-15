#!/bin/bash

usage_string="usage: ./$(basename "$0") [OPTIONS]

Dev utility for managing the ebsi-agent dependency

See also the \"ebsi-agent\" section of the .gitmodules file.

Actions
  info              Show submodule status along with commit diff and statistics
                    against the tracked upstream branch
  log               Inspect downstream commit graph
                    against the tracked upstream branch
  update            Pull latest commit from the tracked upstream branch (specified
                    in the .gitmodules file) into the ./ebsi-agent submodule
  reset <CHECKSUM>  Hard reset of the submodule to the provided commit.
                    Incompatible with the update action
  commit            Commit the current status of the submodule (.e.g., the
                    changes introduced by any of the above options). The commit
                    message will be of the form

                    ebsi-agent upgrade: <checksum>

                    where <checksum> stands for the first six hexadecimal digits of
                    the current latest commit of the submodule. Nothing will
                    happen if the current status of the submodule has already been
                    commited by some previous commit.
Options
  -h, --help        Display help message and exit

Example
  $ ./ebsi-agent.sh info      # Check for upstream changes
  $ ./ebsi-agent.sh update    # Pull changes from upstream
  $ ./ensi-agent.sh commit    # Commit the fact that the downstream has been updated
"

set -e

usage() { echo -n "$usage_string" 1>&2; }

EBSI_AGENT_DIR="$(dirname "${BASH_SOURCE[0]}")/ebsi-agent"

INFO=false
LOG=false
UPDATE=false
CHECKSUM=
COMMIT=false

while [[ $# -gt 0 ]]
do
    arg="$1"
    case $arg in
        info)
            INFO=true
            shift
            ;;
        log)
            LOG=true
            shift
            ;;
        update)
            UPDATE=true
            shift
            ;;
        reset)
            CHECKSUM="$2"
            shift
            shift
            ;;
        commit)
            COMMIT=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[-] Invalid argument: $arg"
            usage
            exit 1
            ;;
    esac
done

get_tracked_branch() {
    echo $(git submodule status | awk -F "/" '{print $NF}') | sed 's/)//g'
}

get_local_branch() {
    echo git branch | sed -n -e 's/^\* \(.*\)/\1/p'
}

get_latest_commit() {
    git submodule status | awk 'NR==1{print $1}'
}


[[ ${UPDATE} == true ]] && [[ ${CHECKSUM} != "" ]] && {
    echo "[-] Either update or reset. You cannot do both."
    exit 1
}

if [[ ${INFO} == true ]]; then

    echo -ne  "\nSubmodule status:\n"
    git submodule status

    tracked=$(get_tracked_branch)
    cd $EBSI_AGENT_DIR

    echo -ne "\nCommit differences against upstream branch:\n"
    branch=$(get_local_branch)
    git log --graph \
        --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' \
        --abbrev-commit \
        --date=relative ${branch}..origin/${tracked}

    echo -ne "\nDiff statistics against upstream branch:\n"
    git fetch origin ${tracked}
    git diff origin/${tracked} --stat

    echo && cd - &>/dev/null
fi

if [[ ${LOG} == true ]]; then
    cd $EBSI_AGENT_DIR
    git log --graph --oneline --pretty='format:%C(auto)%h %s - (%an, %ar)'
    cd -
fi

if [[ ${UPDATE} == true ]]; then

    tracked=$(get_tracked_branch)
    echo "ebsi-agent update: pulling from upstream branch ${tracked} ..."
    git submodule update --remote --recursive &>/dev/null

    [[ $?==0 ]] && {
        pulled_commit=$(get_latest_commit)
        echo "ebsi-agent: ${pulled_commit}"
    }

elif [[ ${CHECKSUM} != "" ]]; then
    cd $EBSI_AGENT_DIR
    git reset $CHECKSUM --hard
    cd -
fi

if [[ ${COMMIT} == true ]]; then
    current_commit=$(get_latest_commit)
    git commit $EBSI_AGENT_DIR -m "ebsi-agent upgrade: ${current_commit:1:7}"
fi

exit 0
