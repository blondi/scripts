#!/usr/bin/env bash

git_username=
git_email=

echo -n "GIT> Enter full name: "
read git_username
echo -n "GIT> Enter email address: "
read git_email
echo "GIT> $git_username ($git_email) will be set as global git user!"

echo "GIT> Configuring GIT..."
git config --global user.name $git_username &> /dev/null
git config --global user.email $git_email &> /dev/null
echo