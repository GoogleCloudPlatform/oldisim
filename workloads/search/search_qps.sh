#!/bin/bash

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-t experiment time] [-s scan arguments] -- driver command
Finds the maximum QPS that satisfies a latency target.
Algorithm to find QPS for latency target adapted from Jacob Leverich\'s
mutilate (EuroSys \'14) [https://github.com/leverich/mutilate]

    -h          display this help and exit
    -t          amount of time to run each experiment in seconds
    -s          metric:target (in msec). Example: 99p:5.01. Allowable metrics
                are avg, 50p, 90p, 95p, 99p, 99.9p
EOF
}

# Run the load test and pull results
# run_loadtest output_qps output_latency [target qps]
run_loadtest() {
  local __output_qps=$1
  local __output_latency=$2
  local qps_arg=""

  # check for optional QPS argument
  if [ $# -eq 3 ]; then
    qps_arg="--qps=$3"
  fi

  # run the command, saving result to tmpfile
  local tmp_file=$(tempfile)
  $command $qps_arg &>$tmp_file &
  LOADTEST_PID=$!

  # wait for time
  sleep $experiment_time

  # send SIGINT to the command
  kill -SIGINT $LOADTEST_PID

  # wait for results to show up and queries to drain
  sleep 5

  # check file for QPS
  if grep -q "#: [0-9]\+.\([0-9]\+\)\? QPS" $tmp_file; then
    local qps=$(cat $tmp_file | grep QPS | awk '{print $2}')
  else
    echo "Could not find QPS in loadtest output" >&2
    echo "Contents of loadtest output:" >&2
    cat $tmp_file >&2
    exit 1;
  fi

  if grep -q "$latency_type: [0-9]\+.\([0-9]\+\)\? ms" $tmp_file; then
    local latency=$(cat $tmp_file | grep $latency_type | awk '{print $2}')
  else
    echo "Could not find latency in loadtest output" >&2
    echo "Contents of loadtest output:" >&2
    cat $tmp_file >&2
    exit 1;
  fi

  eval $__output_qps="'$qps'"
  eval $__output_latency="'$latency'"
}

# Initialize our own variables:
experiment_time=30
latency_type=""
latency_target=""

OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "ht:s:" opt; do
  case "$opt" in
    h)
      show_help
      exit 0
      ;;
    t)
      experiment_time=$OPTARG
      ;;
    s)
      latency_type=$(echo $OPTARG | tr ':' ' ' | awk '{print $1}')
      latency_target=$(echo $OPTARG | tr ':' ' ' | awk '{print $2}')
      ;;
    '?')
      show_help >&2
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

# remaining argument is loadtest command
command=$@

# make sure latency_type and latency_target are specified
if [[ $latency_type = "" ]] || [[ $latency_target = "" ]]; then
  echo 'error: -s metric:target must be specified' >&2; exit 1
fi

# make sure latency_type is a recognized type
if [[ $latency_type != "avg" ]] && [[ $latency_type != "50p" ]] && \
   [[ $latency_type != "90p" ]] && [[ $latency_type != "95p" ]] && \
   [[ $latency_type != "99p" ]] && [[ $latency_type != "99.9p" ]]; then
  echo 'error: metric must be avg|50p|90p|95p|99p|99.9p' >&2; exit 1
fi

# check to make sure experiment_time is an integer
if ! [[ $experiment_time =~ ^[0-9]+$ ]] ; then
 echo "error: experiment_time ($experiment_time) is not an integer" >&2; exit 1
fi

# check to make sure latency_target is a float
if ! [[ $latency_target =~ ^[0-9]+([.][0-9]+)?$ ]] ; then
 echo "error: latency_target ($latency_target) is not a float" >&2; exit 1
fi

# check to make sure first argument is a binary
type $1 >/dev/null 2>&1 || { echo >&2 "The loadtest command does not appear to invoke a binary."; exit 1; }

# tell the user what we are doing
echo "Searching for QPS where $latency_type latency <= $latency_target msec"

# find peak QPS
run_loadtest peak_qps measured_latency
printf "peak qps = %.0f, latency = %.1f\n" $peak_qps $measured_latency

# if latency is too high, try doing binary search
latency_good=$(echo "$measured_latency <= $latency_target" | bc)
if [[ $latency_good -eq 0 ]]; then
  high_qps=$peak_qps
  low_qps=1
  cur_qps=$peak_qps

  # binary search to approx. location
  loop_cond=$(echo "(($high_qps > $low_qps * 1.02) && $cur_qps > ($peak_qps * .1))" | bc)
  while [[ $loop_cond -eq 1 ]]; do
    # calculate new QPS
    cur_qps=$(echo "scale=5; ($high_qps + $low_qps) / 2" | bc)

    # run experiment and report result
    run_loadtest measured_qps measured_latency $cur_qps
    printf "requested_qps = %.0f, measured_qps = %.0f, latency = %.1f\n" $cur_qps $measured_qps $measured_latency

    # set new QPS ranges
    latency_good=$(echo "$measured_latency <= $latency_target" | bc)
    if [[ $latency_good -eq 0 ]]; then
      high_qps=$cur_qps
    else
      low_qps=$cur_qps
    fi

    loop_cond=$(echo "(($high_qps > $low_qps * 1.02) && $cur_qps > ($peak_qps * .1))" | bc)
  done

  # do fine tuning
  loop_cond=$(echo "($measured_latency > $latency_target && $cur_qps > ($peak_qps * .1) && $cur_qps > ($low_qps * 0.90))" | bc)
  while [[ $loop_cond -eq 1 ]]; do
    cur_qps=$(echo "scale=5; $cur_qps * 98 / 100" | bc)

    # run experiment and report result
    run_loadtest measured_qps measured_latency $cur_qps
    printf "requested_qps = %.0f, measured_qps = %.0f, latency = %.1f\n" $cur_qps $measured_qps $measured_latency

    loop_cond=$(echo "($measured_latency > $latency_target && $cur_qps > ($peak_qps * .1) && $cur_qps > ($low_qps * 0.90))" | bc)
  done
fi

# End of file
