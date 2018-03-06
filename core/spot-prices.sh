#!/bin/bash
#
#_________________________________________________________________________
#                                                                         |
#                                                                         |
#  Author:   Blake Huber                                                  |
#  Purpose:  QuickView of current EC2 spot prices on market               |
#  Name:     ec2-qv-spot-prices.sh                                        |
#  Location: $EC2_REPO                                                    |
#  Requires: awscli, awk, bash, writable dir                              |
#  Environment Variables (required, global):                              |
#       EC2_BASE                                                          |
#       EC2_HOME                                                          |
#       AWS_ACCESS_KEY                                                    |
#       AWS_SECRET_KEY                                                    |
#       AWS_DEFAULT_REGION                                                |
#  User:     $USER                                                        |
#  Out:      CLI                                                          |
#  Error:    stderr                                                       |
#  Log:      N/A                                                          |
#                                                                         |
#_________________________________________________________________________|

# Future Enhancements:
#	- InstanceType Array needs auto build via readin of current valid InstanceTypes
#       - Add summary statement displaying region selected, OS, and Instance \
# 	  types for which pricing displayed [single instance pricing only]
#	- Description of InstanceType Chosen to be displayed when only 1 instance type is chosen
#	- Error handling for user data when chosing instance type
#	- After chosing region, display Human Readable region desc instead \
#	  of region code
#

# set vars
NOW=$(date)
pkg_path=$(cd $(dirname $0); pwd -P)
E_BADSHELL=7              # exit code if incorrect shell detected
E_BADARG=8                    # exit code if bad input parameter
REGION=$AWS_DEFAULT_REGION    # set region from global env var


# source config file location
config_dir=$(cat $pkg_path/pkgconfig.json | jq -r .config_dir)

# source colors library
source $pkg_path/colors.sh

# source standard functions
source $pkg_path/std_functions.sh


#
# functions  ------------------------------------------------------------------
#


function precheck(){
    ## validates presence of instance types file, gen if not  ##
    if [ ! -e $config_dir/types.ec2 ]; then
        bash $pkg_path/instancetypes.sh
    else
        # check age of file, if older than x age, renew it
        bash $pkg_path/instancetypes.sh
    fi
}


function load_arrays(){
    ## loads array for each instance type family ##
    declare -a C_TYPE
    declare -a D_TYPE
    declare -a F_TYPE
    declare -a G_TYPE
    declare -a I_TYPE
    declare -a H_TYPE
    declare -a M_TYPE
    declare -a P_TYPE
    declare -a R_TYPE
    declare -a T_TYPE
    declare -a X_TYPE
    declare -a MISC_TYPE
    #
    C_TYPE=$(grep c[1-9].* $config_dir/types.ec2 | grep -v cc)
    D_TYPE=$(grep d[1-9].* $config_dir/types.ec2)
    F_TYPE=$(grep f[1-9].* $config_dir/types.ec2)
    G_TYPE=$(grep g[1-9].* $config_dir/types.ec2 | grep -v cg)
    H_TYPE=$(grep h[1-9].* $config_dir/types.ec2)
    I_TYPE=$(grep i[1-9].* $config_dir/types.ec2)
    M_TYPE=$(grep m[1-9].* $config_dir/types.ec2)
    P_TYPE=$(grep p[1-9].* $config_dir/types.ec2)
    R_TYPE=$(grep r[1-9].* $config_dir/types.ec2 | grep -v cr)
    T_TYPE=$(grep t[1-9].* $config_dir/types.ec2)
    X_TYPE=$(grep x[1-9].* $config_dir/types.ec2)

}


# < -- Start -->

echo -e "\n"

# var definition
# REGIONS[] :: List of AWS Global Regions, Array
# REGIONCODE :: Region selected by user
# LOCATION :: Location description of region selected by user
# OS[]	::  Operating System choices, Array
# TYPE :: Operating System selected by user from OS[] array choices
# SIZE[] :: InstanceTypes, Array
# CHOICE :: tmp var holding choice selected by user

# set fs pointer to writeable temp location in memory
if [ "$(df /run | awk '{print $1, $6}' | grep tmpfs 2>/dev/null)" ]
then
        TMPDIR="/dev/shm"
        cd $TMPDIR
else
        TMPDIR="/tmp"
        cd $TMPDIR
