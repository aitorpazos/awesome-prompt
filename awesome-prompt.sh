#!/bin/bash
#
# awesome-prompt.sh
#
# This script provides an easy way to enjoy a colorful responsive prompt.
# It divides the prompt line in three sections: left, center and right.
# If they don't fit, it will move those sections that doesn't fit to the next line.
#
# Instructions:
# - In order to use this script using the default config, you just need to add
# this line to your $HOME/.bashrc file:
#                 source <full path to the script>
# - You can modify shown information using environment variables that you can
# export before sourcing the line in the previous point or while running for temporary
# modifications: export <option>=1
# - Supported options:
#       - SHOW_BAT_STATUS -> Shows the battery charge and if you are running on AC or battery
#       - SHOW_SYS_STATS  -> Shows the most CPU consuming process at the moment
#       - SHOW_DOCKER     -> Shows currently running Docker containers. Beware of it's performance impact.
#       - SHOW_LXC        -> Shows currently running LXC containers. Beware of it's performance impact.
#       - SHOW_QEMU       -> Shows currently running Qemu VMs. Beware of it's performance impact.
#       - SHOW_VBOX       -> Shows currently running VirtualBox VMs. Beware of it's performance impact.
#       - SHOW_GIT        -> Shows GIT information of current working directory. It requires that
#                      git-prompt.sh script which is part of Git distribution
#                      (possibly at /etc/bash_completion.d/git-prompt.sh ) has been
#                      sourced before this script. i.e.:
#                           source $HOME/.git-prompt.sh
#                           export SHOW_GIT=1
#                           source $HOME/awesome-prompt.sh
#       - SHOW_SIMPLE    -> Shows a minimal prompt. Useful for screen recording/sharing
#       - SHOW_TIMING    -> Only for debug purposes. It prints timing information to
#                           stderr in order to help spotting commands that might
#                           slow the prompt
#
# Copyright (C) 2016 Aitor Pazos <mail@aitorpazos.es>
# Distributed under the GNU General Public License, version 3.0.
#

export HOST=$(hostname -s)

# Colors
color_reset="\[$(tput sgr0)\]"
color_default="\[$(tput setaf 0)\]"
color_black="\[$(tput setaf 232)\]"
color_red="\[$(tput setaf 88)\]"
color_green="\[$(tput setaf 28)\]"
color_yellow="\[$(tput setaf 178)\]"
color_blue="\[$(tput setaf 26)\]"
color_fucsia="\[$(tput setaf 63)\]"
color_cyan="\[$(tput setaf 74)\]"
color_white="\[$(tput setaf 15)\]"
# Background colors
bg_default="\[$(tput setab 0)\]"
bg_black="\[$(tput setab 232)\]"
bg_red="\[$(tput setab 88)\]"
bg_green="\[$(tput setab 28)\]"
bg_yellow="\[$(tput setab 178)\]"
bg_blue="\[$(tput setab 26)\]"
bg_fucsia="\[$(tput setab 63)\]"
bg_cyan="\[$(tput setab 74)\]"
bg_white="\[$(tput setab 15)\]"

# Function that evaluates last command's exit code.
# It will show OK if it returned 0, it prints the result code and the command line
# otherwise. If the length is greater than certain length (default = 30 chars)
# the returned string is ellipsed
function exitstatus() {
    local MAX_CHARS=30;
	if [[ "${lastCommandResult}" -eq "0" ]]; then
		echo "${color_green}✅${color_white}";
	else
		local suffix="";
		if [[ "`echo ${lastCommand} | wc -m`" -gt ${MAX_CHARS} ]]; then
			suffix="...";
		fi;
		local commandCut="$(echo ${lastCommand} | cut -c 1-${MAX_CHARS})"
		echo "${color_red}❌ ${lastCommandResult} 👉 ${commandCut}${suffix}${color_white}";
	fi
}

# Prints timing information if SHOW_TIMING environment variable is set.
# It takes a message string as first argument and the reference time (as returned
# by "date +%s.%N" command) in seconds
function printTiming() {
    local TIMING_MESSAGE=$1
    local START=$2;
    local END=$(date +%s.%N)
	local DIFF=$(echo "$END - $START" | bc)
	local PROMPT_TIMING="${DIFF}"
	if [ -n "${SHOW_TIMING}" ]; then echo "${TIMING_MESSAGE}: ${PROMPT_TIMING}" 1>&2; fi
}

