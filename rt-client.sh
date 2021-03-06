#!/bin/bash dry-wit
# Copyright 2013-today Automated Computing Machinery S.L.
# Distributed under the terms of the GNU General Public License v3

function usage() {
    cat <<EOF
$SCRIPT_NAME [-v[v]] [-q|--quiet] init remote-url
$SCRIPT_NAME [-v[v]] [-q|--quiet] commit
$SCRIPT_NAME [-v[v]] [-q|--quiet] push
$SCRIPT_NAME [-h|--help]
(c) 2013-today Automated Computing Machinery S.L.
    Distributed under the terms of the GNU General Public License v3
 
Client script for RT.

- Init command: When setting up a new project, it prepares the project
to be able to commit and push changes remotely.
  MAKE SURE YOU RUN IT FROM A LOCAL COPY OF THE TARGET REPOSITORY.
- Commit command: Commits any change to the internal repository.
- Push command: Pushes accumulated changes to the remote repository.
 
Where:
  * remote-url: The remote repository.
EOF
}

# Requirements
function checkRequirements() {
    checkReq git GIT_NOT_INSTALLED;
    checkReq watch WATCH_NOT_INSTALLED;
    checkReq realpath REALPATH_NOT_INSTALLED;
    checkReq bc BC_NOT_INSTALLED;
}

# Environment
function defineEnv() {
    export GIT_BASEDIR_DEFAULT="$HOME/.RT.git.d";
    export GIT_BASEDIR_DESCRIPTION="The git folder";
    if    [ "${GIT_BASEDIR+1}" != "1" ] \
       || [ "x${GIT_BASEDIR}" == "x" ]; then
        export GIT_BASEDIR="${GIT_BASEDIR_DEFAULT}";
    fi

    export GIT_DIR_DEFAULT="${GIT_BASEDIR}/$(basename $PWD)";
    export GIT_DIR_DESCRIPION="Where the actual git repository is located";
    if    [ "${GIT_DIR+1}" != "1" ] \
       || [ "x${GIT_DIR}" == "x" ]; then
        export GIT_DIR="${GIT_DIR_DEFAULT}";
    fi

    export EXTENSIONS_DEFAULT="java stg properties xml jsp xsl xslt txt dsg";
    export EXTENSIONS_DESCRIPTION="The filename extensions to deal with";
    if    [ "${EXTENSIONS+1}" != "1" ] \
       || [ "x${EXTENSIONS}" == "x" ]; then
        export EXTENSIONS="${EXTENSIONS_DEFAULT}";
    fi

    export COMMIT_FREQUENCY_DEFAULT="1";
    export COMMIT_FREQUENCY_DESCRIPTION="The frequency to perform commits, in seconds. The minimum value is 0.1";
    if    [ "${COMMIT_FREQUENCY+1}" != "1" ] \
       || [ "x${COMMIT_FREQUENCY}" == "x" ]; then
        export COMMIT_FREQUENCY="${COMMIT_FREQUENCY_DEFAULT}";
    fi
    
    export REMOTE_REPO_NAME_DEFAULT="origin";
    export REMOTE_REPO_NAME_DESCRIPTION="The name of the remote (typically 'origin')";
    if    [ "${REMOTE_REPO_NAME+1}" != "1" ] \
       || [ "x${REMOTE_REPO_NAME}" == "x" ]; then
        export REMOTE_REPO_NAME="${REMOTE_REPO_NAME_DEFAULT}";
    fi
    
    export REMOTE_BRANCH_DEFAULT="master";
    export REMOTE_BRANCH_DESCRIPTION="The name of the remote branch (typically 'master')";
    if    [ "${REMOTE_BRANCH+1}" != "1" ] \
       || [ "x${REMOTE_BRANCH}" == "x" ]; then
        export REMOTE_BRANCH="${REMOTE_BRANCH_DEFAULT}";
    fi
    
    export GITIGNORE_ENTRIES_DEFAULT="*~ *~* .idea target *.class *.swp *.iml .* *.bak *.rej *.orig *_";
    export GITIGNORE_ENTRIES_DESCRIPTION="The files to ignore";
    if    [ "${GITIGNORE_ENTRIES+1}" != "1" ] \
       || [ "x${GITIGNORE_ENTRIES}" == "x" ]; then
        export GITIGNORE_ENTRIES="${GITIGNORE_ENTRIES_DEFAULT}";
    fi
    
    ENV_VARIABLES=(\
        GIT_BASEDIR \
        GIT_DIR \
        EXTENSIONS \
        COMMIT_FREQUENCY \
        REMOTE_REPO_NAME \
        REMOTE_BRANCH \
        GITIGNORE_ENTRIES \
    );
    
    export ENV_VARIABLES;
}

