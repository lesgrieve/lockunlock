#!/bin/sh
# Publishing to https://github.com/lesgrieve/lockunlock
# Copyright 2020 Les Grieve
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
PERIOD=1d
if [[ $# -ge 1 ]]; then
    PERIOD=$1
fi

# Thu 2020-06-04 10:55
# Solution to version comparison found on
# https://stackoverflow.com/a/4024263/4637974
verlte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

verlt() {
    [ "$1" = "$2" ] && return 1 || verlte $1 $2
}

echo "Times of Mac login, logout, lock, and unlock events in the past ${PERIOD}:"
LOCK_TERM='going inactive, create activity semaphore'
UNLOCK_TERM='user is active, releasing the activity semaphore'
SHUTDOWN_TERM='startLogout Enter'
LOGIN_TERM='Login Window Application Started'
MAC_VERSION=$(sw_vers -productVersion)

if ! verlt ${MAC_VERSION} 10.15.5
then
    # Thu 2020-06-04 09:58
    # A recent Mac update 10.15.5 (19F101) no longer uses this consistently
    UNLOCK_TERM='no activity semaphore, continuing auth'
elif verlt ${MAC_VERSION} 10.15
then
    # This worked for Mojave but not Catalina
    LOCK_TERM=">>>>>>>>>> \[-\[LUIAuthenticationServiceProvider deactivateWithContext:\]_block_invoke\] - com.apple.CryptoTokenKit.AuthenticationHintsProvider \[self userName\]"
fi

SEARCH_FOR="${LOCK_TERM}|${UNLOCK_TERM}|${SHUTDOWN_TERM}|${LOGIN_TERM}"
content=$(log show --style syslog --predicate 'process == "loginwindow"' --debug --info --last ${PERIOD} | grep -E "${SEARCH_FOR}")
green="\033[32m"
red="\033[31m"
while IFS= read -r line; do
    date=${line:0:19}
    reason=${line#*|}
    if [[ $reason == *"${LOCK_TERM}"* ]] || [[ $reason == *"${SHUTDOWN_TERM}"* ]]; then
        colour=${red}
    else
        colour=${green}
    fi
    printf "${colour}${date}  ${reason}\n"
done <<< "${content}"
