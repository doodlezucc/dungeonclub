#!/usr/bin/env bash
# bash strict mode
set -euo pipefail
# Reading ENV
set +u
enable_music_player=$ENABLE_MUSIC_PLAYER
server_args=""
set -u
echo "-----                                                                      -----"                                                                
echo "                                                                                "
echo "        @@@@@@@  @@@  @@@ @@@  @@@  @@@@@@@  @@@@@@@@  @@@@@@  @@@  @@@         "
echo "        @@!  @@@ @@!  @@@ @@!@!@@@ !@@       @@!      @@!  @@@ @@!@!@@@         "
echo "        @!@  !@! @!@  !@! @!@@!!@! !@! @!@!@ @!!!:!   @!@  !@! @!@@!!@!         "
echo "        !!:  !!! !!:  !!! !!:  !!! :!!   !!: !!:      !!:  !!! !!:  !!!         "
echo "        :: :  :   :.:: :  ::    :   :: :: :  : :: ::   : :. :  ::    :          "
echo "                                                                                "
echo "                                                                                "
echo "                     @@@@@@@ @@@      @@@  @@@ @@@@@@@                          "
echo "                    !@@      @@!      @@!  @@@ @@!  @@@                         "
echo "                    !@!      @!!      @!@  !@! @!@!@!@                          "
echo "                    :!!      !!:      !!:  !!! !!:  !!!                         "
echo "                     :: :: : : ::.: :  :.:: :  :: : ::                          "
echo "                                                                                "
echo "              .,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,                   "
echo "              ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.                  "
echo "              ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.                  "
echo "              ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.                  "
echo "              ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.                  "
echo "              ,,,,,,,,,         ,,,,,,,,,,,         ,,,,,,,,,.                  "
echo "              ,,,,,,,              ,,,,,,              ,,,,,,.                  "
echo "              ,,,,,,               ,,,,,               ,,,,,,.                  "
echo "              ,,,,,,,              ,,,,,,              ,,,,,,.                  "
echo "              ,,,,,,,,            ,,,,,,,,            ,,,,,,,.                  "
echo "              ,,,,,,,,,,        ,,,,,,,,,,,,        ,,,,,,,,,.                  "
echo "              ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.                  "
echo "              ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.                  "
echo "              ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.                  "
echo "              ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.                  "
echo "              ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.                  "
echo "              .,,,,,,,....,,,,,,,,,,,..,,,,,,,,,,,....,,,,,,,.                  "
echo "               .,,,.        .,,,,.        .,,,,.        ,,,,                    "
echo "                                                                                "
echo "-----                        Environment Variables                         -----"
if [[ "$enable_music_player" != "" ]]; then 
echo -n "-----                    " && echo -n "$(printf "%-20s %-28s" ENABLE_MUSIC_PLAYER: "$enable_music_player")" && echo " -----"
fi

echo "-----                             Copy Data                                -----"
# mv -u -v ../app_tmp/* ../app/
rsync -auvhp --remove-source-files --info=progress2 --size-only ../app_tmp/* ../app/

if [[ "$enable_music_player" = "true" ]]; then 
server_args="--music"
echo "-----                  Download and Unzip Ambience Music                   -----"

wget -q --no-check-certificate -O ../app/ambience/music-bundle.zip "https://www.dropbox.com/scl/fi/jvzrz1jy813r0f4d5kxw7/music-bundle.zip?rlkey=88eq8s06mzzgxdpwu96tyj273&dl=1" && unzip -u -v ../app/ambience/music-bundle.zip -d ../app/ambience/ && rm -r ../app/ambience/music-bundle.zip 
#rsync -auvhp --remove-source-files --info=progress2 --size-only ../app/ambience/music-bundle/* ../app/ambience/ 

else
server_args="--no-music"
fi

../app/server "$server_args"