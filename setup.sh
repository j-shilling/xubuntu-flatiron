#!/bin/bash

# Detect uninitialised variables
set -o nounset
# Exit when any command fails
set -o errexit
# Exit on error inside any functions or subshells
set -o errtrace
# Detect errors before piping
set -o pipefail

readonly BASH_PROFILE_URL="https://raw.githubusercontent.com/learn-co-students/online-web-pt-081219/master/00-linux-virtual-machine/xubuntu/linux_bash_profile"
readonly IRBRC_URL="https://raw.githubusercontent.com/flatiron-school/dotfiles/master/irbrc"
readonly GITIGNORE_URL="https://raw.githubusercontent.com/flatiron-school/dotfiles/master/ubuntu-gitignore"
readonly GITCONFIG_URL="https://raw.githubusercontent.com/flatiron-school/dotfiles/master/linux_gitconfig"
readonly GPG_KEYS="409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB"

readonly user=${1:-$(whoami)}

eexit() {
	local __message=${1:-"An unkown error occured!"}
	echo ${__message}
	exit -1
}

run_as_root() {
	local __cmd=$1
	local __full_cmd="${__cmd}"
	eval "${__full_cmd}" || eexit "Failed to execute \"${__full_cmd}\""
}

run_as_user() {
	local __cmd=$1
	local __full_cmd="su -l ${user} -c \"${__cmd}\""
	eval "${__full_cmd}" || eexit "Failed to execute \"${__full_cmd}\""
}

run_if_not_installed() {
	local __program=$1
	local __cmd=$2

	run_as_user "hash ${__program} 2>/dev/null || ${__cmd}"
}

run_if_not_function() {
	local __function=$1
	local __cmd=$2

	run_as_user "type ${__function} 2>/dev/null || ${__cmd}"
}

username() {
	# Check if this is being run as root
	if [ "$UID" -eq 0 ]; then
		local __username=""
		echo -n "Set up a Flatiron environment for: "
		read __username
		echo "${__username}"
	else
		# Not root, return current user and elevate permissions
		echo $(whoami)
	fi
}

pkg_update() {
	run_as_root "apt-get -yq update"
}

pkg_upgrade() {
	run_as_root "apt-get -yq upgrade"
}

pkg_install() {
	local __packages=$1
	run_as_root "apt-get -yq install ${__packages}"
}

append_line_to_file_as_root() {
	local __line=$1
	local __file=$2

	run_as_root "grep -qxF '${__line}' ${__file} || echo '${__line}' >> ${__file}"
}

append_line_to_file_as_user() {
	local __line=$1
	local __file=$2

	run_as_user "grep -qxF '${__line}' ${__file} || echo '${__line}' >> ${__file}"
}

download() {
	local __url=$1
	local __output=$2

	run_as_user "wget ${__url} -O ${__output}"
}

#####
### Entry point
#####

main() {
	# Make sure that the system is up to date
	pkg_update
	pkg_upgrade

	# Make sure that required tools are installed: RVM requires
	# gnupg2 and curl; git is just good to have
	pkg_install "gnupg2 curl git"

	####
	## Setup Configuration files
	####

	# When RVM installs ruby, it's going to run a script that
	# involves running sudo. This script will only work if run
	# from an interactive shell and not from within this bash
	# script--this work around makes sudo not ask for a password,
	# so that we can run the RVM from within this script.
	# append_line_to_file_as_root "${user} ALL=(ALL) NOPASSWD:
	# ALL" "/etc/sudoers"
	append_line_to_file_as_root "${user} ALL=(ALL) NOPASSWD: ALL" "/etc/sudoers"

	# Download the flatiron bash_profile
	run_as_user "if [ -f ~/.profile ]; then mv ~/.profile{,.bak}; fi"

	download "${BASH_PROFILE_URL}" "${HOME}/.profile"

	# Tell the XFCE4 terminal emulated to use a login shell
	append_line_to_file_as_user "[Configuration]" "${HOME}/.config/xfce4/terminal/terminalrc"
	append_line_to_file_as_user "CommandLoginShell=TRUE" "${HOME}/.config/xfce4/terminal/terminalrc"

	# Download some more flatiron dotfiles
	download "${IRBRC_URL}" "${HOME}/.irbrc"
	download "${GITIGNORE_URL}" "${HOME}/.gitignore"
	download "${GITCONFIG_URL}" "${HOME}/.gitconfig"

	####
	## Install User Dev Tools
	####

	# Install RVM
	run_as_user "gpg2 --recv-keys ${GPG_KEYS}"
	run_if_not_installed "rvm" "wget -q -O - https://get.rvm.io | bash"

	# Install ruby
	run_if_not_installed "ruby" "rvm install ruby"

	# By default don't parse rdoc
	append_line_to_file_as_user "gem: --no-document" "${HOME}/.gemrc"

	# Install the needed gems
	run_as_user 'gem update --system'
	run_as_user 'gem install learn-co'
	run_as_user 'gem install phantomjs'
	pkg_install "libpq-dev"
	run_as_user 'gem install pg'
	run_as_user 'gem install sqlite3'
	run_as_user 'gem install bundler'
	run_as_user 'gem install rails'

	# Some problems come up if ~/.netrc doesn't exist
	run_as_user 'touch ~/.netrc && chmod 0600 ~/.netrc'

	# Install NVM
	run_if_not_function "nvm" "wget -q0- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.0/install.sh | bash"

	# Install node
	run_if_not_installed "node" "nvm install node"

	# Install create-react-app
	run_if_not_installed "create-react-app" "npm install -g create-react-app"

	# Install phantomjs
	run_if_not_installed "phantomjs" "npm install -g phantomjs"

	echo "

AUTO SETUP COMPLETE!!!

Please run \"learn whoami\" to finish setting up the learn gem.

"

	# Drop the user in a login shell
	run_as_root "su -l ${user}"
}

# If this script is being run as a normal user, then launch it again
# as root, passing the username in as an argument. Not everything in
# here needs to be run as a super use--if fact a lot of the commands
# need to be run by the user account we are configuring--but if we
# don't run su -l ${user} as root, then a password is needed every
# time.
if [ "${UID}" -eq 0 ]; then
	main
else
	exec sudo "$0" "${user}"
fi
