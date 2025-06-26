#!/usr/bin/env bash

git_username=
git_email=

read -p "GIT> Enter full name: " git_username
read -p "GIT> Enter email address: " git_email
echo "GIT> $git_username ($git_email) will be set as global git user!"

echo "GIT> Configuring GIT..."
git config --global user.name $git_username &> /dev/null
git config --global user.email $git_email &> /dev/null
echo