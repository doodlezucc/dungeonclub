# Dungeon Club - Virtual Tabletop <img align="right" src="web/images/icon.png" alt="Icon" height=96 />

An online platform to gather and play Dungeons & Dragons, Call of Cthulu, Pathfinder and more.

[**Dungeon Club**](https://theoretically.online/dnd) strives to be the most *user-friendly* virtual tabletop of all, providing tons of features and a comfortable design.
Visit the homepage for a demonstration of features or [try the demo](https://theoretically.online/dnd/game/sandbox) right now!

## Development
There are three essential parts to debugging and running this VTT locally, all of which require an [installation of Dart](https://dart.dev/get-dart).
If you're on Windows and don't want the trouble of installing Chocolatey, I recommend following [this guide](https://medium.com/2beengineer/install-the-dart-sdk-on-windows-10-b503cd065ab5) instead.

After downloading the SDK and making sure it's part of your PATH, run the following lines as a *one-time* setup:

```bash
# Clone repository and navigate into the directory
git clone https://github.com/doodlezucc/dungeonclub.git
cd dungeonclub

dart pub get                     # Download all required packages
dart pub global activate sass    # Download SCSS->CSS transpiler
dart pub global activate webdev  # Download Dart->JavaScript transpiler
```
<sup>More info on [sass](https://pub.dev/packages/sass) and [webdev](https://dart.dev/tools/webdev).</sup>

You're now ready to start a debuggable local Dungeon Club server!

### Launching via VS Code
If you're a using the IDE [Visual Studio Code](https://code.visualstudio.com/), you can make use of repository-included launch configurations available for both server and web.
- **Server/Backend** - Run *`Debug: Start Debugging`* (or press <kbd>F5</kbd>).
- **Web/Frontend** - Run *`Tasks: Run Build Task`* (or press <kbd>Control</kbd>+<kbd>Shift</kbd>+<kbd>B</kbd>).

### Launching via Shell
Alternatively, you can open three separate terminals and enter the following one-liners.

```bash
# Launch the backend server
dart bin/server.dart
```
```bash
# Convert from Dart to browser-readable JavaScript (file watching)
webdev serve
```
```bash
# Convert from SCSS to CSS (-w enables file watching) 
sass web/sass/style.scss web/style/style.css -s compressed -w
```

If `webdev` and `sass` commands aren't available on your PATH, you can use `dart pub global run [command from above]`.

After initializing backend and web serving, you can go to [_`localhost:8080`_](http://localhost:8080) and view your freshly delivered, live-compiled version of Dungeon Club.

Changes to the source code are reflected at different times depending on what part you're working on. Changes can be seen...
- **Server Code** - after restarting the server.
- **Website Code** - after refreshing the website (at _`http://localhost:8080`_).
- **Website Stylesheet** - after refreshing the website or by pressing <kbd>Shift</kbd>+<kbd>R</kbd> (not available on Firefox).

## Self-Hosting
You can find the official public version of Dungeon Club at https://theoretically.online/dnd. In case you (for one reason or another) want to host a local server on your machine, there are two ways to achieve this.

### Pre-Compiled Releases

Whenever an update rolls out to the public website, a new *release* is added to the repository [Releases](releases) tab. Releases consist of a short changelog followed by a list of pre-compiled builds for multiple platforms and architectures.

After downloading and unzipping your selected build, you will find two relevant files inside:
- **server.exe** - The executable server. (Depending on your platform, the file extension may differ.)
- **login.yaml** - A file which may define custom account logins.

When executing `server.exe`, a terminal opens up, informing you that Dungeon Club is now _`serving at http://localhost:7070`_.
You can navigate to this address and see your very own copy of the VTT loaded and ready to use.

Try logging into the pre-registered mock account by filling in email "admin", password "admin" on the homepage.
There's no difference in using a *mock account* vs. a regular *email-verified account*, aside from the way it's created.
Upon a successful login, you're presented with the ability to create and manage your own campaigns.

If you open the server port (`7070` by default) in your network, outside players should be able to interact with your locally hosted website by accessing your IP address.

**Important**: Please note that closing the shell window can lead to losing **unsaved changes** on some platforms. It is recommended to gracefully shutdown the server by pressing <kbd>Control</kbd>+<kbd>C</kbd> inside the terminal.

### Custom Build
Apart from the official list of executable releases, you can also build Dungeon Club yourself.
Follow the one-time setup described in [Development](#development) to install required tools.
Then, execute the repository-included dedicated build script by running the following command:

```
dart bin/build.dart [options]
```

For a list of possible arguments, run `dart bin/build.dart --help` or take a look at [Building Options](#building-options).

## Command Line Arguments
The following options may be entered as arguments to both the server and the builder file.

Option | Definition | Default
------ | ---------- | -------
`--[no-]mock-account` | Whether to accept contents of "login.yaml" as a list of registered accounts. | `true`
`--[no-]music` | Whether to enable the integrated audio player. Server hosts may need to install youtube-dl and ffmpeg to download 500 MB of background music. | `false`

### Building Options
Additional arguments can be provided when compiling Dungeon Club into native machine code.

Option | Definition | Default
------ | ---------- | -------
`--[no-]copy-music` | Whether to include locally downloaded music (ambience/tracks/*.mp3) in the build. | `false`
`--part` | Which parts to compile and include in the build. Can be `server` or `all`. | `all`