fi

#
# Validate Shell  ------------------------------------------------------------
#

# test default shell, fail if not bash
if [ ! -n "$BASH" ]
  then
        # shell other than bash
        echo "\nDefault shell appears to be something other than bash. \
		Please rerun with bash. Exiting. Code $E_BADSHELL\n"
        exit $E_BADSHELL
fi

#
#  choose region  ------------------------------------------------------------
#

# collect list of all current AWS Regions globally:
aws ec2 describe-regions --output json > .regions.json
ARR_REGIONS=( $(jq -r .Regions[].RegionName .regions.json) )
MAXCT=${#ARR_REGIONS[*]}    # array max length

# output choices
i=1
for region in ${ARR_REGIONS[@]}; do
    # set region location description
    case "$region" in
        eu-west-1)
            LOCATION="Europe (Ireland)"
            ;;
        eu-west-2)
            LOCATION="Europe (London, UK)"
            ;;
        eu-west-3)
                LOCATION="Europe (Paris, France)"
                ;;
        eu-central-1)
            LOCATION="Europe (Frankfurt, Germany)"
            ;;
        sa-east-1)
            LOCATION="South America (Sao Paulo, Brazil)"
            ;;
        us-east-1)
            LOCATION="United States (N. Virgina)"
            ;;
        us-east-2)
            LOCATION="United States (Ohio)"
            ;;
        us-west-1)
            LOCATION="United States (N. California)"
            ;;
        us-west-2)
            LOCATION="United States (Oregon)"
            ;;
        ap-northeast-1)
            LOCATION="Asia Pacific (Tokyo, Japan)"
	        ;;
		ap-northeast-2)
	        LOCATION="Asia Pacific (Seoul, Korea)"
            ;;
	    ap-south-1)
	        LOCATION="Asia Pacific (Mumbai, India)"
	        ;;
        ap-southeast-1)
            LOCATION="Asia Pacific (Singapore)"
            ;;
        ap-southeast-2)
            LOCATION="Asia Pacific (Sydney, Austrailia)"
            ;;
        ca-central-1)
            LOCATION="Canada (Central)"
            ;;
        *)
            LOCATION="New Region"
            ;;
    esac
    echo ""\($i\): "$region" $LOCATION"" >> .arrayoutput.tmp
    i=$(( i+1 ))
done

# print header
total_width="60"
echo ""
echo -e "${title}     EC2 SPOT MARKET\n" | indent15
echo -e "${bold}${orange}Amazon Web Services ${white}Regions Worldwide${bodytext}\n" | indent10

print_header "\nRegionCode Location" $total_width .header.tmp

# print choices
awk '{printf "%-23s %-2s %-30s\n", $1, $2, $3}' .header.tmp | indent02
echo -e "\n"
awk '{printf "%-5s %-19s %-2s %-2s %-2s %-2s %-2s \n\n", $1, $2, $3, $4, $5, $6, $7}' .arrayoutput.tmp | indent02
print_separator $total_width
# clean up
rm ./.regions.json ./.header.tmp ./.arrayoutput.tmp


# enter loop to validate range and type of user entry
VALID=0
while [ $VALID -eq 0 ]; do
	# read instance choice in from user
	echo ""
	read -p "  ${title}Select Region${bodytext} [$AWS_DEFAULT_REGION], or press q to quit > " CHOICE
	echo ""
	if [ -z "$CHOICE" ]; then
        # CHOICE is blank, default region chosen
	    # use the aws_default_region env variable
        REGION=$AWS_DEFAULT_REGION
      	echo -e "  You Selected: "${yellow}$REGION${bodytext}"\n"
		VALID=1   # exit loop
	elif [ "$CHOICE" = "q" ]; then
        exit 0
    elif [[ ! "$CHOICE" =~ ^[0-9]+$ ]]; then
        # CHOICE is a value, check type and range
        # contains chars
        echo -e "Your entry must be an integer between 0 and $(( $MAXCT-1 )) or hit return."
	else
        correct=$(( $CHOICE - 1))
        if [[ $correct -ge 0 ]] && [[ $correct -lt $(( $MAXCT )) ]]; then
            # valid range, reset the aws default region to user choice momentarily
	        REGION=${ARR_REGIONS[$correct]}
	        echo -e "  You Selected: "$REGION"\n"
            VALID=1   # exit loop
        else
            # out of range
            echo -e "Your entry must be an integer between 0 and $(( $MAXCT-1 )) or hit return."
        fi
	fi
