#!/bin/bash

# A timer script to send an alert after a specified time
# Takes a time in the following format: xx:xx:xx or xxh xxm xxs
# For example: ./timer 5:24:30 or ./timer 5h 24m 30s

# Usage
usage() {
  echo "To specify a time: ./timer xx:xx:xx or ./timer xxh xxm xxs"
  echo "Press any key to pause or unpause"
  echo "Options:"
  echo "  --help: show options"
  echo "  -h|--hidden: no notifications"
  echo "  -q|--quiet: no output"
  echo "  -s|--stopwatch: stopwatch"
  echo "  -t|--time: alert at the specified time"
}

# Define flags
h="false"
q="false"
s="false"
t="false"

# Check for flags
while getopts "hqst-:" flags; do
  case "${flags}" in
    -)
      case "${OPTARG}" in
        help)
          usage
          exit 0
          ;;
        hidden)
          h="true"
          ;;
        quiet)
          q="true"
          ;;
        stopwatch)
          s="true"
          ;;
        time)
          t="true"
          ;;
        *)
          usage
          exit 1
          ;;
      esac
      ;;
    h)
      h="true"
      ;;
    q)
      q="true"
      ;;
    s)
      s="true"
      ;;
    t)
      t="true"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))"

# Stops processes on interrupt signal
stop() {
  if [[ -f "/tmp/timerIsPaused$$.txt" ]]; then
    rm -f "/tmp/timerIsPaused$$.txt"
  fi
  dunstify -h string:x-canonical-private-synchronous:"timer$$" "$@"
  exit 0
}

# Timer notifications
# Uses the same parameters as the dunstify command
# Click to pause or unpause timer
notifyTimer() {
  if [[ "$(echo "$(< "/tmp/timerIsPaused$$.txt")")"  == "true" ]]; then
    dunstify -t 0 -h string:x-canonical-private-synchronous:"timer$$" \
        "Timer (paused)" "$2"
  else
    dunstify -h string:x-canonical-private-synchronous:"timer$$" "$@"
  fi
  if [[ "$q" == "false" && "$2" != "⌛ Complete" ]]; then
    if [[ "$(echo "$(< "/tmp/timerIsPaused$$.txt")")"  == "true" ]]; then
      echo -n "Timer (paused): $2"
      echo -ne "\r"
    else
      echo -n "Time remaining: $2"
      echo -ne "\r"
    fi
  fi
}

# Stopwatch notifications
# Uses the same parameters as the dunstify command
# Click to pause or unpause stopwatch
notifyStopwatch() {
  if [[ "$(echo "$(< "/tmp/timerIsPaused$$.txt")")"  == "true" ]]; then
    dunstify -t 0 -h string:x-canonical-private-synchronous:"timer$$" \
        "Stopwatch (paused)" "$2"
  else
    dunstify -h string:x-canonical-private-synchronous:"timer$$" "$@"
  fi
  if [[ "$q" == "false" ]]; then
    if [[ "$(echo "$(< "/tmp/timerIsPaused$$.txt")")"  == "true" ]]; then
      echo -n "Stopwatch (paused): $2"
      echo -ne "\r"
    else
      echo -n "Time elapsed      : $2"
      echo -ne "\r"
    fi
  fi

}

# Converts miliseconds to days, hours, minutes, seconds, miliseconds
# Takes time in miliseconds and returns expanded time as formatted string
msConverter() {
  printf "%02dd %02dh %02dm %02ds %03dms\n" "$(("$1"/86400000))" \
      "$((("$1"/3600000)%24))" "$((("$1"/60000)%60))" "$((("$1"/1000)%60))" \
      "$(("$1"%1000))"
}

# Converts seconds to hours, minutes, seconds
# Takes time in seconds and returns expanded time as formatted string
secConverter() {
  printf "%02dh %02dm %02ds\n" "$(("$1"/3600))" "$((("$1"%3600)/60))" \
      "$(("$1"%60))"
}

# Start the stopwatch
stopwatch() {
  local start="$(date +%s%N)"
  local timePaused=0
  while true; do
    if [[ -f "/tmp/timerIsPaused$$.txt" ]]; then
      local pauseStart="$(date +%s%N)"
      local pauseEnd="$pauseStart"
      while [[ "$(echo "$(< "/tmp/timerIsPaused$$.txt")")"  == "true" ]]; do
        local pauseEnd="$(date +%s%N)"
        if [[ "$h" == "false" ]]; then
          local end="$(msConverter \
              "$(((("$pauseStart"-"$start")-"$timePaused"+500000)/1000000))")"
          notifyStopwatch "Stopwatch (Paused)" "🕛 $end"
        fi
      done
      ((timePaused+=("$pauseEnd"-"$pauseStart")))
    fi
    # +500000 for rounding (num=num+den/2)
    local end="$(msConverter \
        "$(((("$(date +%s%N)"-"$start")-"$timePaused"+500000)/1000000))")"
    if [[ "$h" == "false" ]]; then
      notifyStopwatch "Stopwatch" "🕛 $end"
    fi
    trap "stop \"Stopwatch (stopped)\" \"🕛 $end\"" SIGINT
  done
}

