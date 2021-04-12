#!/bin/bash

# Set linting rules
# shellcheck disable=SC1090
# shellcheck disable=SC2059
# shellcheck disable=SC2086
# shellcheck disable=SC2164
# shellcheck disable=SC2002

version='1.0.0'
print_help() {
  printf "seft (Secure Enough File Transfer) \n"
  printf "version: $version \n\n"
  printf "seft is a simple file transfer wrapper script for https://transfer.sh which allows files and directories \n"
  printf "to be password encrypted using openssl aes256. This is ideal for transferring files that are not sensitive \n"
  printf "whilst still keeping files password protected from nosy people.\n\n"
  printf "USAGE: \n"
  printf "    seft -s foo.txt \n"
  printf "    seft -s /path/to/entire/directory -p MyPassword1234 \n"
  printf "    seft -r https://transfer.sh/foobar/foo.txt -p MyPassword1234 -z \n\n"
  printf "OPTIONS: \n"
  printf "    -c    Do not cleanup zip files or encrypted files after processing (Receive only)\n"
  printf "    -d    Enable debugging messages\n"
  printf "    -h    Print help message\n"
  printf "    -l    Password length. Defaults to 6 (Send only)\n"
  printf "    -p    Specifies a password (Send)\n"
  printf "          Password required for decryption (Receive)\n"
  printf "    -r    transfer.sh download url (Receive only)\n"
  printf "    -s    File or directory to send (Send only)\n"
  printf "    -u    Do not encrypt file/directory (Send)\n"
  printf "          Do not decrypt downloaded file (Receive)\n"
  printf "    -z    Do not unzip downloaded file. Useful to keep a transferred directory as a zipped package (Receive only)\n\n"
  printf "TIP:\n"
  printf "    Need to download an encrypted file to a computer that cannot get seft? Use:\n\n"
  printf "      curl https://transfer.sh/foobar/foo.txt -o '<<ENCRYPTED FILENAME>>' \n"
  printf "      openssl enc -k <<PASSWORD>> -aes256 -base64 -d -in '<<ENCRYPTED FILENAME>>' -out '<<DECRYPTED FILENAME>>'\n\n"
  exit 0
}

# Logging functions
debug() { if [[ $enable_debug == 1 ]]; then printf "[ DEBUG ] $1\n"; fi }
log() { if [[ -z "$2" ]]; then message="$1"; level='INFO'; else level="${1^^}"; message="$2"; fi; printf "[ $level ] $message\n"; }

# Functions
cleanup() {
     if ! [[ $cleanup == 'true' ]]; then
      log info "-c switch specified. Not cleaning up: $(basename $1)"
    else
      debug "Cleaning up: $(basename $1)"
      rm -f "$1"
    fi
}

if [ $# -eq 0 ]; then
  print_help
fi

# Set default values
cleanup='true'
direction='send'
password_length=6
unzip='true'

# set script arguments as variables
while getopts "cdf:hlp:r:s:uz" OPT; do
  case "$OPT" in
    c) cleanup='false'; debug 'Not cleaning up encrypted file after transmission';;
    d) enable_debug=1; debug 'Debugging enabled';;
    h) print_help;;
    l) password_length=$OPTARG;;
    p) password=$OPTARG; debug 'A password has been specified';;
    r) address=$OPTARG; debug "Receive address specifed as: $address";;
    s) file=$OPTARG; debug "File/directory specified: $file";;
    u) unencrypted='true'; debug 'Unencrypted transfer specified';;
    z) unzip='false'; debug 'Do not unzip has been specified as: true';;
    *) log error "Invalid argument passed -$OPT.\n" && exit 99 ;;
  esac
done

# Set direction variable for easier reading of script
if [[ -z "$address" ]]; then
  direction='send'
else
  direction='receive'
fi

debug "Transfer direction set to: $direction"
debug "Password length set as: $password_length"

# Validate password length is integer
re='^[0-9]+$'
if ! [[ $password_length =~ $re ]]; then
  log error 'Specified password length is not a valid integer. exit 5'
  exit 5
fi

#
# Send direction (Default)
#

if [[ $direction == 'send' ]]; then

  debug 'Validating file/directory exists'
  if [ ! -e "$file" ];then
    log error "No such file or directory: $file"
    exit 10
  fi

  # Split full path to base/directory name
  file_name=$(basename "$file"); debug "file_name is: $file_name"
  directory=$(dirname "$file");  debug "directory is: $directory"

  # Set password if not specified
  if [[ -z "$password" ]]; then
    debug 'Generating random password'
    password="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $password_length | head -n 1)"
  else
    debug 'A user selected password has been specified'
  fi

  # zip directory if not a file
  if [ -d "$file" ];then
  debug "Zipping directory: $file_name"
    file_name="$file_name.zip" ,
    cd "$file"; debug "Set working directory as: $file"

    log info 'Zipping directory contents'
    zip -r -q - .
  fi

  # Encrypt contents
  if [[ $unencrypted != 'true' ]]; then
    to_send="$directory/$file_name.encrypted"; debug "Encrypted filename is: $to_send"
    openssl enc -k "$password" -aes256 -base64 -e -in "$directory/$file_name" -out "$directory/$to_send" > /dev/null 2>&1
  else
    to_send="$directory/$file_name"
  fi

  # Send file via transfer.sh
  debug 'Starting data transfer with curl'
  cat "$directory/$to_send" | curl --progress-bar --upload-file "-" "https://transfer.sh/$to_send"
  printf "\n"


  # Cleanup encrypted file and print password
  if ! [[ $unencrypted == 'true' ]]; then

    # Cleanup files
    cleanup "$directory/$to_send"

    # Print password
    log info "Password is: $password"
  fi

#
# Receive direction
#

elif [[ $direction == 'receive' ]]; then

  # Validate receive address is populated and valid
  re='^https:\/\/transfer\.sh\/[a-zA-Z0-9]+\/.*$'
  if [[ -z "$address" ]]; then
    log error 'No address specified. Specify a transfer.sh url and try again. exit 20'
    exit 20
  elif ! [[ "$address" =~ $re ]]; then
    log error 'Not a valid transfer.sh address. https:// is required at the beginning. exit 25'
    exit 25
  fi

  # Download file
  debug "Downloading file to current directory: $(pwd)"
  file_name=$(basename "$address")

  curl --progress-bar $address -o $file_name

  # Decrypt file
  suffix='.encrypted'
  out_file=${file_name%"$suffix"}

  if ! [[ $unencrypted == 'true' ]]; then

    if [[ -z "$password" ]]; then
      log error 'No decryption password specified. If you wish to download the file without decrypting it, use the -n switch. exit 27'
      cleanup "./$file_name"
      exit 27
    fi

    log info 'Decrypting downloaded file'
    openssl enc -k $password -aes256 -base64 -d -in "$file_name" -out "$out_file" > /dev/null 2>&1
  fi

  # Unzip file
  if [[ $unzip == 'true' && $out_file == *.zip ]]; then
    log info 'Unzipping file'
    unzip $out_file -q

    cleanup "./$file_name"
    cleanup "./$out_file"

  elif [[ $unzip == 'true' && $out_file == *$suffix ]]; then
    log error 'This file appears to be encrypted still. Unencrypt it first before attempting to unzip. exit 30'
    cleanup "./$file_name"
    cleanup "./$out_file"
    exit 30

  elif [[ $unzip == 'true' && $out_file != *.zip ]]; then
    cleanup "./$file_name"
  fi
fi


debug 'Complete!'
