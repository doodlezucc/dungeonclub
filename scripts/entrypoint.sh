#!/bin/bash

# Das set -o pipefail schaltet in Pipelines das Konsensprinzip ein: Eine Pipeline scheitert, sobald irgendwo in der Pipeline etwas schief geht. Das ist das, was man will (fast immer[1]).
set -euo pipefail


# -u  Treat unset variables as an error when substituting.The +u turn this off.
set +u
enable_music_player	= $ENABLE_MUSIC_PLAYER

server_args= ""
set -u

echo "-----                        Environment Variables                         -----"
if [[ "$enable_music_player" != "" ]]; then echo -n "-----                    " && echo -n "$(printf "%-20s %-28s" ENABLE_MUSIC_PLAYER: "$enable_music_player")" && echo " -----"; fi

echo "-----                        Copy Data                         -----"
mv -u -v ../app_tmp/* ../app/

if [[ "$enable_music_player" = "true" ]]; then 
server_args = "--music"

echo "-----                        Update Sytem                         -----"
apt-get update && apt-get upgrade -y
apt-get install unzip
apt-get clean
echo "-----                        Download and Unzip Ambience Music                         -----"

wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1X4yT3Ch-eKqnaucqBkX46XzTt2SITctk' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1X4yT3Ch-eKqnaucqBkX46XzTt2SITctk" -O ../app/ambience/music-bundle.zip && rm -rf /tmp/cookies.txt

unzip ../app/ambience/music-bundle.zip -d ../app/ambience/tracks/

rm -r ..app/ambience/music-bundle.zip
else
server_args = "--no-music"
fi

../app/server "$server_args"