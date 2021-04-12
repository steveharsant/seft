# seft

seft (Secure Enough File Transfer)

seft is a simple file transfer wrapper script for [transfer.sh](https://transfer.sh) which allows files and directories to be password encrypted using openssl aes256. This is ideal for transferring files that are not sensitive whilst still keeping files password protected from nosy people.

## Installation

```shell
chmod +x /path/to/seft.sh
sudo ln -sf  /path/to/seft.sh /usr/bin/seft
```
## Usage

```shell
seft -s foo.txt
seft -s /path/to/entire/directory -p MyPassword1234
seft -r https://transfer.sh/foobar/foo.txt -p MyPassword1234 -z
```

## Options

```shell
-c    Do not cleanup zip files or encrypted files after processing (Receive only)
-d    Enable debugging messages
-h    Print help message
-l    Password length. Defaults to 6 (Send only)
-p    Specifies a password (Send)
      Password required for decryption (Receive)
-r    transfer.sh download url (Receive only)
-s    File or directory to send (Send only)
-u    Do not encrypt file/directory (Send)
      Do not decrypt downloaded file (Receive)
-z    Do not unzip downloaded file. Useful to keep a transferred directory as a zipped package (Receive only)
```

## Tips

Need to download an encrypted file to a computer that cannot get seft? Use:

```shell
curl https://transfer.sh/foobar/foo.txt -o '<<ENCRYPTED FILENAME>>'
openssl enc -k <<PASSWORD>> -aes256 -base64 -d -in '<<ENCRYPTED FILENAME>>' -out '<<DECRYPTED FILENAME>>'
```
