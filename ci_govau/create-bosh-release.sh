#!/bin/bash

set -e
set -x

VERSION=$(cat version/number)-govau
RELEASE_ROOT="$PWD/github-release-info"
RELEASE_NAME=${bosh_release_name}

cp -r ./git/. boshrelease-output

pushd boshrelease-output

  # move community dirs to temp location
  mv .final_builds .final_builds_community
  mv config config_community
  mv releases releases_community
  # move govau dirs into offical location for purpose of build
  mv releases_govau releases
  mv .final_builds_govau .final_builds
  mv config_govau config
  # BOSH release details
  rm -rf .dev_builds dev_releases
  cat > ./config/private.yml << EOF
---
blobstore:
  provider: s3
  options:
    access_key_id: ${access_key_id}
    secret_access_key: ${secret_access_key}
EOF
  # work-around Go BOSH CLI trying to rename blobs downloaded into ~/.root/tmp
  # into release dir, which is invalid cross-device link
  export HOME=$PWD
  bosh sync-blobs
  bosh -n create-release --final --force --tarball=${RELEASE_ROOT}/${RELEASE_NAME}-$VERSION.tgz --name $RELEASE_NAME --version $VERSION

  # GIT!
  if [[ -z $(git config --global user.email) ]]; then
    git config --global user.email "tools+concourse@digital.gov.au"
  fi
  if [[ -z $(git config --global user.name) ]]; then
    git config --global user.name "cloud-gov-au-concourse"
  fi

  # move govau specific dirs around and commit
  mv releases releases_govau
  mv releases_community releases
  mv .final_builds .final_builds_govau
  mv .final_builds_community .final_builds
  mv config config_govau
  mv config_community config
  git add releases_govau .final_builds_govau
  git commit -m"New GOVAU release of $RELEASE_NAME"

  RELEASE_SHA1=$(sha1sum ${RELEASE_ROOT}/${RELEASE_NAME}-$VERSION.tgz |awk '{print $1}')

  # prep details for github release
  echo "v${VERSION}"                 > ${RELEASE_ROOT}/tag
  echo "${RELEASE_NAME} v${VERSION}" > ${RELEASE_ROOT}/name
  cat > ${RELEASE_ROOT}/body         << EOF
## Manifest
\`\`\`
releases:
- name: $RELEASE_NAME
  version: $VERSION
  sha1: $RELEASE_SHA1
  url: https://github.com/govau/${RELEASE_NAME}-boshrelease/releases/download/v${VERSION}/${RELEASE_NAME}-${VERSION}.tgz
\`\`\`

EOF

  echo ""
popd
