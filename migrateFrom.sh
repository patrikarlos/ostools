#!/bin/bash

## Assumes that you have openstack environment variables set.
#Username of ssh user
OSSSHUSER="ubuntu"
#force dns domain, issue with multiple domains, dhcp, etc... Should be empty, or replaced with your prefered domain. 
#myDomain=""
myDomain=".maas"

details=0
human=0 
while getopts dvh name
do
    case $name in
	d) details=1;;
	v) human=1;;
	?) printf "Usage %s: [-d] [-v] sourceNode \n" $0;echo -e "\t-d show details";echo -e "\t-v verbose"
	exit 2;;
    esac
done

shift $((OPTIND - 1))  



sourceNode=$1
if (( $human == 1 )); then 
    echo "Moving from $sourceNode, details = $details "
fi





sourceSpecs_cpu=$(mktemp)
sourceSpecs_cpu2=$(mktemp)

## Pending additonal requirements (PAR)
#sourceSpecs_mem=$(mktemp)
#sourceSpecs_io=$(mktemp)

nodeSpecs_cpu=$(mktemp)




tmpfile1=$(mktemp)
tmpfile2=$(mktemp)

ssh -oStrictHostKeyChecking=no $OSSSHUSER@$sourceNode$myDomain 'cat /proc/cpuinfo' > $sourceSpecs_cpu 2> /dev/null
## PAR
#ssh ubuntu@$sourceNode 'cat /proc/meminfo' > $sourceSpecs_mem
#ssh ubuntu@$sourceNode 'sudo lshw -c disk' > $sourceSpecs_io

perfmatchARRAY=()
coverdmatchARRAY=()
unknownARRAY=()

theSourceFlags=$(cat $sourceSpecs_cpu | grep flags | sed 's/flags[\tab]\{1,\}://g' | uniq | sort | uniq | sed 's/ /\n/g' | sort | uniq | sort ) 
echo "$theSourceFlags" > $sourceSpecs_cpu2

for node in $(openstack compute service list | grep nova-compute | grep ' up ' | awk '{print $6}'); do
    if (( $human == 1 )); then 
       echo -n  "Checking $node,"
   fi
    nodeSpecs_cpu2=$(mktemp)
    ssh -oStrictHostKeyChecking=no $OSSSHUSER@$node$myDomain 'cat /proc/cpuinfo' > $nodeSpecs_cpu 2> /dev/null

    theNodeFlags=$(cat $nodeSpecs_cpu | grep flags | sed 's/flags[\tab]\{1,\}://g' | uniq | sort | uniq | sed 's/ /\n/g'| sort | uniq | sort )
    echo "$theNodeFlags" > $nodeSpecs_cpu2

    theDifference=$(diff <(echo $theSourceFlags) <(echo $theNodeFlags))
    noDiff=$(echo "$theDifference" | wc -w )

    if (( $noDiff == 0 )); then
	if (( $human == 1 )); then 
	    echo " it is a perfect match."
	fi
	perfmatchARRAY+=($node) 
    else
	missingFlags=$(comm -23 $sourceSpecs_cpu2 $nodeSpecs_cpu2 | wc -l )
	commonFlags=$(comm -12 $sourceSpecs_cpu2 $nodeSpecs_cpu2 | wc -l )
	if (( $details == 1 )); then
	    echo -n " there are $commonFlags between source and node, but source has $missingFlags flag(s) that the node is missing. "
	fi

	if (( $missingFlags == 0 )); then
	    coverdmatchARRAY+=($node)
	    if (( $human == 1 )); then
		echo "."
	    fi
	    
	else
	    if (( $human == 1 )); then
		echo ""
	    fi
	    if (( $details == 1 )); then 
		echo "[Need] Implement comparision between CPU flags."
		unknownARRAY+=($node)
		sourceCPU=$(cat $sourceSpecs_cpu | grep name | uniq | sed 's/model name//g' | tr -d ':' )
		nodeCPU=$(cat $nodeSpecs_cpu | grep name | uniq | sed 's/model name//g'  | tr -d ':') 
		echo "Source CPU : $sourceCPU vs  $nodeCPU Node "
	    
		##Things will be complicated. 
		#	    comm -23 $sourceSpecs_cpu2 $nodeSpecs_cpu2 > $tmpfile1
		#	    comm -13 $sourceSpecs_cpu2 $nodeSpecs_cpu2 > $tmpfile2
		#	    echo "Are these compatible?"
		#	    diff -y $tmpfile1 $tmpfile2
		echo "Node = $nodeSpecs_cpu $nodeSpecs_cpu2 "
		echo "Source = $sourceSpecs_cpu $sourceSpecs_cpu2"
	    fi
	    
	fi
    fi
done

if (( $human == 1 )); then
    echo "*****************************"
    echo "To Migrate from $sourceNode, the following nodes are "
    echo "perfect match = ${perfmatchARRAY[*]}"
    echo "covered match = ${coverdmatchARRAY[*]}"
    echo  "unknown = ${unknownARRAY[*]}"
else
    echo "perfect ${perfmatchARRAY[*]}"
    echo "covered  ${coverdmatchARRAY[*]}"
    echo "unknown ${unknownARRAY[*]}"
fi
