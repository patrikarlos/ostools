#!/bin/bash

## Assumes that you have openstack environment variables set.
#Username of ssh user
OSSSHUSER="ubuntu"

sourceNode=$1
echo "Moving from $sourceNode"  




sourceSpecs_cpu=$(mktemp)
sourceSpecs_cpu2=$(mktemp)

## Pending additonal requirements (PAR)
#sourceSpecs_mem=$(mktemp)
#sourceSpecs_io=$(mktemp)

nodeSpecs_cpu=$(mktemp)




tmpfile1=$(mktemp)
tmpfile2=$(mktemp)

ssh -oStrictHostKeyChecking=no $OSSSHUSER@$sourceNode.maas 'cat /proc/cpuinfo' > $sourceSpecs_cpu 2> /dev/null
## PAR
#ssh ubuntu@$sourceNode 'cat /proc/meminfo' > $sourceSpecs_mem
#ssh ubuntu@$sourceNode 'sudo lshw -c disk' > $sourceSpecs_io

perfmatchARRAY=()
coverdmatchARRAY=()
unknownARRAY=()

theSourceFlags=$(cat $sourceSpecs_cpu | grep flags | sed 's/flags[\tab]\{1,\}://g' | uniq | sort | uniq | sed 's/ /\n/g' | sort | uniq | sort ) 
echo "$theSourceFlags" > $sourceSpecs_cpu2

for node in $(openstack compute service list | grep nova-compute | grep ' up ' | awk '{print $6}'); do
    echo -n  "Checking $node,"
    nodeSpecs_cpu2=$(mktemp)
    ssh -oStrictHostKeyChecking=no $OSSSHUSER@$node.maas 'cat /proc/cpuinfo' > $nodeSpecs_cpu 2> /dev/null

    theNodeFlags=$(cat $nodeSpecs_cpu | grep flags | sed 's/flags[\tab]\{1,\}://g' | uniq | sort | uniq | sed 's/ /\n/g'| sort | uniq | sort )
    echo "$theNodeFlags" > $nodeSpecs_cpu2

    theDifference=$(diff <(echo $theSourceFlags) <(echo $theNodeFlags))
    noDiff=$(echo "$theDifference" | wc -w )

    if (( $noDiff == 0 )); then
	echo " it is a perfect match."
	perfmatchARRAY+=($node) 
    else
	missingFlags=$(comm -23 $sourceSpecs_cpu2 $nodeSpecs_cpu2 | wc -l )
	commonFlags=$(comm -12 $sourceSpecs_cpu2 $nodeSpecs_cpu2 | wc -l )
	echo -n " there are $commonFlags between source and node, but source has $missingFlags flag(s) that the node is missing. "

	if (( $missingFlags == 0 )); then
	    coverdmatchARRAY+=($node)
	    echo "."
	else
	    echo ""
	    echo "[Need] Implement comparision between CPU flags."
	    unknownARRAY+=($node)
	    sourceCPU=$(cat $sourceSpecs_cpu | grep name | uniq)
	    nodeCPU=$(cat $nodeSpecs_cpu | grep name | uniq)
	    echo "Source CPU : $sourceCPU"
	    echo "  node CPU : $nodeCPU"
	    
##Things will be complicated. 
#	    comm -23 $sourceSpecs_cpu2 $nodeSpecs_cpu2 > $tmpfile1
#	    comm -13 $sourceSpecs_cpu2 $nodeSpecs_cpu2 > $tmpfile2
#	    echo "Are these compatible?"
#	    diff -y $tmpfile1 $tmpfile2
	fi
	
	echo "Node = $nodeSpecs_cpu $nodeSpecs_cpu2 "
	echo "Source = $sourceSpecs_cpu $sourceSpecs_cpu2"
    fi
done

echo "*****************************"
echo "To Migrate from $sourceNode. "
echo "perf = ${perfmatchARRAY[*]}"
echo "covered = ${coverdmatchARRAY[*]}"
echo  "unknown = ${unknownARRAY[*]}"