# Error messages
function defineErrors() {
    export INVALID_OPTION="Unrecognized option";
    export GIT_NOT_INSTALLED="git not installed";
    export WATCH_NOT_INSTALLED="watch not installed";
    export REALPATH_NOT_INSTALLED="realpath not installed";
    export BC_NOT_INSTALLED="bc not installed";
    export COMMAND_IS_MANDATORY="command is mandatory";
    export INVALID_COMMAND="Invalid command";
    export REMOTE_REPOSITORY_IS_MANDATORY="remote repository url is mandatory";
    export CANNOT_SETUP_GIT_REPOSITORY="Cannot setup internal git repository";
    export CANNOT_ADD_FILES="Cannot add existing files to RT repository";
    export CANNOT_COMMIT_CHANGES="Cannot commit changes";
    export CANNOT_WATCH_CHANGES_IN_BACKGROUND="Cannot watch changes in background";
    export CANNOT_PUSH_CHANGES="Cannot push changes";
    export ANOTHER_RT_ALREADY_RUNNING="Another ${SCRIPT_NAME} process is already running";
    export INVALID_COMMIT_FREQUENCY="Invalid commit frequency";

    ERROR_MESSAGES=(\
        INVALID_OPTION \
        GIT_NOT_INSTALLED \
        WATCH_NOT_INSTALLED \
        REALPATH_NOT_INSTALLED \
        BC_NOT_INSTALLED \
        COMMAND_IS_MANDATORY \
        INVALID_COMMAND \
        REMOTE_REPOSITORY_IS_MANDATORY \
        CANNOT_SETUP_GIT_REPOSITORY \
        CANNOT_ADD_FILES \
        CANNOT_COMMIT_CHANGES \
        CANNOT_WATCH_CHANGES_IN_BACKGROUND \
        CANNOT_PUSH_CHANGES \
        ANOTHER_RT_ALREADY_RUNNING \
        INVALID_COMMIT_FREQUENCY \
    );

    export ERROR_MESSAGES;
}

# Checking input
function checkInput() {
    
    local _flags=$(extractFlags $@);
    local _flagCount;
    local _currentCount;
    logInfo -n "Checking input";

    # Flags
    for _flag in ${_flags}; do
        _flagCount=$((_flagCount+1));
        case ${_flag} in
            -h | --help | -v | -vv | -q)
                shift;
                ;;
            *) exitWithErrorCode INVALID_OPTION ${_flag};
               ;;
        esac
    done
    
    # Parameters
    if [ "x${COMMAND}" == "x" ]; then
        COMMAND="$1";
        shift;
    fi

    if [ "x${COMMAND}" == "x" ]; then
        logInfoResult FAILURE "fail";
        exitWithErrorCode COMMAND_IS_MANDATORY;
    fi
    
    if [ "${COMMAND}" == "init" ]; then
        if [ "x${REMOTE_REPOS}" == "x" ]; then
            REMOTE_REPOS="$1";
            shift;
        fi

        if [ "x${REMOTE_REPOS}" == "x" ]; then
            logInfoResult FAILURE "fail";
            exitWithErrorCode REMOTE_REPOSITORY_IS_MANDATORY;
        fi
    fi
    logInfoResult SUCCESS "valid";
}

function main() {

    retrieve_lock_file_path "${COMMAND}";
    local _lockFile="${RESULT}";

    case "${COMMAND}" in
        "init")
            if acquire_lock "${_lockFile}"; then
                git_initialize "${REMOTE_REPOS}" "${PWD}";
                purge_stale_lock "${_lockFile}";
            else
                exitWithErrorCode ANOTHER_RT_ALREADY_RUNNING;
            fi       
            ;;
        "commit")
            if acquire_lock "${_lockFile}"; then
                git_commit_loop;
            else
                exitWithErrorCode ANOTHER_RT_ALREADY_RUNNING;
            fi       
            ;;
        "_ci")
            git_commit "${PWD}";
            ;;
        "push")
            if acquire_lock "${_lockFile}"; then
                git_push;
                purge_stale_lock "${_lockFile}";
            else
                exitWithErrorCode ANOTHER_RT_ALREADY_RUNNING;
            fi       
            ;;
        *) exitWithErrorCode INVALID_COMMAND;
           ;;
    esac
}

