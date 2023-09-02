#!/bin/sh

dart pub get
dart pub global activate webdev
dart bin/build.dart
mkdir -p tmp
mv dist/database tmp/database
rm -rf dist
mv build/latest dist
mv tmp/database dist/database
