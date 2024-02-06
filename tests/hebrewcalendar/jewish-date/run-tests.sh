#!/usr/bin/env bash

set -eu -o pipefail

# Load all lines into an array.
mapfile -t lines < ./tests/hebrewcalendar/jewish-date/tests.psv

# Log the test cases
echo 'Tests:'
printf '  %s\n' "${lines[@]}"
echo '-------'

# Loop through the test cases
for line in "${lines[@]}"; do
#  echo "$line"

  # Split each line into the Gregorian input, and the expected output.
  # https://stackoverflow.com/a/27521984/8037425
  read -r gregorian expected <<< "$(echo "$line" | awk -F'|' '{print $1" "$2}')"
  printf "Running test...\n  Gregorian: '%s'\n  Expected: '%s'\n" "$gregorian" "$expected"

  sql="CALL gregorian_date_to_jewish_date($gregorian, @jewishYear, @jewishMonth, @jewishDay); SELECT @jewishYear, @jewishMonth, @jewishDay;"

  # The `tail` is needed to drop out the following output: `failed to get console mode for stdout: The handle is invalid.`
  output=$($MYSQL_CMD -u root --batch --database db1 --skip-column-names --execute "$sql" | sed 's/\t/,/g' | tail -n 1)
  printf "  Output: '%s'\n" "$output"

  # Assert the actual output matches the expected output
  if [[ "$output" == "$expected" ]]
    then
      echo 'Passed.'
      echo '-------'
    else
      echo "Failed: Expected '$output' to equal '$expected'"
      exit 1
  fi

done