done

print_separator $total_width
#
###  choose Operating System ##############################################
#

OS[0]="Linux/UNIX"
OS[1]="SUSE Linux"
OS[2]="Windows"
MAXCT=${#OS[*]}

# output choices
i=0
while (( i < $MAXCT ))
do
        echo "($i): ""${OS[$i]}"  >> .type.tmp
        i=$(( $i+1 ))
done

# print choices
echo -e "${BOLD}Operating Systems Available:${UNBOLD}\n" | indent02
awk -F "  " '{ printf "%-4s %-20s \n", $1, $2}' .type.tmp | indent02

# get user input while checking type and range
VALID=0    # set loop break

while [ $VALID -eq 0 ]
do
	# read instance choice in from user
	echo ""
	read -p "  Enter OS type [Linux/UNIX]: " CHOICE
	echo ""

	if [[ -n ${CHOICE//[0-$(( $MAXCT-1 ))]/} ]]
	then
		echo "  You must enter an integer number between 0 and $(( $MAXCT-1 ))."
	else
		VALID=1
	fi
done

if [ -z "$CHOICE" ]
then
        # CHOICE is blank, default chosen
	CHOICE=0
fi

# set type
TYPE=${OS[$CHOICE]}
echo -e "  You Selected: "${yellow}$TYPE${bodytext}"\n"

total_width="110"
print_separator $total_width
# clean up
rm ./.type.tmp

#
###  choose Instance size #################################################
#

# build InstanceType array
load_arrays

# set max count based on # of entries in the previous section
MAXCT=${#M_TYPE[*]}

set counters
i=1
c=0; f=0; g=0; m=0; I=0
j=$(( $i + 10 ))
j=$(( $i + 10 ))
# output choices
while (( i < $MAXCT ))
do
    echo "($c): ""${C_TYPE[$i]}" "($f): ""${F_TYPE[$i]}" "($g): ""${G_TYPE[$i]}" "($I): ""${I_TYPE[$i]}" \
        "($m): ""${M_TYPE[$i]}" >> data.output
    i=$(( $i+1 ))
done

# print output
echo -e "\n${BOLD}Choose from the following $TYPE EC2 instance types:\n${UNBOLD}" | indent02
echo -e "General Purpose  ""Compute Opt(Gen3)  ""Memory Optimized  ""Storage Optimized  " "Compute Opt(Gen4)" > .header.tmp
echo -e "---------------  ""----------------  ""----------------  ""-----------------   ""-----------------" >> .header.tmp
awk -F "  " '{ printf "%-20s %-20s %-20s %-20s %-20s \n", $1, $2, $3, $4, $5}' .header.tmp | indent02
awk '{ printf "%-4s %-15s %-4s %-15s %-4s %-14s %-4s %-15s %-4s %-15s \n", \
	$1, $2, $3, $4, $5, $6, $7, $8, $9, $10}' data.output | indent02
echo ""

# clean up
rm ./data.output
rm ./.header.tmp

# read instance choice in from user
echo ""
read -p "  Enter Instance size # or hit return for all spot prices [all]: " CHOICE
echo ""

print_separator $total_width
# assign choice

if [ -z "$CHOICE" ]
then
        # CHOICE is blank, default chosen. Show all spot prices
	# for instance types avail in region chosen

	# print title header
	echo -e "\n"
        echo -e "  ${BOLD}Spot pricing for all EC2 instance types${UNBOLD} : $AWS_DEFAULT_REGION:\n"


	# Place Future summary here for:  Region, OS, Instances (all instances)

	# Format prices in ascending order based on RegionCode & OS Type:
	case "$TYPE" in

		# Amazon Linux OS Formatting
		"Linux/UNIX")
        	case "$REGION" in
	                eu-central-1)
        	        # special formatting for long RegionCodes
			#
			# print column header
			echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
			echo -e "-------------  ""----------  ""----------  ""--------   " >> .header.tmp
			awk -F " " '{ printf "%-20s %-15s %-15s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

                	aws ec2 describe-spot-price-history  \
                          --region $REGION \
                        	--start-time "$NOW" \
	                        --product-description "$TYPE" \
        	                --output text | \
                	        sort -k +5n > .body.tmp     # Cut 1st col, sort by 5th col
			awk -F " " '{printf "%-20s %-20s %-15s %-15s %-10s \n", $1, $2, $3, $4, $5}' .body.tmp | cut -c 22-84 | indent02
	                  ;;

                        ap-*)
			# output formatting ap-northeast-1, ap-southeast-1, or ap-southeast-2
                        #
                        # print column header
                        echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
                        echo -e "---------------  ""----------  ""----------  ""--------   " >> .header.tmp
                        awk -F " " '{ printf "%-20s %-15s %-15s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

                        aws ec2 describe-spot-price-history  \
                                --region $REGION \
                                --start-time "$NOW" \
                                --product-description "$TYPE" \
                                --output text | \
                                sort -k +5n > .body.tmp      # Cut 1st col, sort by 5th col
                        awk -F " " '{printf "%-20s %-20s %-15s %-15s %-10s \n", $1, $2, $3, $4, $5}' .body.tmp | cut -c 22-84 | indent02
                          ;;

                	*)
	                # all other RegionCodes, use std default formatting
			#
		        # print column header
		        echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
		        echo -e "----------  ""----------  ""----------  ""--------   " >> .header.tmp
		        awk -F " " '{ printf "%-15s %-15s %-15s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

			aws ec2 describe-spot-price-history  \
                          --region $REGION \
                	        --start-time "$NOW" \
                        	--product-description "$TYPE" \
	                        --output text | \
        	                sort -k +5n > .body.tmp
			awk -F " " '{printf "%-20s %-15s %-15s %-15s %-10s \n", $1, $2, $3, $4, $5}' .body.tmp | cut -c 22-84 | indent02
			;;
		esac
		;;

		# SUSE Linux OS Formatting
		"SUSE Linux")
                case "$REGION" in       # output formatting by RegionCode
                        eu-central-1)
                        # output formatting Frankfurt, Germany
                        #
                        # print column header
                        echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
                        echo -e "-------------  ""----------  ""----------  ""--------   " >> .header.tmp
                        awk -F " " '{ printf "%-20s %-15s %-15s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

                        aws ec2 describe-spot-price-history  \
                                --region $REGION \
                                --start-time "$NOW" \
                                --product-description "$TYPE" \
                                --output text | \
                                sort -k +6n > .body.tmp      # Cut 1st col, sort by 4th col
                        awk -F " " '{printf "%-20s %-20s %-15s %-3s %-10s %-15s \n", $1, $2, $3, $4, $5, $6}' .body.tmp | cut -c 22-84 | indent02
                          ;;

			ap-*)
			# output formatting ap-northeast-1&2, ap-southeast-1&2
			#
			# print column header
			echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
			echo -e "---------------  ""----------  ""----------  ""--------   " >> .header.tmp
			awk -F " " '{ printf "%-20s %-15s %-15s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

                        aws ec2 describe-spot-price-history  \
                                --region $REGION \
                                --start-time "$NOW" \
                                --product-description "$TYPE" \
                                --output text | \
                                sort -k +6n > .body.tmp      # Cut 1st col, sort by 4th col
			awk -F " " '{printf "%-20s %-20s %-15s %-3s %-10s %-15s \n", $1, $2, $3, $4, $5, $6}' .body.tmp | cut -c 22-84 | indent02
                          ;;

                        *)
                        # all other RegionCodes, use std default formatting
			#
		        # print column header
		        echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
		        echo -e "----------  ""----------  ""----------  ""--------   " >> .header.tmp
		        awk -F " " '{ printf "%-15s %-15s %-15s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

                        aws ec2 describe-spot-price-history  \
                                --region $REGION \
                                --start-time "$NOW" \
                                --product-description "$TYPE" \
                                --output text | \
                                sort -k +6n > .body.tmp
			awk -F " " '{printf "%-20s %-15s %-15s %-3s %-10s %-15s \n", $1, $2, $3, $4, $5, $6}' .body.tmp | cut -c 22-84 | indent02
                        ;;
                esac
		;;

		# Windows OS Formatting
		"Windows")
            case "$REGION" in
                eu-central-1)
                    # print column header
                    echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
                    echo -e "-------------  ""----------  ""-------  ""--------   " >> .header.tmp
                    awk -F " " '{ printf "%-20s %-15s %-13s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

                    # special formatting for long RegionCodes
                    aws ec2 describe-spot-price-history  \
                            --region $REGION \
                            --start-time "$NOW" \
                            --product-description "$TYPE" \
                            --output text | \
                            sort -k +5n > .body.tmp     # Cut 1st col, sort by 4th col
                    awk -F " " '{printf "%-20s %-20s %-15s %-13s %-15s \n", $1, $2, $3, $4, $5}' .body.tmp | cut -c 22-84 | indent02
                      ;;

                ap-northeast-1 | ap-northeast-2)
                    # print column header
    	            echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
            	    echo -e "---------------  ""----------  ""-------  ""--------   " >> .header.tmp
                    awk -F " " '{ printf "%-20s %-15s %-13s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

		            # special formatting for long RegionCodes
                    aws ec2 describe-spot-price-history  \
                            --region $REGION \
                            --start-time "$NOW" \
                            --product-description "$TYPE" \
                            --output text | \
                            sort -k +5n > .body.tmp     # Cut 1st col, sort by 4th col
                    awk -F " " '{printf "%-20s %-20s %-15s %-13s %-15s \n", $1, $2, $3, $4, $5}' .body.tmp | cut -c 22-84 | indent02
                    ;;

                ap-southeast-1)
                        # print column header
                        echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
                        echo -e "---------------  ""----------  ""-------  ""--------   " >> .header.tmp
                        awk -F " " '{ printf "%-20s %-15s %-13s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

                        # special formatting for long RegionCodes
                        aws ec2 describe-spot-price-history  \
                                --region $REGION \
                                --start-time "$NOW" \
                                --product-description "$TYPE" \
                                --output text | \
                                sort -k +5n > .body.tmp     # Cut 1st col, sort by 4th col
	                    awk -F " " '{printf "%-20s %-20s %-15s %-13s %-15s \n", $1, $2, $3, $4, $5}' .body.tmp | cut -c 22-84 | indent02
                        ;;

                ap-southeast-2)
                        # print column header
                        echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
                        echo -e "---------------  ""----------  ""-------  ""--------   " >> .header.tmp
                        awk -F " " '{ printf "%-20s %-15s %-13s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02

                        # special formatting for long RegionCodes
                        aws ec2 describe-spot-price-history  \
                                --region $REGION \
                                --start-time "$NOW" \
                                --product-description "$TYPE" \
                                --output text | \
                                sort -k +5n > .body.tmp     # Cut 1st col, sort by 4th col
	                    awk -F " " '{printf "%-20s %-20s %-15s %-13s %-15s \n", $1, $2, $3, $4, $5}' .body.tmp | cut -c 22-84 | indent02
                        ;;

                *)
                    # ALL OTHER RegionCodes, use std default formatting
			            #
                    # print column header
                    echo -e "RegionCode  ""Instance  ""OperSys  ""Price/hr  " > .header.tmp
                    echo -e "----------  ""----------  ""-------  ""--------   " >> .header.tmp
                    awk -F " " '{ printf "%-15s %-15s %-13s %-20s \n", $1, $2, $3, $4}' .header.tmp | indent02
                    aws ec2 describe-spot-price-history  \
                            --region $REGION \
                            --start-time "$NOW" \
                            --product-description "$TYPE" \
                            --output text | \
                            sort -k +5n > .body.tmp     # Cut 1st col, sort by 4th col
               	    awk -F " " '{printf "%-15s %-15s %-15s %-13s %-15s \n", $1, $2, $3, $4, $5}' .body.tmp | cut -c 18-80 | indent02
                    ;;
		esac
		  ;;

	esac

        # clean up, display all section complete
        rm ./.header.tmp
	rm ./.body.tmp

else
	# display current spot prices only for specific instance type in region chosen
	aws ec2 describe-spot-price-history  \
    --region $REGION \
		--start-time "$NOW" \
		--product-description "$TYPE" \
		--instance- ${SIZE[$CHOICE]} \
		--output table
fi

# <-- end -->

# line feed
echo -e "\n"

exit 0
