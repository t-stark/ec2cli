#!/usr/bin/env bash

#------------------------------------------------------------------------------
#   Author:  	Blake Huber
#   Purpose: 	ec2cli installer
#   Required:
#               - wget
#               - git
#
#   Description:
#               - suggest run script manually due to use of 'git pull'
#                 ie, your local repos will be merged with remote
#               - script traverses down 2 levels of hierarchy
#                 searching for git repos to update.
#
#------------------------------------------------------------------------------

# ec2cli git repository
repo_url='https://github.com/fstab50/ec2cli.git'

#
# global variables
#
PROJECT='ec2cli'
pkg=$(basename $0)
pkg_path=$(cd $(dirname $0); pwd -P)
log_file="$pkg_path/installer.log"
PWD=$(pwd .)
git=$(which git)
host=$(hostname)
system=$(uname)
clear=$(which clear)

# Configuration files, ancillary vars
CONFIG_DIR="ec2cli"
CONFIG_ROOT="$HOME/.config"
CONFIG_PATH="$CONFIG_ROOT/$CONFIG_DIR"
CONFIG_PATH_ALT="$HOME/.ec2cli"

# format
white=$(tput setaf 7)
bold='\u001b[1m'
title=$(echo -e ${bold}${white})
reset=$(tput sgr0)

#
# ---  delcarations -----------------------------------------------------------------------------------------
#

# indent
function indent02() { sed 's/^/  /'; }
function indent04() { sed 's/^/    /'; }

function std_logger(){
    local msg="$1"
    local prefix="$2"
    local log_file="$3"
    #
    if [ ! $prefix ]; then
        prefix="INFO"
    fi
    if [ ! -f $log_file ]; then
        # create log file
        touch $log_file
        if [ ! -f $log_file ]; then
            echo "[$prefix]: $pkg ($VERSION): failure to call std_logger, $log_file location not writeable"
            exit $E_DIR
        fi
    else
        echo "$(date +'%Y-%m-%d %T') $host - $pkg - $VERSION - [$prefix]: $msg" >> "$log_file"
    fi
}

function std_message(){
    #
    # Caller formats:
    #
    #   Logging to File | std_message "xyz message" "INFO" "/pathto/log_file"
    #
    #   No Logging  | std_message "xyz message" "INFO"
    #
    local msg="$1"
    local prefix="$2"
    local log_file="$3"
    #
    if [ $log_file ]; then
        std_logger "$msg" "$prefix" $log_file
    fi
    [[ $QUIET ]] && return
    shift
    pref="----"
    if [[ $1 ]]; then
        pref="${1:0:5}"
        shift
    fi
    if [ $format ]; then
        echo -e "${yellow}[ $cyan$pref$yellow ]$reset  $msg" | indent04
    else
        echo -e "\n${yellow}[ $cyan$pref$yellow ]$reset  $msg\n" | indent04
    fi
}

function std_error(){
    local msg="$1"
    std_logger "$msg" "ERROR" $log_file
    echo -e "\n${yellow}[ ${red}ERROR${yellow} ]$reset  $msg\n" | indent04
}

function std_warn(){
    local msg="$1"
    std_logger "$msg" "WARN" $log_file
    if [ "$3" ]; then
        # there is a second line of the msg, to be printed by the caller
        echo -e "\n${yellow}[ ${red}WARN${yellow} ]$reset  $msg" | indent04
    else
        # msg is only 1 line sent by the caller
        echo -e "\n${yellow}[ ${red}WARN${yellow} ]$reset  $msg\n" | indent04
    fi
}

function std_error_exit(){
    local msg="$1"
    local status="$2"
    std_error "$msg"
    exit $status
}

