# Copyright 2019 Roman Perepelitsa.
#
# This file is part of GitStatus. It provides Bash bindings.
#
# GitStatus is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GitStatus is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GitStatus. If not, see <https://www.gnu.org/licenses/>.

[[ $- == *i* ]] || return  # non-interactive shell

# Starts gitstatusd in the background. Does nothing and succeeds if gitstatusd
# is already running.
#
# Usage: gitstatus_start [OPTION]...
#
#   -t FLOAT  Fail the self-check on initialization if not getting a response from
#             gitstatusd for this this many seconds. Defaults to 5.
#
#   -s INT    Report at most this many staged changes; negative value means infinity.
#             Defaults to 1.
#
#   -u INT    Report at most this many unstaged changes; negative value means infinity.
#             Defaults to 1.
#
#   -c INT    Report at most this many conflicted changes; negative value means infinity.
#             Defaults to 1.
#
#   -d INT    Report at most this many untracked files; negative value means infinity.
#             Defaults to 1.
#
#   -m INT    Report -1 unstaged and untracked if there are more than this many files
#             in the index. Negative value means infinity. Defaults to -1.
#
#   -e        Count files within untracked directories like `git status --untracked-files`.
function gitstatus_start() {
  unset OPTIND
  local opt timeout=5 max_dirty=-1 recurse_untracked_dirs
  local max_num_staged=1 max_num_unstaged=1 max_num_conflicted=1 max_num_untracked=1
  while getopts "t:s:u:c:d:m:e" opt; do
    case "$opt" in
      t) timeout=$OPTARG;;
      s) max_num_staged=$OPTARG;;
      u) max_num_unstaged=$OPTARG;;
      c) max_num_conflicted=$OPTARG;;
      d) max_num_untracked=$OPTARG;;
      m) max_dirty=$OPTARG;;
      e) recurse_untracked_dirs='--recurse-untracked-dirs';;
      *) return 1;;
    esac
  done

  (( OPTIND == $# + 1 )) || { echo "usage: gitstatus_start [OPTION]..." >&2; return 1; }

  [[ -z "${GITSTATUS_DAEMON_PID:-}" ]] || return 0  # already started

  local req_fifo resp_fifo

  function gitstatus_start_impl() {
    local log_level="${GITSTATUS_LOG_LEVEL:-}"
    [[ -n "$log_level" || "${GITSTATUS_ENABLE_LOGGING:-0}" != 1 ]] || log_level=INFO

    local daemon="${GITSTATUS_DAEMON:-}"
    if [[ -z "$daemon" ]]; then
      local os   &&   os=$(uname -s)                    || return
      local arch && arch=$(uname -m)                    || return
      local dir  &&  dir=$(dirname "${BASH_SOURCE[0]}") || return
      [[ "$os" != Linux || "$(uname -o)" != Android ]]  || os=Android
      daemon="$dir/bin/gitstatusd-${os,,}-${arch,,}"
    fi

    local threads="${GITSTATUS_NUM_THREADS:-0}"
    if (( threads <= 0 )); then
      case "$(uname -s)" in
        FreeBSD) threads=$(sysctl -n hw.ncpu)         || return;;
        *)       threads=$(getconf _NPROCESSORS_ONLN) || return;;
      esac
      (( threads *=  2 ))
      (( threads >=  2 )) || threads=2
      (( threads <= 32 )) || threads=32
    fi

    req_fifo=$(mktemp -u "${TMPDIR:-/tmp}"/gitstatus.$$.pipe.req.XXXXXXXXXX)   || return
    resp_fifo=$(mktemp -u "${TMPDIR:-/tmp}"/gitstatus.$$.pipe.resp.XXXXXXXXXX) || return
    mkfifo "$req_fifo" "$resp_fifo"                                            || return
    exec {_GITSTATUS_REQ_FD}<>"$req_fifo" {_GITSTATUS_RESP_FD}<>"$resp_fifo"   || return
    command rm "$req_fifo" "$resp_fifo"                                        || return

    local d="${GITSTATUS_DAEMON:-}"
    local daemon_args=(
      --parent-pid="$$"
      --num-threads="$threads"
      --max-num-staged="$max_num_staged"
      --max-num-unstaged="$max_num_unstaged"
      --max-num-conflicted="$max_num_conflicted"
      --max-num-untracked="$max_num_untracked"
      --dirty-max-index-size="$max_dirty"
      $recurse_untracked_dirs)

    if [[ -n "$log_level" ]]; then
      GITSTATUS_DAEMON_LOG=$(mktemp "${TMPDIR:-/tmp}"/gitstatus.$$.log.XXXXXXXXXX) || return
      [[ "$log_level" == INFO ]] || daemon_args+=(--log-level="$log_level")
    else
      GITSTATUS_DAEMON_LOG=/dev/null
    fi

    local IFS=
    [[ "${daemon_args[*]}" =~ ^[a-z0-9=-]*$ ]] || return
    IFS=' '

    { <&$_GITSTATUS_REQ_FD >&$_GITSTATUS_RESP_FD 2>"$GITSTATUS_DAEMON_LOG" \
        _gitstatus_daemon="$daemon" bash -cx "
          trap 'kill %1 &>/dev/null' SIGINT SIGTERM EXIT
          \"\$_gitstatus_daemon\" ${daemon_args[*]} 0<&0 1>&1 2>&2 &
          wait %1
          if [[ \$? != 0 && \$? != 10 && \$? -le 128 && -f \"\$_gitstatus_daemon\"-static ]]; then
            \"\$_gitstatus_daemon\"-static ${daemon_args[*]} 0<&0 1>&1 2>&2 &
            wait %1
          fi
          echo -nE $'bye\x1f0\x1e'" & } 2>/dev/null
    disown
    GITSTATUS_DAEMON_PID=$!

    local reply
    echo -nE $'hello\x1f\x1e' >&$_GITSTATUS_REQ_FD                     || return
    IFS='' read -rd $'\x1e' -u $_GITSTATUS_RESP_FD -t "$timeout" reply || return
    [[ "$reply" == $'hello\x1f0' ]]                                    || return

    _GITSTATUS_DIRTY_MAX_INDEX_SIZE=$max_dirty
  }

  if ! gitstatus_start_impl; then
    echo "gitstatus_start: failed to start gitstatusd" >&2
    [[ -z "${req_fifo:-}"  ]] || command rm -f "$req_fifo"
    [[ -z "${resp_fifo:-}" ]] || command rm -f "$resp_fifo"
    unset -f gitstatus_start_impl
    gitstatus_stop
    return 1
  fi

  unset -f gitstatus_start_impl

  if [[ "${GITSTATUS_STOP_ON_EXEC:-1}" == 1 ]]; then
    type -t _gitstatus_exec &>/dev/null    || function _gitstatus_exec()    { exec    "$@"; }
    type -t _gitstatus_builtin &>/dev/null || function _gitstatus_builtin() { builtin "$@"; }

    function _gitstatus_exec_wrapper() {
      (( ! $# )) || gitstatus_stop
      local ret=0
      _gitstatus_exec "$@" || ret=$?
      [[ -n "${GITSTATUS_DAEMON_PID:-}" ]] || gitstatus_start || true
      return $ret
    }

    function _gitstatus_builtin_wrapper() {
      while [[ "${1:-}" == builtin ]]; do shift; done
      if [[ "${1:-}" == exec ]]; then
        _gitstatus_exec_wrapper "${@:2}"
      else
        _gitstatus_builtin "$@"
      fi
    }

    alias exec=_gitstatus_exec_wrapper
    alias builtin=_gitstatus_builtin_wrapper

    _GITSTATUS_EXEC_HOOK=1
  else
    unset _GITSTATUS_EXEC_HOOK
  fi
}

# Stops gitstatusd if it's running.
function gitstatus_stop() {
  [[ -z "${_GITSTATUS_REQ_FD:-}"    ]] || exec {_GITSTATUS_REQ_FD}>&-              || true
  [[ -z "${_GITSTATUS_RESP_FD:-}"   ]] || exec {_GITSTATUS_RESP_FD}>&-             || true
  [[ -z "${GITSTATUS_DAEMON_PID:-}" ]] || kill "$GITSTATUS_DAEMON_PID" &>/dev/null || true
  if [[ -n "${_GITSTATUS_EXEC_HOOK:-}" ]]; then
    unalias exec builtin &>/dev/null || true
    function _gitstatus_exec_wrapper()    { _gitstatus_exec    "$@"; }
    function _gitstatus_builtin_wrapper() { _gitstatus_builtin "$@"; }
  fi
  unset _GITSTATUS_REQ_FD _GITSTATUS_RESP_FD GITSTATUS_DAEMON_PID _GITSTATUS_EXEC_HOOK
  unset _GITSTATUS_DIRTY_MAX_INDEX_SIZE
}

# Retrives status of a git repository from a directory under its working tree.
#
# Usage: gitstatus_query [OPTION]...
#
#   -d STR    Directory to query. Defaults to ${GIT_DIR:-$PWD}.
#   -t FLOAT  Timeout in seconds. Will block for at most this long. If no results
#             are available by then, will return error.
#
# On success sets VCS_STATUS_RESULT to one of the following values:
#
#   norepo-sync  The directory doesn't belong to a git repository.
#   ok-sync      The directory belongs to a git repository.
#
# If VCS_STATUS_RESULT is ok-sync, additional variables are set:
#
#   VCS_STATUS_WORKDIR              Git repo working directory. Not empty.
#   VCS_STATUS_COMMIT               Commit hash that HEAD is pointing to. Either 40 hex digits or
#                                   empty if there is no HEAD (empty repo).
#   VCS_STATUS_LOCAL_BRANCH         Local branch name or empty if not on a branch.
#   VCS_STATUS_REMOTE_NAME          The remote name, e.g. "upstream" or "origin".
#   VCS_STATUS_REMOTE_BRANCH        Upstream branch name. Can be empty.
#   VCS_STATUS_REMOTE_URL           Remote URL. Can be empty.
#   VCS_STATUS_ACTION               Repository state, A.K.A. action. Can be empty.
#   VCS_STATUS_INDEX_SIZE           The number of files in the index.
#   VCS_STATUS_NUM_STAGED           The number of staged changes.
#   VCS_STATUS_NUM_CONFLICTED       The number of conflicted changes.
#   VCS_STATUS_NUM_UNSTAGED         The number of unstaged changes.
#   VCS_STATUS_NUM_UNTRACKED        The number of untracked files.
#   VCS_STATUS_HAS_STAGED           1 if there are staged changes, 0 otherwise.
#   VCS_STATUS_HAS_CONFLICTED       1 if there are conflicted changes, 0 otherwise.
#   VCS_STATUS_HAS_UNSTAGED         1 if there are unstaged changes, 0 if there aren't, -1 if
#                                   unknown.
#   VCS_STATUS_NUM_UNSTAGED_DELETED The number of unstaged deleted files. Note that renamed files
#                                   are reported as deleted plus added.
#   VCS_STATUS_HAS_UNTRACKED        1 if there are untracked files, 0 if there aren't, -1 if
#                                   unknown.
#   VCS_STATUS_COMMITS_AHEAD        Number of commits the current branch is ahead of upstream.
#                                   Non-negative integer.
#   VCS_STATUS_COMMITS_BEHIND       Number of commits the current branch is behind upstream.
#                                   Non-negative integer.
#   VCS_STATUS_STASHES              Number of stashes. Non-negative integer.
#   VCS_STATUS_TAG                  The last tag (in lexicographical order) that points to the same
#                                   commit as HEAD.
#
# The point of reporting -1 via VCS_STATUS_HAS_* is to allow the command to skip scanning files in
# large repos. See -m flag of gitstatus_start.
#
# gitstatus_query returns an error if gitstatus_start hasn't been called in the same
# shell or the call had failed.
function gitstatus_query() {
  unset OPTIND
  local opt dir="${GIT_DIR:-}" timeout=()
  while getopts "d:c:t:" opt "$@"; do
    case "$opt" in
      d) dir=$OPTARG;;
      t) timeout=(-t "$OPTARG");;
      *) return 1;;
    esac
  done
  (( OPTIND == $# + 1 )) || { echo "usage: gitstatus_query [OPTION]..." >&2; return 1; }

  [[ -n "$GITSTATUS_DAEMON_PID" ]] || return  # not started

  local req_id="$RANDOM.$RANDOM.$RANDOM.$RANDOM"
  [[ "$dir" == /* ]] || dir="$(pwd -P)/$dir" || return
  echo -nE "$req_id"$'\x1f'"$dir"$'\x1e' >&$_GITSTATUS_REQ_FD || return

  local -a resp
  while true; do
    IFS=$'\x1f' read -rd $'\x1e' -a resp -u $_GITSTATUS_RESP_FD "${timeout[@]}" || return
    [[ "${resp[0]}" == "$req_id" ]] && break
  done

  if [[ "${resp[1]}" == 1 ]]; then
    VCS_STATUS_RESULT=ok-sync
    VCS_STATUS_WORKDIR="${resp[2]}"
    VCS_STATUS_COMMIT="${resp[3]}"
    VCS_STATUS_LOCAL_BRANCH="${resp[4]}"
    VCS_STATUS_REMOTE_BRANCH="${resp[5]}"
    VCS_STATUS_REMOTE_NAME="${resp[6]}"
    VCS_STATUS_REMOTE_URL="${resp[7]}"
    VCS_STATUS_ACTION="${resp[8]}"
    VCS_STATUS_INDEX_SIZE="${resp[9]}"
    VCS_STATUS_NUM_STAGED="${resp[10]}"
    VCS_STATUS_NUM_UNSTAGED="${resp[11]}"
    VCS_STATUS_NUM_CONFLICTED="${resp[12]}"
    VCS_STATUS_NUM_UNTRACKED="${resp[13]}"
    VCS_STATUS_COMMITS_AHEAD="${resp[14]}"
    VCS_STATUS_COMMITS_BEHIND="${resp[15]}"
    VCS_STATUS_STASHES="${resp[16]}"
    VCS_STATUS_TAG="${resp[17]:-}"
    VCS_STATUS_NUM_UNSTAGED_DELETED="${resp[18]:-0}"
    VCS_STATUS_HAS_STAGED=$((VCS_STATUS_NUM_STAGED > 0))
    if (( _GITSTATUS_DIRTY_MAX_INDEX_SIZE >= 0 &&
          VCS_STATUS_INDEX_SIZE > _GITSTATUS_DIRTY_MAX_INDEX_SIZE_ )); then
      VCS_STATUS_HAS_UNSTAGED=-1
      VCS_STATUS_HAS_CONFLICTED=-1
      VCS_STATUS_HAS_UNTRACKED=-1
    else
      VCS_STATUS_HAS_UNSTAGED=$((VCS_STATUS_NUM_UNSTAGED > 0))
      VCS_STATUS_HAS_CONFLICTED=$((VCS_STATUS_NUM_CONFLICTED > 0))
      VCS_STATUS_HAS_UNTRACKED=$((VCS_STATUS_NUM_UNTRACKED > 0))
    fi
  else
    VCS_STATUS_RESULT=norepo-sync
    unset VCS_STATUS_WORKDIR
    unset VCS_STATUS_COMMIT
    unset VCS_STATUS_LOCAL_BRANCH
    unset VCS_STATUS_REMOTE_BRANCH
    unset VCS_STATUS_REMOTE_NAME
    unset VCS_STATUS_REMOTE_URL
    unset VCS_STATUS_ACTION
    unset VCS_STATUS_INDEX_SIZE
    unset VCS_STATUS_NUM_STAGED
    unset VCS_STATUS_NUM_UNSTAGED
    unset VCS_STATUS_NUM_CONFLICTED
    unset VCS_STATUS_NUM_UNTRACKED
    unset VCS_STATUS_HAS_STAGED
    unset VCS_STATUS_HAS_UNSTAGED
    unset VCS_STATUS_HAS_CONFLICTED
    unset VCS_STATUS_HAS_UNTRACKED
    unset VCS_STATUS_COMMITS_AHEAD
    unset VCS_STATUS_COMMITS_BEHIND
    unset VCS_STATUS_STASHES
    unset VCS_STATUS_TAG
    unset VCS_STATUS_NUM_UNSTAGED_DELETED
  fi
}

# Usage: gitstatus_check.
#
# Returns 0 if and only if gitstatus_start has succeeded previously.
# If it returns non-zero, gitstatus_query is guaranteed to return non-zero.
function gitstatus_check() {
  [[ -n "$GITSTATUS_DAEMON_PID" ]]
}
