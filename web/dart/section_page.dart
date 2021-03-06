import 'dart:html';

void showPage(String id) {
  querySelectorAll('section.show').classes.remove('show');
  querySelector('section#$id').classes.add('show');
}