function check_not_already_running() {
    local rescode=0;
    local command="${1}";

    local _auxPath="$(realpath ${SCRIPT_NAME})";
    local _lockFile="$(dirname "${_auxPath}")/.${SCRIPT_NAME}-${command}.lock";

    if [ -f "${_lockFile}" ]; then
        local _pid=$(head -n 1 "${_lockFile}" 2> /dev/null);
        if [ -n "$(ps -p ${_pid} | grep ${_pid})" ]; then
            rescode=1;
        fi
    fi

    return ${rescode};
}

function retrieve_lock_file_path() {
    local arg="${1}";

    local _auxPath="$(realpath ${SCRIPT_NAME})";
    local result="$(dirname "${_auxPath}")/.${SCRIPT_NAME}-${arg}.lock";

    export RESULT="${result}";
}

# Acquire specified lock.
# @param the lock file.
# @return 0 if successful, 1 if not

acquire_lock () {
    local me=$(sh -c 'echo $PPID')
    local owner
    local shell
    local status
    local rescode
    local flags=$-
    set -o noclobber #make output redirection into atomic test-and-set

    local file="${1}";
    if [ "x${file}" == "x" ]; then
        retrieve_lock_file_path "${COMMAND}";
        file="${RESULT}";
    fi

    if echo $me $$ valid >"${file}"; then
        result=0
    else
        read owner shell status <"${file}"
        test "$owner $shell $status" = "$me $$ valid"
        result=$?
    fi 2>/dev/null
    set +$- -$flags
    return $result
}

# Remove specified lock if stale (valid, but neither the
# owning process nor the shell that spawned it are still
# running)
# @param the lock file.

purge_stale_lock () {
    local owner
    local shell
    local status
    local file="${1}";
    if [ "x${file}" == "x" ]; then
        retrieve_lock_file_path "${COMMAND}";
        file="${RESULT}";
    fi

    if
        read owner shell status <"${file}" &&
            test "$status" = valid &&
            ! ps p "$shell" &&
            ! ps p "$owner" ; then
        rm -f "${file}"
    fi >/dev/null 2>&1

    rm -f "${file}"
}

function create_lock_file() {
    local command="${1}";
    local _auxPath="$(realpath ${SCRIPT_NAME})";
    local _lockFile="$(dirname "${_auxPath}")/.${SCRIPT_NAME}-${command}.lock";
    echo $$ > "${_lockFile}";
}

function delete_lock_file() {
    local command="${1}";
    local _auxPath="$(realpath ${SCRIPT_NAME})";
    local _lockFile="$(dirname "${_auxPath}")/.${SCRIPT_NAME}-${command}.lock";
    rm -f "${_lockFile}" 2>&1 > /dev/null;
}

function multiply_by_ten_no_decimals() {
    local value="${1}";
    local result="$(echo "scale=1; (${value} * 10)" | bc)";
    result="$(echo "scale=0; $result/1" | bc)";

    export RESULT="${result}";
}

function check_commit_frequency() {
    local rescode=0;
    multiply_by_ten_no_decimals "${COMMIT_FREQUENCY}";
    if [ ${RESULT} -lt 1 ]; then
        rescode=1;
    fi

    return ${rescode};
}

