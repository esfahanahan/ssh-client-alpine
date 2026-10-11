#!/bin/sh
# Default command is ssh. SSH_PROFILE selects a complete config under
# /etc/ssh/profiles/. An explicit client command is executed unchanged.
set -eu

uid=$(id -u)
home=$(awk -F: -v uid="${uid}" '$3 == uid { print $6; exit }' /etc/passwd)
if [ -n "${home}" ] && { [ -z "${HOME:-}" ] || { [ "${HOME}" = "/root" ] && [ "${uid}" -ne 0 ]; }; }; then
  export HOME="${home}"
fi

if [ "$#" -ge 1 ]; then
  case "$1" in
    ssh|/usr/bin/ssh|scp|/usr/bin/scp|ssh-keygen|/usr/bin/ssh-keygen|ssh-agent|/usr/bin/ssh-agent|ssh-add|/usr/bin/ssh-add|sh|/bin/sh)
      exec "$@"
      ;;
  esac
fi

if [ -n "${SSH_PROFILE:-}" ]; then
  case "${SSH_PROFILE}" in
    strict|accept-new|skip-host-check|batch)
      exec ssh -F "/etc/ssh/profiles/${SSH_PROFILE}" "$@"
      ;;
    *)
      printf '%s\n' "entrypoint: unknown SSH_PROFILE '${SSH_PROFILE}' (expected strict, accept-new, skip-host-check, or batch)" >&2
      exit 1
      ;;
  esac
fi

exec ssh "$@"
