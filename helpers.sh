function retry() {
  local i=1
  local max=$1
  shift
  local pause=5

  while true; do
    "$@" && break || {
      if [[ $i -lt $max ]]; then
	((i++))
	echo "Attempt failed, $i of $max"
	sleep $pause
      else
	echo "$max attempts failed. exiting."
	exit 1
      fi
    }
  done
}
