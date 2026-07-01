#!/bin/bash
# Source this file:  source refresh-token.sh
#
# It must export vars into your *current* shell, so it is meant to be sourced.
# That means it MUST NOT use `set -e`/`set -u`/`exit` — when sourced, those act
# on your interactive shell and a single failure would close your terminal.
# Use `return` (works when sourced) with an `exit` fallback (when executed).

_rt_fail() { echo "refresh-token: $1" >&2; return 1 2>/dev/null || exit 1; }

_rt_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_rt_env="${_rt_dir}/.env"

[[ -f "$_rt_env" ]] || _rt_fail ".env not found at $_rt_env (copy .env.example to .env and fill it in)"

set -a
# shellcheck disable=SC1090
source "$_rt_env"
set +a

[[ -n "${SERVICE_ACCOUNT_ID:-}"   ]] || _rt_fail "SERVICE_ACCOUNT_ID not set in .env"
[[ -n "${AWS_ACCESS_KEY_ID:-}"    ]] || _rt_fail "AWS_ACCESS_KEY_ID not set in .env"
[[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] || _rt_fail "AWS_SECRET_ACCESS_KEY not set in .env"

if ! _rt_token=$(yc iam create-token --impersonate-service-account-id "$SERVICE_ACCOUNT_ID" 2>&1); then
  _rt_fail "yc iam create-token failed: $_rt_token"
fi
export YC_TOKEN="$_rt_token"

export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
export TF_VAR_folder_id="$YC_FOLDER_ID"

echo "Token refreshed, expires in 12 hours"
