#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if [[ -n ${VERBOSE:-} ]]; then
    set -x
fi

TARGET_DIR="${TARGET_DIR:-}"
SOURCE_DIR="${SOURCE_DIR:-}"
if [[ -z "${TARGET_DIR}" ]]; then
  echo "Unknown TARGET_DIR"
  exit 1
fi
if [[ -z "${SOURCE_DIR}" ]]; then
  echo "Unknown SOURCE_DIR"
  exit 1
fi

if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "Destination directory not found"
    exit 1
fi

if [[ "${SOURCE_DIR}" == /* ]] && [[ ! -d "${SOURCE_DIR}" ]]; then
    echo "Source directory not found"
    exit 1
fi

TIMESTAMP="$(date +%Y-%m-%d.%H-%M-%S)"
TARGET_DIR_PATH="${TARGET_DIR/%\//}/daily"
COMPLETE_TARGET_DIR="${TARGET_DIR_PATH}.backup_${TIMESTAMP}"
INCOMPLETE_TARGET_DIR="${TARGET_DIR_PATH}.incomplete"
CURRENT_TARGET_DIR="${TARGET_DIR_PATH}.current"

RSYNC_ARGS=(
    --archive
    --one-file-system
    --hard-links
    --human-readable
    --inplace
    --numeric-ids
    --delete
    --ignore-errors
    --verbose
    -F # --filter='dir-merge /.rsync-filter' repeated: --filter='- .rsync-filter'
    --link-dest="${CURRENT_TARGET_DIR}/"
    ${RSYNC_OPTIONS:-}
    "${SOURCE_DIR/%\//}/"
    "${INCOMPLETE_TARGET_DIR}/"
)

# 1. Copy over all files
# 2. only when successful, move the incomplete path to a completed path
# 3. delete the quick reference symlink the most recent backup
# 4. make a new reference to the latest backup
# 5. make sure this folder's last modified time is now!
rsync "${RSYNC_ARGS[@]}" \
    && mv "${INCOMPLETE_TARGET_DIR}" "${COMPLETE_TARGET_DIR}" \
    && rm -f "${CURRENT_TARGET_DIR}" \
    && (cd "${TARGET_DIR}" && ln -s "$(basename "${COMPLETE_TARGET_DIR}")" "${CURRENT_TARGET_DIR}" ) \
    && touch "${COMPLETE_TARGET_DIR}"

TARGET_DIR="${TARGET_DIR:-}"
MAX_AGE="${MAX_AGE:-180}"
if [[ -z "${TARGET_DIR}" ]]; then
    echo "Unknown TARGET_DIR"
    exit 1
fi

if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "Destination directory not found"
    exit 1
fi

TARGET_DIR_PATH="${TARGET_DIR/%\//}"
FIND_ARGS=(
    "${TARGET_DIR_PATH}"
    -maxdepth 1
    -iname 'daily.*'
    -mtime +${MAX_AGE}
    -type d
)

# If there's no files to delete, that's ok
if ! ( find "${FIND_ARGS[@]}" \
    | grep -v incomplete \
    | grep -q -v "$(basename "$(readlink "${TARGET_DIR_PATH}/daily.current")")" ); then
    exit 0
fi

# print found files for logging
find "${FIND_ARGS[@]}" \
    | grep -v incomplete \
    | grep -v "$(basename "$(readlink "${TARGET_DIR_PATH}/daily.current")")" \
    | sort

# 1. Find all old backups
# 2. Exclude the current in progress folder
# 3. Exclude the current backup
# 4. remove found backups
find "${FIND_ARGS[@]}" \
    | grep -v incomplete \
    | grep -v "$(basename "$(readlink "${TARGET_DIR_PATH}/daily.current")")" \
    | sort \
    | xargs -t -r rm -rf
