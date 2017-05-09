#!/bin/bash

# syntax check
if ! bash -n "$0"; then
  echo 'Script syntax error' >&2
  exit 1
fi

readlink_() {
  declare src="${BASH_SOURCE[0]}"
  declare dir=

  while [ -h "$src" ]; do
    dir="$(cd -P "$( dirname "$src" )" && pwd)"
    src="$(readlink "$src")"
    [[ $src != /* ]] && src="$dir/$src"
  done
  cd -P "$( dirname "$src" )" && pwd
}

_pwd=$(readlink_ "$0")

err() {
  echo "$@" >&2
}

die() {
  err "$@"
  exit 1
}

finish() {
  cd "$_pwd" || die 'cd error'

  if [ "$no_clean" -eq 0 ]; then
    find . -name '*.deb' -type f | xargs rm -f
  fi
}

trap "finish" EXIT

usage() {
  # Local var because of grep
  declare helpdoc='HELP'
  helpdoc+='DOC'
  echo 'Usage: test.sh [opts]'
  echo 'Opts:'
  grep "$helpdoc" "$_pwd/test.sh" -B 1 | egrep -v '^--$' | sed -e 's/^  //g' -e "s/# $helpdoc: //g"
}

vagrant_clean() {
  vagrant destroy -f upstart systemd no-init redirect
}

declare -i failures=0
declare -i no_clean=0
declare -i clean_first=0
declare single_project_test=

while [ -n "$1" ]; do
  param="$1"
  value="$2"
  case $param in
    --clean)
      # HELPDOC: Run all clean up tasks and exit (no tests will be run)
      echo 'Removing test resources'
      finish
      vagrant_clean
      trap - EXIT
      trap
      echo 'Clean up complete'
      exit 0
      ;;
    --clean-first)
      # HELPDOC: Run all clean up tasks then run all tests
      clean_first=1
      ;;
    -h | --help)
      # HELPDOC: Display this message and exit
      usage
      exit 0
      ;;
    --no-clean)
      # HELPDOC: Don't delete files generated during the tests
      no_clean=1
      ;;
    --only)
      # HELPDOC: Run only a single test by name
      if echo "$value" | egrep -q '[^a-zA-Z0-9\-_]' | egrep -q '^test-'; then
        die "Invalid test name: $value"
      fi
      single_project_test="$value"
      shift
      ;;
    *)
      echo "Invalid option: $param" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

cd "$_pwd" || die 'cd error'

if [ "$clean_first" -ne 0 ]; then
  echo 'Removing test resources'
  finish
  vagrant_clean
  echo 'Clean up complete'
fi

### TESTS ###

test-node-deb-syntax() {
  echo 'Running syntax check'
  cd "$_pwd" || die 'cd error'

  if bash -n 'node-deb'; then
    echo 'Syntax check success'
    return 0
  else
    err 'Syntax check failure'
    return 1
  fi
}

test-simple-project() {
  echo "Running tests for simple-project"
  cd "$_pwd/test/simple-project" || die 'cd error'

  declare -i is_success=1
  declare output
  output=$(../../node-deb --no-delete-temp -- app.js lib/ package.json)

  if [ "$?" -ne 0 ]; then
    is_success=0
    err "$output"
  fi

  output_dir='simple-project_0.1.0_all/'

  if ! grep -q 'Package: simple-project' "$output_dir/DEBIAN/control"; then
    err 'Package name was wrong'
    is_success=0
  fi

  if ! grep -q 'Version: 0.1.0' "$output_dir/DEBIAN/control"; then
    err 'Package version was wrong'
    is_success=0
  fi

  if [ "$is_success" -eq 1 ]; then
    echo "Success for simple-project"
    rm -rf "$output_dir"
  else
    err "Failure for simple project"
    : $((failures++))
  fi
}

test-whitespace-project() {
  echo "Running tests for whitespace-project"
  cd "$_pwd/test/whitespace-project" || die 'cd error'

  declare -i is_success=1

  declare output
  output=$(../../node-deb -- 'whitespace file.js' 'whitespace folder' package.json 2>&1)

  if [ "$?" -ne 0 ]; then
    is_success=0
  fi

  output+='\n'
  output+=$(../../node-deb --  whitespace\ file.js whitespace\ folder package.json 2>&1)
  if [ "$?" -ne 0 ]; then
    is_success=0
  fi

  if [[ $output == '*No such file or directory*' ]]; then
    err 'There was an error with the test.'
    err -e "$output"
    err 'Unable to locate a directory. This is likely an error with `find`.'
  fi

  if [ "$is_success" -eq 1 ]; then
    echo "Success for whitespace-project"
  else
    err "Failure for whitespace-project"
    : $((failures++))
  fi
}

test-node-deb-override-project() {
  echo "Running tests for node-deb-override-project"
  cd "$_pwd/test/node-deb-override-project" || die 'cd error'

  declare -i is_success=1
  declare output
  output=$(../../node-deb --no-delete-temp -- app.js lib/ package.json)

  if [ "$?" -ne 0 ]; then
    is_success=0
    err "$output"
  fi

  declare -r output_dir='overridden-package-name_0.1.1_all/'

  if ! grep -q 'Package: overridden-package-name' "$output_dir/DEBIAN/control"; then
    err 'Package name was wrong'
    is_success=0
  fi

  if ! grep -q 'Version: 0.1.1' "$output_dir/DEBIAN/control"; then
    err 'Package version name was wrong'
    is_success=0
  fi

  if ! grep -q 'Maintainer: overridden maintainer' "$output_dir/DEBIAN/control"; then
    err 'Package maintainer was wrong'
    is_success=0
  fi

  if ! grep -q 'Description: overridden description' "$output_dir/DEBIAN/control"; then
    err 'Package description was wrong'
    is_success=0
  fi

  if ! grep -q 'POSTINST_OVERRIDE' "$output_dir/DEBIAN/postinst"; then
    err 'postinst template override was wrong'
    is_success=0
  fi

  if ! grep -q 'POSTRM_OVERRIDE' "$output_dir/DEBIAN/postrm"; then
    err 'postrm template override was wrong'
    is_success=0
  fi

  if ! grep -q 'PRERM_OVERRIDE' "$output_dir/DEBIAN/prerm"; then
    err 'prerm template override was wrong'
    is_success=0
  fi

  if ! grep -q 'PREINST_OVERRIDE' "$output_dir/DEBIAN/preinst"; then
    err 'preinst template override was wrong'
    is_success=0
  fi

  if ! grep -q 'SYSTEMD_SERVICE_OVERRIDE' "$output_dir/etc/systemd/system/overridden-package-name.service"; then
    err 'systemd.service template override was wrong'
    is_success=0
  fi

  if ! grep -q 'UPSTART_CONF_OVERRIDE' "$output_dir/etc/init/overridden-package-name.conf"; then
    err 'upstart.conf template override was wrong'
    is_success=0
  fi

  if ! grep -q 'EXECUTABLE_OVERRIDE' "$output_dir/usr/share/overridden-package-name/bin/overridden-executable-name"; then
    err 'executable template override was wrong'
    is_success=0
  fi

  if [ "$is_success" -eq 1 ]; then
    echo "Success for simple-project"
    rm -rf "$output_dir"
  else
    err "Failure for simple project"
    : $((failures++))
  fi
}

test-commandline-override-project() {
  echo "Running tests for commandline-override-project"
  cd "$_pwd/test/commandline-override-project" || die 'cd error'

  declare -i is_success=1
  declare output

  output=$(../../node-deb --no-delete-temp \
    -n overridden-package-name \
    -v 0.1.1 \
    -u overridden-user \
    -g overridden-group \
    -m 'overridden maintainer' \
    -d 'overridden description' \
    -- app.js lib/ package.json)

  if [ "$?" -ne 0 ]; then
    is_success=0
    err "$output"
  fi

  output_dir='overridden-package-name_0.1.1_all/'

  if ! grep -q 'Package: overridden-package-name' "$output_dir/DEBIAN/control"; then
    err 'Package name was wrong'
    is_success=0
  fi

  if ! grep -q 'Version: 0.1.1' "$output_dir/DEBIAN/control"; then
    err 'Package version name was wrong'
    is_success=0
  fi

  if ! grep -q 'Maintainer: overridden maintainer' "$output_dir/DEBIAN/control"; then
    err 'Package maintainer was wrong'
    is_success=0
  fi

  if ! grep -q 'Description: overridden description' "$output_dir/DEBIAN/control"; then
    err 'Package description was wrong'
    is_success=0
  fi

  if [ "$is_success" -eq 1 ]; then
    echo "Success for simple-project"
    rm -rf "$output_dir"
  else
    err "Failure for simple project"
    : $((failures++))
  fi
}

test-upstart-project() {
  echo 'Running tests for upstart-project'
  declare -r target_file='/var/log/upstart-project/TEST_OUTPUT'
  declare -i is_success=1

  # Make sure process can be started
  vagrant up --provision upstart && \
  vagrant ssh upstart -c "if [ -a '$target_file' ]; then sudo rm -rf '$target_file'; fi" && \
  echo 'Sleeping...' && \
  sleep 3 && \
  vagrant ssh upstart -c "[ -f '$target_file' ]"

  if [ "$?" -ne 0 ]; then
    is_success=0
    err 'Failure on checking file existence for target host'
  fi

  # Make sure process can be stopped
  vagrant ssh upstart -c "sudo service upstart-project stop && { if [ -a '$target_file' ]; then sudo rm -rf '$target_file'; fi }" && \
  echo 'Sleeping...' && \
  sleep 3 && \
  vagrant ssh upstart -c "[ ! -f '$target_file' ]"

  if [ "$?" -ne 0 ]; then
    is_success=0
    err 'Failure on checking file absence for target host after process was stopped'
  fi

  if [ "$is_success" -ne 1 ]; then
    err 'Failure for upstart-project'
    : $((failures++))
  else
    vagrant destroy -f upstart
    echo 'Success for upstart-project'
  fi
}

test-systemd-project() {
  echo 'Running tests for systemd-project'
  declare -r target_file='/var/log/systemd-project/TEST_OUTPUT'
  declare -i is_success=1

  # Make sure process can be started
  vagrant up --provision systemd && \
  vagrant ssh systemd -c "if [ -a '$target_file' ]; then sudo rm -rf '$target_file'; fi" && \
  echo 'Sleeping...' && \
  sleep 3 && \
  vagrant ssh systemd -c "[ -f '$target_file' ]"

  if [ "$?" -ne 0 ]; then
    is_success=0
    err 'Failure on checking file existence for target host'
  fi

  # Make sure process can be stopped
  vagrant ssh systemd -c "sudo systemctl stop systemd-project && { if [ -a '$target_file' ]; then sudo rm -rf '$target_file'; fi }" && \
  echo 'Sleeping...' && \
  sleep 3 && \
  vagrant ssh systemd -c "[ ! -f '$target_file' ]"

  if [ "$?" -ne 0 ]; then
    is_success=0
    err 'Failure on checking file absence for target host after process was stopped'
  fi

  if [ "$is_success" -ne 1 ]; then
    err 'Failure for systemd-project'
    : $((failures++))
  else
    vagrant destroy -f systemd
    echo 'Success for systemd-project'
  fi
}

test-no-init-project() {
  echo 'Running tests for no-init-project'
  declare -r target_file='/var/log/no-init-project/TEST_OUTPUT'
  declare -i is_success=1

  vagrant up --provision no-init && \
  sleep 3 && \
  vagrant ssh no-init -c "[ ! -f '$target_file' ]"

  if [ "$?" -ne 0 ]; then
    is_success=0
    err 'Failure on checking file absence for target host'
  fi

  vagrant ssh no-init -c "no-init-project" && \
  vagrant ssh no-init -c "[ -f '$target_file' ]"

  if [ "$is_success" -ne 1 ]; then
    err 'Failure for no-init-project'
    : $((failures++))
  else
    vagrant destroy -f no-init
    echo 'Success for no-init-project'
  fi
}

test-redirect-project() {
  echo 'Running tests for redirect-project'
  declare -r target_file='/var/log/redirect-project/TEST_OUTPUT'
  declare -r target_file_stdout='/var/log/redirect-project/TEST_OUTPUT_STDOUT'
  declare -r target_file_stderr='/var/log/redirect-project/TEST_OUTPUT_STDERR'
  declare -r target_file_redirect='/var/log/redirect-project/TEST_OUTPUT_REDIRECT'
  declare -i is_success=1

  vagrant up --provision redirect && \
  vagrant ssh redirect -c "sudo redirect-project" && \
  echo 'App was run.' && \
  vagrant ssh redirect -c "[ -f '$target_file' ] && [ -f '$target_file_stdout' ] && [ -f '$target_file_stderr' ] && [ -f '$target_file_redirect' ]" && \
  echo 'Files were found.' && \
  vagrant ssh redirect -c "{ ! grep -q '{{' \"$(which redirect-project)\"; }" && \
  echo 'Everything was replaced.'

  if [ "$?" -ne 0 ]; then
    is_success=0
  fi

  if [ "$is_success" -ne 1 ]; then
    err 'Failure for redirect-project'
    : $((failures++))
  else
    vagrant destroy -f redirect
    echo 'Success for redirect-project'
  fi
}

test-dog-food() {
  echo 'Running the dog food test'
  cd "$_pwd" || die 'cd error'
  declare -i is_success=1

  if ! ./node-deb --no-delete-temp -- node-deb templates/ package.json; then
    is_success=0
  fi

  declare -r node_deb_version=$(jq -r '.version' "./package.json")
  declare -r output_dir="node-deb_${node_deb_version}_all/"

  if [ $(find "$output_dir" -name 'node-deb' -type f | wc -l) -lt 1 ]; then
    is_success=0
    err "Couldn't find node-deb in output"
  fi

  if [ $(find "$output_dir" -name 'templates' -type d | wc -l) -lt 1 ] || [ $(find "$output_dir/" -type f | grep 'templates' | wc -l) -lt 1 ]; then
    is_success=0
    err "Couldn't find templates"
  fi

  rm -rf "$output_dir"

  if [ "$is_success" -ne 1 ]; then
    : $((failures++))
    err 'Failure for the dog food test'
  else
    echo 'Success for the dog food test'
  fi
}

if [ -n "$single_project_test" ]; then
  echo '--------------------------'
  eval "$single_project_test"
  echo '--------------------------'
else
  echo '--------------------------'
  test-node-deb-syntax
  echo '--------------------------'
  test-simple-project
  echo '--------------------------'
  test-whitespace-project
  echo '--------------------------'
  test-node-deb-override-project
  echo '--------------------------'
  test-commandline-override-project
  echo '--------------------------'
  test-dog-food
  echo '--------------------------'
  test-upstart-project
  echo '--------------------------'
  test-systemd-project
  echo '--------------------------'
  test-no-init-project
  echo '--------------------------'
  test-redirect-project
  echo '--------------------------'
fi

trap - EXIT
trap

if [ "$failures" -eq 0 ]; then
  echo "Success for all tests"
  finish
  exit 0
else
  die "Tests contained $failures failure(s)."
fi
