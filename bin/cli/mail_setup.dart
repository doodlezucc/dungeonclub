import 'dart:io';

import 'package:prompts/prompts.dart' as prompts;
import 'package:googleapis_auth/auth_io.dart' as auth;

import '../server.dart';
import '../service/mail.dart';

Future<void> setupMailAuth() async {
  print('''
-- Create an OAuth 2.0 client --

1. Register a new project in the Google Cloud Console at
   https://console.cloud.google.com/projectcreate

2. Go to "Credentials" and create a new OAuth client ID (application type: "Desktop app")

3. Copy and paste the newly created client ID and secret to proceed
''');

  var clientID = prompts.get('Client ID');
  var clientSecret = prompts.get('Client secret');
  var user = prompts.get('Email address');

  var client = auth.ClientId(clientID, clientSecret);
  var scopes = ['https://mail.google.com/'];
  var creds = await auth.obtainAccessCredentialsViaUserConsent(
    client,
    scopes,
    httpClient,
    (url) {
      print('\nPlease go to the following URL and grant access:');
      print('$url');
    },
  );

  final credentials = MailCredentials(
    user: user,
    clientId: client,
    credentials: creds,
  );

  await credentials.save();
  httpClient.close();
  print('\nAuthorization complete! Emails can now be sent from $user');
  exit(0);
}
