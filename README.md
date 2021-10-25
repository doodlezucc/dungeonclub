# D&D Interactive <img align="right" src="web/images/icon.png" alt="Icon" height=96 />

**Dungeons & Dragons** is an immersive pen-and-paper RPG. Like every tabletop game, you'll surely need a table for everyone to gather around.
Now, if your group of adventurous travelers and travelling adventurers is scattered all across the country and you don't have the chance to meet up a lot,
virtual tabletops can be of great help to carry out a game of D&D.

[**D&D Interactive**](https://theoretically.online/dnd) strives to be the most user-friendly online session tool, with a high standard of functionality range and design. Feel free to contribute!


## Running the Code Yourself
If you want to test your own code additions, there are basically three programs you'd need to run simultaneously.
All three require an installation of the ***Dart SDK***, which you can get [here](https://dart.dev/get-dart).

After downloading Dart, start out by running `dart pub get` in the root directory. This will download all required dependencies.


### 1. Backend
The server/backend of D&D Interactive can be started by running `dart bin/server.dart` (or simply pressing `F5` in Visual Studio Code).

Make sure to fill out the `mail/gmail_credentials` file with your Gmail address in the first line and your Gmail password in the second.
(This method might be replaced with an OAuth approach in the future.)


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

#### You should now be able to see your own version of D&D Interactive up and running at [http://localhost:8080](http://localhost:8080). Yay!
