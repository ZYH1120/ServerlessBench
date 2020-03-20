#!/bin/bash
source eval-config
PRINTLOG=false
WARMUPONLY=false
RUNONLY=false
while getopts "r:m:t:w:lWR" OPT; do
    case $OPT in
    # Mode: cold or warm.
    r)
        RESULT=$OPTARG
        ;;
    m)
        MODE=$OPTARG
        if [[ $MODE != 'cold' && $MODE != 'warm' ]] ;then
            echo "usage: "
            echo "./single-code_warm -m <mode> -t <loop times> -w <warm ups>"
            echo 'mode: warm, cold'
            exit
        fi
        ;;
    
    # The loop time
    t)
        TIMES=$OPTARG
        expr $TIMES + 0 &>/dev/null
        if [[ $? != 0 ]] || [[ $TIMES -lt 1 ]]; then
            echo "Error: loop times must be a positive integer"
            exit
        fi
        ;;
    
    # The warm up times
    w)
        WARMUP=$OPTARG
        expr $WARMUP + 0 &>/dev/null
        if [[ $? != 0 ]] || [[ $WARMUP -lt 1 ]]; then
            echo "Error: warm up times must be a positive integer"
            exit
        fi
        ;;

    # Output the results to the log with this argument.
    l)
        PRINTLOG=true
        LOGFILE=$ACTIONNAME-$MODE.csv
        ;;

    # "Warm up only" with this argument: warm up and then exit with no output.
    W)
        if [[ $RUNONLY = true || $MODE = "cold" ]]; then
            echo "Error: contradictory arguments"
            exit
        fi
        echo "Warm up only mode."
        WARMUPONLY=true
        ;;
    
    # "Run only" with this argument: invoke the first action without warm up. Paused containers are needed.
    R)
        if [[ $WARMUPONLY = true ]]; then
            echo "Error: contradictory arguments"
            exit
        fi
        # If there's no paused container, the mode should not be supported
        if [[ -z `docker ps | grep $CONTAINERNAME | awk {'print $1'}` ]];then
            echo "Error: could not find paused containers of the action"
            exit
        fi
        echo "Run only mode"
        RUNONLY=true
        WARMUP=0
        ;;
    ?)
        echo "unknown arguments"
    esac
done

if [[ -z $MODE ]];then
    echo "default mode: warm"
    MODE="warm"
fi

if [[ -z $TIMES && $WARMUPONLY = false ]]; then
    if [ $MODE = "warm" ];then
        echo "default warm loop times: 10"
        TIMES=10
    else
        echo "default cold loop times: 3"
        TIMES=3
    fi
fi

if [[ $MODE = "warm" ]] && [[ -z $WARMUP ]] && [[ $RUNONLY = false ]]; then
    echo "default warm up times: 1"
    WARMUP=1
fi

# mode = warm: kill all the running containers and then warm up
if [[ $MODE = "warm" && $RUNONLY = false ]]; then
    echo "Warm up.."
    if [[ -n `docker ps | grep $CONTAINERNAME | awk {'print $1'}` ]];then
        echo 'Stop the running container..'
        docker stop `docker ps | grep $CONTAINERNAME | awk {'print $1'}` > /dev/null 2>&1
    fi
    for i in $(seq 1 $WARMUP)
    do
        echo "The $i-th warmup..."
        wsk -i action invoke $ACTIONNAME --blocking --result $PARAMS > /dev/null
    done
    echo "Warm up complete"
    if [[ $WARMUPONLY = true ]]; then
        echo "No real action is needed."
        exit
    fi
fi


if [[ $PRINTLOG = true && ! -e $LOGFILE ]]; then
    echo logfile:$LOGFILE
    echo "invokeTime,endTime" > $LOGFILE
fi

LATENCYSUM=0

for i in $(seq 1 $TIMES)
do
    if [[ $MODE = 'cold' ]]; then
        echo 'Stop the running container..'
        docker stop `docker ps | grep $CONTAINERNAME | awk {'print $1'}` > /dev/null 2>&1
    fi

    echo Measure $MODE start up time: no.$i
    
    invokeTime=`date +%s%3N`
    times=`wsk -i action invoke $ACTIONNAME --blocking --result $PARAMS`
    checkresult=`echo $times | jq -r ."result"`
    expr $checkresult + 0 &> /dev/null    
    if [[ $? != 0 ]]; then
        echo "Activation error: timeout or something else"
        continue
    fi
    endTime=`date +%s%3N`
    echo "invokeTime: $invokeTime, endTime: $endTime" 

    latency=`expr $endTime - $invokeTime`
    LATENCYSUM=`expr $latency + $LATENCYSUM`
    # The array starts from array[1], not array[0]!
    LATENCIES[$i]=$latency

    if [[ $PRINTLOG = true ]];then
        echo "$invokeTime,$endTime" >> $LOGFILE
    fi
done

# Sort the latencies
for((i=0; i<$TIMES+1; i++)){
  for((j=i+1; j<$TIMES+1; j++)){
    if [[ ${LATENCIES[i]} -gt ${LATENCIES[j]} ]]
    then
      temp=${LATENCIES[i]}
      LATENCIES[i]=${LATENCIES[j]}
      LATENCIES[j]=$temp
    fi
  }
}

echo "------------------ result ---------------------"
_50platency=${LATENCIES[`echo "$TIMES * 0.5"| bc | awk '{print int($0)}'`]}
_75platency=${LATENCIES[`echo "$TIMES * 0.75"| bc | awk '{print int($0)}'`]}
_90platency=${LATENCIES[`echo "$TIMES * 0.90"| bc | awk '{print int($0)}'`]}
_95platency=${LATENCIES[`echo "$TIMES * 0.95"| bc | awk '{print int($0)}'`]}
_99platency=${LATENCIES[`echo "$TIMES * 0.99"| bc | awk '{print int($0)}'`]}

echo "Latency (ms):"
echo -e "Avg\t50%\t75%\t90%\t95%\t99%\t"
echo -e "`expr $LATENCYSUM / $TIMES`\t$_50platency\t$_75platency\t$_90platency\t$_95platency\t$_99platency\t"

if [ ! -z $RESULT ]; then
    echo -e "\n\n------------------ (single)result ---------------------\n" >> $RESULT
    echo "mode: $MODE, loop_times: $TIMES, warmup_times: $WARMUP" >> $RESULT
    _50platency=${LATENCIES[`echo "$TIMES * 0.5"| bc | awk '{print int($0)}'`]} 
    _75platency=${LATENCIES[`echo "$TIMES * 0.75"| bc | awk '{print int($0)}'`]} 
    _90platency=${LATENCIES[`echo "$TIMES * 0.90"| bc | awk '{print int($0)}'`]} 
    _95platency=${LATENCIES[`echo "$TIMES * 0.95"| bc | awk '{print int($0)}'`]} 
    _99platency=${LATENCIES[`echo "$TIMES * 0.99"| bc | awk '{print int($0)}'`]}

    echo "Latency (ms):" >> $RESULT
    echo -e "Avg\t50%\t75%\t90%\t95%\t99%\t" >> $RESULT
    echo -e "`expr $LATENCYSUM / $TIMES`\t$_50platency\t$_75platency\t$_90platency\t$_95platency\t$_99platency\t" >> $RESULT
fi

