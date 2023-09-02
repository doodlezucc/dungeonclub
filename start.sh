#!/bin/sh

# copy mock account file
cp login.yaml dist/login.yaml
cp config.yaml dist/config.yaml

# go to working directory (latest release)
cd dist

# force recompile assets on launch
rm web/images/assets/entity-preview.png
rm web/images/assets/pc-preview.png
rm web/images/assets/scene-preview.jpg

# execute server
exec ./server --port 7070 $@
