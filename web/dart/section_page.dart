import 'dart:html';

import 'html_helpers.dart';

void showPage(String id) {
  querySelectorAll('section.show').classes.remove('show');
  queryDom('section#$id').classes.add('show');
}
