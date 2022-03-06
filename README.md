# Dungeon Club - Virtual Tabletop <img align="right" src="web/images/icon.png" alt="Icon" height=96 />

An online platform to gather and play Dungeons & Dragons, Call of Cthulu, Pathfinder and more.

[**Dungeon Club**](https://theoretically.online/dnd) strives to be the most user-friendly virtual tabletop, with a high standard of functionality and design. Feel free to contribute!


## Running the Code Yourself
If you want to test your own code additions, there are basically three programs you'd need to run simultaneously.
All three require an installation of the ***Dart SDK***, which you can get [here](https://dart.dev/get-dart).

After downloading Dart, start out by running `dart pub get` in the root directory. This will download all required dependencies.


### 1. Backend
The server/backend of Dungeon Club can be started by running `dart bin/server.dart` (or simply pressing `F5` in Visual Studio Code).

To enable email serving, a registered OAuth 2.0 client is required.
Run `dart bin/server.dart mail` to open an interactive walkthrough on how to create a free OAuth 2.0 client
with [Google Cloud Console](https://console.cloud.google.com/).


### 2. Frontend
To compile all frontend code (located in `web/dart`) to JavaScript in realtime, you'll first need to install the [webdev package](https://pub.dev/packages/webdev)
by running `dart pub global activate webdev`.

Once you've done that, run `webdev serve` in the root directory. Congratulations, you just translated fancy Dart code into instructions your browser can understand!

This realtime compiler doesn't produce optimal JavaScript, but every change you make to the code is instantly visible after refreshing the website.


### 3. Styling with Sass
Sass/SCSS is a styling language, extending on CSS. Another Dart package is required to compile it.
Similar to webdev, the [sass package](https://pub.dev/packages/sass) can be installed via `dart pub global activate sass`.

Running `sass web/sass/style.scss web/style/style.css --style compressed` will compile all stylesheets into a single minified CSS file.
If you're not editing any Sass files, this must only be run once.

#### 3.1 Editing Sass
You can append `--watch` to the command in order to keep the result up to date.
Pressing `Shift`+`R` in your browser reloads the stylesheet without having to refresh. (The shortcut is not available in Firefox.)

<br>

#### You should now be able to see your own version of Dungeon Club up and running at [http://localhost:8080](http://localhost:8080). Yay!