function git_initialize() {
    local _remoteRepos="${1}";
    local _prjFolder="${2}";
    local rescode=0;

    if isDebugEnabled; then
        logDebug -n "Creating ${GIT_DIR} folder";
    else
        logInfo -n "Initializing git";        
    fi
    mkdir -p "${GIT_DIR}" 2>&1 > /dev/null;
    rescode=$?;

    if [ $rescode -eq 0 ]; then

        if isDebugEnabled; then
            logDebugResult SUCCESS "done";
        fi
        git_init "${_remoteRepos}" "${_prjFolder}";
        rescode=$?;

        if [ $rescode -eq 0 ]; then

            if isDebugEnabled; then
                logDebugResult SUCCESS "done";
            fi
            git_add_remote_repos "${_remoteRepos}" "${_prjFolder}";
            rescode=$?;

            if [ $rescode -eq 0 ]; then

                git_pull_remote "${_prjFolder}";
                rescode=$?;
                if [ $rescode -eq 0 ]; then

                    if ! isDebugEnabled; then
                        logInfoResult SUCCESS "done";
                    fi
                else
                    purge_stale_lock
                    if ! isDebugEnabled; then
                        logInfoResult FAILURE "failed";
                    fi
                    exitWithErrorCode CANNOT_SETUP_GIT_REPOSITORY;
                fi
            else
                purge_stale_lock
                if ! isDebugEnabled; then
                    logInfoResult FAILURE "failed";
                fi
                exitWithErrorCode CANNOT_SETUP_GIT_REPOSITORY;
            fi
        else
            purge_stale_lock
            rm -rf "${GIT_DIR}" 2>&1 > /dev/null
            if isDebugEnabled; then
                logDebugResult FAILURE "failed";
            else
                logInfoResult FAILURE "failed";
            fi
            logInfoResult FAILURE "failed";
            exitWithErrorCode CANNOT_SETUP_GIT_REPOSITORY;
        fi
    else
        purge_stale_lock
        if isDebugEnabled; then
            logDebugResult FAILURE "failed";
        else
            logInfoResult FAILURE "failed";
        fi
        exitWithErrorCode CANNOT_SETUP_GIT_REPOSITORY;
    fi

    git_add_files "${_prjFolder}";
}

function git_init() {
    local _remoteRepos="${1}";
    local _prjFolder="${2}";
    
    if isDebugEnabled; then
        logDebug -n "Initializing git repository";
    fi
    pushd "${_prjFolder}" > /dev/null;
    git --git-dir "${GIT_DIR}" --work-tree . init "${_remoteRepos}" 2>&1 > /dev/null
    rescode=$?;

    if [ $rescode -eq 0 ]; then

        if isDebugEnabled; then
            logDebugResult SUCCESS "done";
        fi
    else
        if isDebugEnabled; then
            logDebugResult FAILURE "failed";
        fi
    fi
    popd > /dev/null

    return ${rescode}
        
}

function git_add_remote() {
    local _remoteRepos="${1}";
    local _prjFolder="${2}";
    
    if isDebugEnabled; then
        logDebug -n "Adding remote ${_remoteRepos}";
    fi
    pushd "${_prjFolder}" > /dev/null;
    git --git-dir "${GIT_DIR}" --work-tree . remote add origin "${_remoteRepos}" 2>&1 > /dev/null
    rescode=$?;

    if [ $rescode -eq 0 ]; then

        if isDebugEnabled; then
            logDebugResult SUCCESS "done";
        fi
    else
        logDebugResult FAILURE "failed";
    fi
    popd > /dev/null

    return ${rescode};
}

function git_pull_remote() {
    local _prjFolder="${1}";

    if isDebugEnabled; then
        logDebug -n "Pulling ${REMOTE_REPO_NAME} ${REMOTE_BRANCH}";
    fi

    pushd "${_prjFolder}" > /dev/null;
    git --git-dir "${GIT_DIR}" --work-tree . pull ${REMOTE_REPO_NAME} ${REMOTE_BRANCH} 2>&1 3>&1 > /dev/null
    rescode=$?;

    if [ $rescode -eq 0 ]; then

        if isDebugEnabled; then
            logDebugResult SUCCESS "done";
        fi
    else
        if isDebugEnabled; then
            logDebugResult FAILURE "failed";
        fi
    fi
    popd > /dev/null

    return ${rescode};
}

function git_setup_gitignore() {
    local _prjFolder="${1}";

    if isDebugEnabled; then
        logDebug -n "Setting up the file patterns to ignore";
    fi

    mkdir "${GIT_DIR}"/info;
    for _p in ${GITIGNORE_ENTRIES}; do
        echo "${_p}" >> "${GIT_DIR}"/info/exclude;
        rescode=$?;
        if [ $rescode -ne 0 ]; then
            break;
        fi
    done

    if [ $rescode -eq 0 ]; then
        if isDebugEnabled; then
            logDebugResult SUCCESS "done";
        fi
    else
        if isDebugEnabled; then
            logDebugResult FAILURE "failed";
        fi
    fi

    return ${rescode};
}

function git_add_files() {
    local _prjFolder="${1}";
    local rescode=0;

    pushd "${_prjFolder}" > /dev/null;
    logInfo -n "Adding files";

    echo git --git-dir "${GIT_DIR}" --work-tree . add --ignore-errors . 2>&1 > /dev/null | sh

    popd > /dev/null
    purge_stale_lock
    logInfoResult SUCCESS "done";
}

