#!/usr/bin/env bash
# Thin wrapper: see muse/sync-data.sh
exec bash "$(dirname "$(readlink -f "$0")")/../muse/sync-data.sh" review-transactions "$@"