function precheck(){
    ## test default shell ##
    if [ ! -n "$BASH" ]; then
        # shell other than bash
        std_error_exit "Default shell appears to be something other than bash. Please rerun with bash. Aborting (code $E_BADSHELL)" $E_BADSHELL
    fi

    ## create log dir for ec2cli ##
    if [[ ! -d $pkg_path/logs ]]; then
        if ! mkdir -p "$pkg_path/logs"; then
            echo "$pkg: failed to make log directory: $pkg_path/logs"
            exit $E_NOLOG
        fi
    fi

    ## check for required cli tools ##
    for prog in which git aws ssh awk sed bc wget curl; do
        if ! type "$prog" > /dev/null 2>&1; then
            std_error_exit "$prog is required and not found in the PATH. Aborting (code $E_DEPENDENCY)" $E_DEPENDENCY
        fi
    done

    ## check if awscli tools are configured ##
    if [ $(curl http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null) ]; then
        std_message "Skipping awscli configuration check, appears to be EC2 instance detected." "INFO" $log_file
    else
        if [[ ! -f $HOME/.aws/config ]]; then
            std_error_exit "awscli not configured, run 'aws configure'. Aborting (code $E_DEPENDENCY)" $E_DEPENDENCY
        fi
    fi

    ## check for jq, use system installed version if found, otherwise use bundled ##
    if which jq > /dev/null; then
        jq=$(which jq)
    else
        jq="assets/jq/$system/jq"
        if [[ ! -f $jq ]]; then
            std_error_exit "no viable json parser binary (jq) found, Aborting (code $E_DEPENDENCY)" $E_DEPENDENCY
        fi
    fi

    ## config directories, files ##
    if [ -d $CONFIG_ROOT ]; then
        if [ ! -d $CONFIG_PATH ]; then
            std_message "Directory CONFIG_PATH ($CONFIG_PATH) not found, creating." "INFO" $log_file
            mkdir $CONFIG_PATH
        fi
    else
        std_logger "[INFO]: Directory CONFIG_ROOT ($CONFIG_ROOT) not found, use alternate."
        if [ ! -d $CONFIG_PATH_ALT ]; then
            std_message "Directory CONFIG_PATH_ALT ($CONFIG_PATH_ALT) not found, creating." "INFO" $log_file
            mkdir $CONFIG_PATH_ALT
        fi
        CONFIG_PATH=$CONFIG_PATH_ALT
    fi
    #
    # <-- end function ec2cli_precheck -->
    #
}

function repo_context(){
    ## determines if installer is executed from within repo on local fs ##
    if [ $(echo "$(git rev-parse --show-toplevel 2>/dev/null)" | grep ec2cli) ]; then
        # installer run from within the current git repo
        return 0
    elif [ -d ec2cli ]; then
        cd ec2cli
        return 0
    else
        return 1
    fi
}

#
# --- main ---------------------------------------------------------------------
#

precheck

# download ec2cli
$clear
std_message "START: The installer will install ${title}ec2cli${reset} to the current
    \tdirectory where the installer is located." "INFO" $log_file
echo -e "\n\n"
read -p "  Is this ok? [quit] " choice
if [ -z $choice ] || [ "$choice" = "q" ]; then
    exit 0
fi

# proceed with install
std_message "Install proceeding.  Downloading files... " "INFO" $log_file

# clone repo
if ! repo_context; then
    $git clone $repo_url
    cd $PROJECT
fi

EC2_REPO=$(pwd .)
profile=''

std_message "Locating local bash profile..." "INFO" $log_file

if [ -f $HOME/.bashrc ]; then
    std_message "Found .bashrc" INFO
    profile="$HOME/.bashrc"

elif [ -f $HOME/.bash_profile ]; then
    std_message "Found .bash_profile" INFO
    profile="$HOME/.bash_profile"

else
    std_message "Could not find either a .bashrc or .bash_profile.  Creating .bashrc." "INFO" $log_file
    read -p "  Is this ok? [quit] " choice
    if [ -z $choice ] || [ "$choice" = "y" ]; then
        exit 0
    fi
    profile="$HOME/.bashrc"
    touch $profile
fi


# --- update local profile -----------------------------------------------------


if [ ! "$(grep 'ec2cli installer' $profile)" ]; then
    echo "# inserted by ec2cli installer" >> $profile
fi

# EC2_REPO
if [ ! "$(echo $EC2_REPO)" ]; then
     echo "export EC2_REPO=$EC2_REPO" >> $profile
fi

# path update
if [ ! "$(echo $PATH | grep ec2cli)" ]; then
    echo "export PATH=$PATH:$EC2_REPO" >> $profile
fi

# ssh_key location
if [ ! "$(echo $SSH_KEYS)" ]; then
    std_message "${title}ec2cli${reset} needs the directory where ssh public keys (.pem files) for ec2 instances." "INFO"
    read -p "  Please enter the directory location: [.]: " choice

    if [ -z $choice ]; then
        SSH_KEYS=$EC2_REPO
    else
        SSH_KEYS=$choice
    fi
    echo "export SSH_KEYS=$SSH_KEYS" >> $profile
else
    std_message "Skipping configuration of SSH_KEYS env variable; found in $profile" "INFO" $log_file
fi

std_message "${title}ec2cli${reset} Installer Complete. Installer log located at $installer_log." "INFO" $log_file
std_message "End.\n" "INFO"
source $profile
exit 0
