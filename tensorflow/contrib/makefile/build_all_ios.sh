#!/usr/bin/env bash
# Copyright 2015 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

set -e

ARCHS="ARMV7 ARMV7S ARM64 I386 X86_64"

USAGE="usage: build_all_ios.sh [-A architecture]

A script to build tensorflow and all dependencies for ios.
This script can only be run on MacOS host platforms.

Options:
-A architecture
Target platforms to compile. The default is: $ARCHS."

while
  ARG="${1-}"
  case "$ARG" in
  -*)  case "$ARG" in -*A*) ARCHS="${2?"$USAGE"}"; shift; esac
       case "$ARG" in -*[!A]*) echo "$USAGE" >&2; exit 2;; esac;;
  "")  break;;
  *)   echo "$USAGE" >&2; exit 2;;
  esac
do
  shift
done

# Make sure we're on OS X.
if [[ $(uname) != "Darwin" ]]; then
    echo "ERROR: This makefile build requires macOS, which the current system "\
    "is not."
    exit 1
fi

# Make sure we're in the correct directory, at the root of the source tree.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ${SCRIPT_DIR}/../../../


# Remove any old files first.
make -f tensorflow/contrib/makefile/Makefile clean
rm -rf tensorflow/contrib/makefile/downloads

# Setting a deployment target is required for building with bitcode,
# otherwise linking will fail with:
#
#    ld: -bind_at_load and -bitcode_bundle (Xcode setting ENABLE_BITCODE=YES) cannot be used together
#
if [[ -n MACOSX_DEPLOYMENT_TARGET ]]; then
    export MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion)
fi

# Pull down the required versions of the frameworks we need.
tensorflow/contrib/makefile/download_dependencies.sh

# Compile protobuf for the target iOS device architectures.
tensorflow/contrib/makefile/compile_ios_protobuf.sh -A "${ARCHS}"

# Compile nsync for the target iOS device architectures.
# Don't use  export var=`something` syntax; it swallows the exit status.
NSYNC_ARCHS=`echo "${ARCHS}" | tr "[:upper:]" "[:lower:]"`
HOST_NSYNC_LIB=`tensorflow/contrib/makefile/compile_nsync.sh`
TARGET_NSYNC_LIB=`tensorflow/contrib/makefile/compile_nsync.sh -t ios -a "${NSYNC_ARCHS}"`
export HOST_NSYNC_LIB TARGET_NSYNC_LIB

# Build the iOS TensorFlow libraries.
tensorflow/contrib/makefile/compile_ios_tensorflow.sh -A "${ARCHS}" -F "-Os -DSELECTIVE_REGISTRATION"

# Creates a static universal library in
# tensorflow/contrib/makefile/gen/lib/libtensorflow-core.a
