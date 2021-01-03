import 'dart:html';

Future<HttpRequest> request(String action,
    {Map<String, String> params, bool post = true}) async {
  print('lmao');
  var uri = Uri.http(
    'localhost:7070',
    'server',
    {'action': action, ...params},
  );
  //var uri = Uri.file('lol.jpg');
  print(uri);

  return await HttpRequest.request(uri.toString(), responseType: 'arraybuffer');
}
