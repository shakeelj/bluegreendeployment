#!/usr/bin/env bash

set -o nounset
set -o noclobber
set -o errexit
set -o pipefail

rm -f ~/test.dat
touch ~/test.dat

id >>~/test.dat
whoami >>~/test.dat
date >>~/test.dat
hostname >>~/test.dat
uname -a >>~/test.dat
cat /etc/issue >>~/test.dat
cat ~/test.dat