# Calculates screen's middle character
function screencenter() {
	echo "$COLUMNS / 2" | bc;
}

# Strips color characters from the string in order to allow the correct layout
# calcultaions
function stripcolor() {
	echo -e "$*" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\\\[//g' | sed 's/\\\]//g';
}

# With emojis, characters calculations may need some adjustment
function char_adjustment() {
    echo -e "$*" | sed 's/[📂🕵📄🐍📦🐋🔌🔋💻🧮❌👉✅▶⡇]/--/g'
}

# Returns the count of characters of a string
function countstr() {
    echo "$(char_adjustment $(stripcolor "$*"))" | wc -m;
}

# Returns a new line if the parameter is 0 and $1 number of spaces otherwise
function newline_spaces() {
	if [[ "$1" -eq "0" ]]; then
		echo "\\n";
	else
		printf "%*s" "$1" " ";
	fi
}

# Identifies the process that currently is taking the most CPU
function syssummary() {
	local START=$(date +%s.%n)
    local guiltyProc="$(echo -n "${summary}" | tail -1 | cut -c48-)";
    local cpu="$(echo "${guiltyProc}" | cut -f1 -d',')";
    local mem="$(echo "${guiltyProc}" | cut -f2 -d',' | cut -f2- -d' ')";
    local name="$(echo "${guiltyProc}" | cut -f2 -d'.' | cut -f2- -d' ')";
    echo "${color_black}${bg_yellow}💻:${cpu}% 🧮:${mem}%◀${color_yellow}${bg_black}${name}";
	printTiming "Performance info timing" $START;
}

# Returns charge status for all batteries installed
function batStatus() {
	local START=$(date +%s.%n)
	local SYS_BAT_BASE="/sys/class/power_supply/"
	local BAT_STR=""
	if [ 1 -eq `cat ${SYS_BAT_BASE}/AC/online` ]; then
	  BAT_STR="${color_white}${bg_green}🔌"
	else
	  BAT_STR="${color_white}${bg_red}🔋"
	fi
	local BAT_NO=1

	for bat in `ls ${SYS_BAT_BASE}`; do
	  # Checking if batteries attributes exist
      if [ -f "${SYS_BAT_BASE}/${bat}/capacity" ]; then
	    local BAT_NAME=`cat ${SYS_BAT_BASE}/${bat}/model_name`
		local DISPLAY_BAT_NAME=${BAT_NAME}
		if [ ${#DISPLAY_BAT_NAME} -gt 7 ]; then
			DISPLAY_BAT_NAME=${DISPLAY_BAT_NAME:0:5}..:
		else
			DISPLAY_BAT_NAME=${DISPLAY_BAT_NAME}:
		fi
		local BAT_CHARGING=""
  	    local BAT_CHARGE=`cat "${SYS_BAT_BASE}/${bat}/capacity"`%;
		if [ -f ${SYS_BAT_BASE}/${bat}/capacity_level ] && [ "Full" == `cat "${SYS_BAT_BASE}/${bat}/capacity_level"` ]; then
			BAT_CHARGE="Full"
		fi
		BAT_STR="${BAT_STR}${DISPLAY_BAT_NAME}${BAT_CHARGING}${BAT_CHARGE} "
	    BAT_NO=$((${BAT_NO} + 1))
	  fi
	done;
	echo "$BAT_STR"
	printTiming "Battery info timing" $START;
}

# Returns the status of Docker containers
function dockerRunning() {
	local START=$(date +%s.%n)
    docker ps > /dev/null 2>&1;
    if [[ "$?" -eq "0" ]]; then
        local dockerOutput="$(echo "$(docker ps | wc -l) - 1" | bc)";
        if [[ "${dockerOutput}" -ne "0" ]]; then
            dockerOutput="${dockerOutput} "$(docker ps --format "{{.Names}}")"";
        fi
        echo ${dockerOutput};
    else
        echo "Off";
    fi;
	printTiming "Docker timing" $START
}

# Returns the status of LXC containers
function lxcRunning() {
	local START=$(date +%s.%N)
    which virsh > /dev/null 2>&1;
    if [[ "$?" -eq "0" ]]; then
      local vmCount="$(echo "$(virsh -r -c lxc:/// list --name 2> /dev/null | wc -l) - 1" | bc)";
      if [[ "${vmCount}" -ge "0" ]]; then
        local lxcOutput="${vmCount}";
        if [[ "${lxcOutput}" -gt "0" ]]; then
            lxcOutput="${lxcOutput} "$(virsh -r -c lxc:/// list --name)"";
        fi;
        echo ${lxcOutput};
      else
        echo "Off";
      fi;
    else
        echo "Off";
    fi;
	printTiming "Lxc timing" $START
}

# Returns the status of Qemu VMs
function qemuRunning() {
	local START=$(date +%s.%N)
    which virsh > /dev/null 2>&1;
    if [[ "$?" -eq "0" ]]; then
        local qemuOutput="$(echo "$(virsh -r -c qemu:///session list --name | wc -l) - 1" | bc)";
        if [[ "${qemuOutput}" -ne "0" ]]; then
            qemuOutput="${qemuOutput} "$(virsh -r -c qemu:///session list --name)"";
        fi
        echo ${qemuOutput};
    else
        echo "Off";
    fi;
	printTiming "Qemu timing" $START
}

# Returns the status of VBox VMs
function vboxRunning() {
	local START=$(date +%s.%N)
    local vboxOutput="Off"
    if [ -c /dev/vboxdrv ]; then
        which VBoxManage > /dev/null 2>&1;
        if [[ "$?" -eq "0" ]]; then
            vboxOutput="$(echo "$(VBoxManage list runningvms | wc -l)" | bc)";
            if [[ "${vboxOutput}" -ne "0" ]]; then
                vboxOutput="${vboxOutput} {"$(VBoxManage list runningvms | cut -d'"' -f2)"}";
            fi
        fi;
    fi;
    echo ${vboxOutput}
	printTiming "VBox timing" $START
}

# Returns the right portion of the prompt
function prompt_right() {
	local START=$(date +%s.%N)
	local sysstats="";
	if [ -n "${SHOW_SYS_STATS}" ]; then
		sysstats="$(syssummary)"
    fi
	if [ -n "${SHOW_BAT_STATUS}" ]; then
		batstatus="$(batStatus)"
	fi
	echo "${color_black}${color_green}${bg_black}${jobs}${color_white}${bg_black}${containersAndVms}${batstatus}${sysstats} ${color_black}${bg_white}${color_white}${bg_blue} $(date +%H:%M:%S)${color_reset}";
	printTiming "Right" $START
}

# Returns the left portion of the prompt
function prompt_left() {
	local START=$(date +%s.%N)
	echo "${bg_blue}$USER@\h${color_blue}${bg_black}${color_white}${bg_black}$(stat -c '%A %U:%G' "$PWD") | 📂${dir} (🕵${hiddenDir}) | 📄${files} (🕵${hiddenFiles}) ${color_black}${bg_default}${color_default}";
	printTiming "Left" $START
}

# Returns the center portion of the prompt
function prompt_center() {
	local START=$(date +%s.%N)
	echo "$(exitstatus)";
	printTiming "Center" $START
}

# Calculates the padding spaces that should be inserted before the right portion
# of the prompt
function right_spaces() {
	local START=$(date +%s.%N)
	local spaces=1;

	if [[ -z "${centerSpacesStr}" ]]; then
		# If center field has been moved to next line, we keep this one in first line if it fits
		spaces="$(echo "${COLUMNS} - $(countstr "${promptLeftStr}${promptRightStr}")" | bc)";
		if [[ "$(countstr "${promptCenterStr} ${promptRightStr}")" -gt "${COLUMNS}" ]]; then
			spaces=0;
		fi
	elif [[ "$(countstr "${promptLeftStr}${promptCenterStr}${promptRightStr}")" -gt "$(echo "${COLUMNS} - ${centerSpacesStr}" | bc)" ]]; then
		# Three fields don't fit
		spaces="0";
	else
		spaces="$(echo "${COLUMNS} - ${centerSpacesStr} - $(countstr "${promptLeftStr}${promptCenterStr}${promptRightStr}")" | bc)";
	fi;
	echo "${spaces}";
	printTiming "Right Spaces" $START
}

# Calculates the padding spaces that should be inserted before the center portion
# of the prompt
function center_spaces() {
	local START=$(date +%s.%N)
	local spaces="1";
	local centerHalf="$(echo "$(countstr "${promptCenterStr}") / 2" | bc)";
	local centerStart="$(echo "$(screencenter) - ${centerHalf}" | bc)";

	if [[ "$(countstr "${promptLeftStr} ${promptCenterStr}")" -gt "${COLUMNS}" ]]; then
		# Both fields don't fit
		spaces="0";
	elif [[ "$(countstr "${promptLeftStr}")" -gt "${centerStart}" ]]; then
		# Left field gets to the middle of the screen
		spaces="1";
	else
		# Center alignment
		spaces="$(echo "${centerStart} - $(countstr "${promptLeftStr}")" | bc)";
	fi
	echo "${spaces}";
	printTiming "Center Spaces" $START
}

# Main function that generates the prompt string and sets PS1 environment variable
#
# You should place heavy commands that should only be run once per prompt in this function
function prompt() {
    if [ -n "${SHOW_SIMPLE}" ]; then
      PS1="\w\$ "
      return
    fi
	lastCommandResult="$?";
    # Saving initial time for logging purposes
    local START=$(date +%s.%N)
	lastCommand="$(history 1 | cut -f3- -d' ')";

    #### Left
    dir="$(find . -maxdepth 1 -type d 2>/dev/null | wc -l)";
    hiddenDir="$(find . -maxdepth 1 -type d -name ".?*" 2>/dev/null | wc -l)";
	files="$(find . -maxdepth 1 -type f 2>/dev/null | wc -l)";
    hiddenFiles="$(find . -maxdepth 1 -type f -name ".*" 2>/dev/null | wc -l)";
	promptLeftStr="$(prompt_left)"
	printTiming "Left side" $START

    #### Center
    promptCenterStr="$(prompt_center)"
    centerSpacesStr="$(center_spaces)"
	printTiming "Center side" $START

    #### Right
    jobs="$(if [[ -n "$(jobs)" ]]; then echo '⚙:\j '; else echo ''; fi)";
	#VBox and Qemu are a bit too slow...
	containersAndVms=""
	if [ -n "${SHOW_VBOX}" ]; then
		containersAndVms="${containersAndVms} 📦VBox:$(vboxRunning)";
	fi
	if [ -n "${SHOW_QEMU}" ]; then
		containersAndVms="${containersAndVms} 📦Qemu:$(qemuRunning)";
	fi
    if [ -n "${SHOW_LXC}" ]; then
    	containersAndVms="${containersAndVms} 📦Lxc:$(lxcRunning)";
    fi
    if [ -n "${SHOW_DOCKER}" ]; then
    	containersAndVms="${containersAndVms} 🐋:$(dockerRunning)";
    fi
    containersAndVms="${containersAndVms} "

    # Sys stats summary
	if [ -n "${SHOW_SYS_STATS}" ]; then
	    summary="$(top -bn1 | grep -v top | head -6)";
	fi
    promptRightStr="$(prompt_right)"
	printTiming "Right side" $START

    #### Second line
    local GIT_OUTPUT=""
    if [ -n "${SHOW_GIT}" ]; then
        GIT_OUTPUT=$(__git_ps1 " ⎇ %s  ")
    fi

    # Python virtual env support
    local PYTHON_VENV_OUTPUT=""
    if [ -n "${VIRTUAL_ENV}" ]; then
        PYTHON_VENV_OUTPUT=" 🐍$(basename ${VIRTUAL_ENV}) "
    fi

    # Set the actual line content
	local lineTwo="${color_reset}${bg_default}"$PWD"${color_black}${bg_yellow}${GIT_OUTPUT}${PYTHON_VENV_OUTPUT}${color_white}${bg_default}\$${color_reset} ";

	PS1=$(echo -e "${promptLeftStr}$(newline_spaces "${centerSpacesStr}")${promptCenterStr}$(newline_spaces "$(right_spaces)")${promptRightStr}\n${lineTwo}");
	printTiming "Prompt timing" $START
}

export PROMPT_COMMAND=prompt