# Start the timer
timer() {
  local start="$(date "+%s")"
  if [[ "$t" == "true" ]]; then
    local end="$((("$hours"*3600+"$minutes"*60+"$seconds") \
        -("$(date "+%H")"*3600+"$(date "+%M")"*60+"$(date "+%S")")))"
    if [[ "$end" -lt 0 ]]; then
      local end="$(("$end"+86400))"
    fi
    local end="$(("$end"+"$(date "+%s")"))"
  else
    local end="$(date -d "+$hours hours $minutes minutes $seconds seconds" \
        "+%s")"
  fi
  local remaining="$(secConverter "$(("$end" - "$start"))")"

  while [[ "$start" != "$end" ]]; do
    if [[ -f "/tmp/timerIsPaused$$.txt" ]]; then
      local pauseStart="$(date +%s)"
      local pauseEnd="$pauseStart"
      while [[ "$(echo "$(< "/tmp/timerIsPaused$$.txt")")"  == "true" ]]; do
        local pauseEnd="$(date +%s)"
        local remaining=$(secConverter "$(("$end" - "$start"))")
        if [[ "$h" == "false" ]]; then
          notifyTimer "Timer (Paused)" "⏳ $remaining"
        fi
      done
      ((end+=("$pauseEnd"-"$pauseStart")))
    fi
    if [[ "$start" -le "$(date -d "+-1second" "+%s")" ]]; then
      start="$(date "+%s")"
      local remaining=$(secConverter "$(("$end" - "$start"))")
      if [[ "$h" == "false" ]]; then
        notifyTimer "Timer" "⏳ $remaining"
      fi
    fi
    trap "stop \"Timer (stopped)\" \"⌛ $remaining\"" SIGINT
  done
  if [[ "$q" == "false" ]]; then
    echo -n "Timer complete"
    echo -ne "\r"
  fi
  notifyTimer "Timer" "⌛ Complete" -u critical -t 0
  if [[ -f "/tmp/timerIsPaused$$.txt" ]]; then
    rm -f "/tmp/timerIsPaused$$.txt"
  fi
  echo ""
  kill -15 $$
  exit 0
}

# Pause or unpause
# /tmp/timerIsPaused$$.txt - File containing pause information
# First line shows pause state of timer
# Second line shows pause state of stopwatch
pauseUnpause() {
  echo "false" > "/tmp/timerIsPaused$$.txt"

  while true; do
    read -n 1 -s -r

    if [[ "$(echo "$(< "/tmp/timerIsPaused$$.txt")")"  == "true" ]]; then
      echo "false" > "/tmp/timerIsPaused$$.txt"
    else
      echo "true" > "/tmp/timerIsPaused$$.txt"
    fi
  done
}

# Start stopwatch
if [[ "$s" == "true" ]]; then
  if [[ "$#" -eq 0 ]]; then
    stopwatch &
    pauseUnpause
    exit 0
  else
    echo "No arguments needed for stopwatch"
    exit 1
  fi
fi

# Parse arguments and check valid input
hours=0
minutes=0
seconds=0

if [[ "$1" =~ ^[0-9]+:[0-5]?[0-9]:[0-5]?[0-9]$ ]]; then
  hours="$(echo "$1" | cut -d ":" -f1)"
  minutes="$(echo "$1" | cut -d ":" -f2)"
  seconds="$(echo "$1" | cut -d ":" -f3)"
elif [[ "$@" =~ \
    ^([0-9]*h)?[[:space:]]*([0-9]*m)?[[:space:]]*(([0-9]*s)?)$ ]]; then
  remainder="$@"
  if [[ "$remainder" == *h* ]]; then
    hours="${remainder%%h*}"
    remainder="${remainder#*h}"
  fi
  if [[ "$remainder" == *m* ]]; then
    minutes="${remainder%%m*}"
    remainder="${remainder#*m}"
  fi
  if [[ "$remainder" == *s ]]; then
    seconds="${remainder%%s*}"
  fi
else
  echo "Invalid time format"
  exit 1
fi

# Check valid alert time
if [[ "$t" == "true" \
    && ("$hours" -ge 24 || "$minutes" -ge 60 || "$seconds" -ge 60) ]]; then
  echo "Time must be in the range 00:00:00 - 23:59:59"
  exit 1
fi

# Start timer
if [[ "$t" == "true" \
    || ("$hours" -ne 0 || "$minutes" -ne 0 || "$seconds" -ne 0) ]]; then
  timer &
  pauseUnpause
  exit 0
else
  if [[ "$#" -gt 0 ]]; then
    echo "Cannot set timer for 0 seconds"
  else
    usage
  fi
  exit 1
fi