function git_add_files_with_find() {
    local _prjFolder="${1}";
    local rescode=0;

    pushd "${_prjFolder}" > /dev/null;
    logInfo -n "Adding files";

    find . -type f -exec file {} \; 2>&1 | grep -v target | grep text | grep -v -e '~$' | cut -d':' -f 1 | awk -vG="${GIT_DIR}" '{printf("git --git-dir %s --work-tree . add --ignore-errors %s 2>&1 > /dev/null\n", G, $0);}' > /tmp/"$(basename ${_prjFolder})".log
    find . -type f -exec file {} \; 2>&1 | grep -v target | grep text | grep -v -e '~$' | cut -d':' -f 1 | awk -vG="${GIT_DIR}" '{printf("git --git-dir %s --work-tree . add --ignore-errors %s 2>&1 > /dev/null\n", G, $0);}' | sh 2>&1 > /dev/null

    popd > /dev/null
    purge_stale_lock
    logInfoResult SUCCESS "done";
}

function git_add_files_based_on_extensions() {
    local _prjFolder="${1}";
    local rescode=0;

    pushd "${_prjFolder}" > /dev/null;
    logInfo -n "Adding files";

#  find . -type f -exec file {} \; 2>&1 | grep -v target | grep text | grep -v -e '~$' | cut -d':' -f 1 | awk -vG="${GIT_DIR}" '{printf("git --git-dir %s --work-tree . add --ignore-errors %s 2>&1 > /dev/null\n", G, $0);}' | sh 2>&1 > /dev/null
    for ext in ${EXTENSIONS}; do
        local _add="'*.${ext}'";
        echo git --git-dir "${GIT_DIR}" --work-tree . add --ignore-errors ${_add} 2>&1 > /dev/null | sh
        rescode=$?;
        if [ $rescode -ne 0 ]; then
            popd > /dev/null
            purge_stale_lock
            logInfoResult FAILURE "failed";
            exitWithErrorCode CANNOT_ADD_FILES;
        fi
    done
    logInfoResult SUCCESS "done";
    popd > /dev/null
}

function git_commit() {
    local _prjFolder="${1}";
    local rescode=0;

    git_add_files "${_prjFolder}";

    logInfo -n "Commiting changes";

    pushd "${_prjFolder}" > /dev/null;
    git --git-dir "${GIT_DIR}" --work-tree . status | tail -n 1 | grep "nothing" | grep "commit" 2>&1 > /dev/null
    rescode=$?;
    if [ $rescode -eq 0 ]; then
        logInfoResult SUCCESS "done";
        popd > /dev/null
    else
        git --git-dir "${GIT_DIR}" --work-tree . commit -a -m"$(date '+%Y%m%d%H%M')" 2>&1 > /dev/null
        rescode=$?;
        popd > /dev/null
        if [ $rescode -eq 0 ]; then
            logInfoResult SUCCESS "done";
        else
            logInfoResult FAILURE "failed";
            exitWithErrorCode CANNOT_COMMIT_CHANGES;
        fi
    fi
}

function git_commit_loop() {
    local _auxPath=$(realpath ${SCRIPT_NAME});
    local _auxFolder=$(dirname ${_auxPath});

    if check_commit_frequency; then
        logInfo -n "Watching changes in background";
        watch -n"${COMMIT_FREQUENCY}" "bash -c \"export PATH=\$PATH:~/github/RT; cd ${_auxFolder}; ${SCRIPT_NAME} _ci\"" > /dev/null &
        if [ $? -eq 0 ]; then
            logInfoResult SUCCESS "done";
        else
            purge_stale_lock
            logInfoResult FAILURE "failed";
            exitWithErrorCode CANNOT_WATCH_CHANGES_IN_BACKGROUND;
        fi
    else
        purge_stale_lock
        exitWithErrorCode INVALID_COMMIT_FREQUENCY;
    fi
}

function git_push() {
    local rescode=0;

    logInfo -n "Pushing changes";

    git --git-dir "${GIT_DIR}" --work-tree . push origin master  > /dev/null 2>&1
    rescode=$?;
    purge_stale_lock
    if [ $rescode -eq 0 ]; then
        logInfoResult SUCCESS "done";
    else
        logInfoResult FAILURE "failed";
        exitWithErrorCode CANNOT_PUSH_CHANGES;
    fi  
}
