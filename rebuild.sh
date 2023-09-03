#!/bin/sh

read -p "!!! WARNING: THIS WILL DELETE YOUR DATABASE IF YOU ARE USING THE DEFAULT PATH, CONTINUE? (N/y) " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  echo "ABORTED."
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

dart pub get
dart pub global activate webdev
dart bin/build.dart
rm -rf dist
mv build/latest dist
