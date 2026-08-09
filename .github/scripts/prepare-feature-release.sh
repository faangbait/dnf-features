#!/usr/bin/env bash

set -euo pipefail

features_root="${1:-src}"
release_features=()
bumped_features=()

if [[ ! -d "$features_root" ]]; then
    echo "Feature directory does not exist: $features_root" >&2
    exit 1
fi

while IFS= read -r metadata_file; do
    feature_dir="${metadata_file%/devcontainer-feature.json}"
    feature_id="$(node -p "require('./${metadata_file}').id")"
    current_version="$(node -p "require('./${metadata_file}').version")"
    current_tag="feature_${feature_id}_${current_version}"

    if ! git rev-parse --verify --quiet "refs/tags/${current_tag}" >/dev/null; then
        echo "${feature_id}: ${current_version} has not been released"
        release_features+=("$feature_id")
        continue
    fi

    if git diff --quiet "$current_tag" -- \
        "$feature_dir" \
        ":(exclude)$feature_dir/README.md"; then
        echo "${feature_id}: no package changes since ${current_tag}"
        continue
    fi

    if [[ ! "$current_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "Cannot automatically patch-bump ${feature_id} from '${current_version}'." >&2
        echo "Set an unreleased semantic version in ${metadata_file}." >&2
        exit 1
    fi

    next_version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((10#${BASH_REMATCH[3]} + 1))"
    node - "$metadata_file" "$next_version" <<'NODE'
const fs = require("fs");

const [metadataFile, nextVersion] = process.argv.slice(2);
const metadata = JSON.parse(fs.readFileSync(metadataFile, "utf8"));
metadata.version = nextVersion;
fs.writeFileSync(metadataFile, `${JSON.stringify(metadata, null, 4)}\n`);
NODE

    echo "${feature_id}: ${current_version} -> ${next_version}"
    release_features+=("$feature_id")
    bumped_features+=("$feature_id")
done < <(find "$features_root" -mindepth 2 -maxdepth 2 \
    -name devcontainer-feature.json -type f -print | sort)

if ((${#release_features[@]} > 0)); then
    release=true
else
    release=false
fi

if ((${#bumped_features[@]} > 0)); then
    changed=true
else
    changed=false
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "release=$release"
        echo "changed=$changed"
        printf 'features=%s\n' "$(IFS=,; echo "${release_features[*]}")"
    } >>"$GITHUB_OUTPUT"
fi

echo "Release required: $release"
if [[ "$release" == "true" ]]; then
    printf 'Features to release: %s\n' "$(IFS=', '; echo "${release_features[*]}")"
fi
