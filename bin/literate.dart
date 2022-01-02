import 'parseLiterate.dart';
import 'dart:io';

// The fun bit is now in parseLiterate.dart, this is just an example of how you could use it
void main(List<String> arguments) {
  if (arguments.length != 1) {
    print('Usage: literate [file]');
    exit(1);
  }
  final pages = parseLiterate(arguments.first);

  Directory('out/html').createSync(recursive: true);

  var index = '';
  
  for (var entry in pages.entries) {
    final first = entry.key == pages.keys.first;
    final last = entry.key == pages.keys.last;
    String? previous = first ? null : (pages.keys.toList()[pages.keys.toList().indexOf(entry.key) - 1]);
    String? next = last ? null : (pages.keys.toList()[pages.keys.toList().indexOf(entry.key) + 1]);
    final header =
      '<title>${entry.key}</title>\n'
      '<div class="navigation">\n'
      '<a class=".home-button .button-enabled" href="index.html">Home</a>\n'
      '<a class=".prev-button ${first ? ".button-disabled" : ".button-enabled"}" href="${first ? "" : "$previous.html"}">Previous</a>\n'
      '<a class=".next-button ${last  ? ".button-disabled" : ".button-enabled"}" href="${last  ? "" :     "$next.html"}">Next</a>\n'
      '</div>\n';

    File('out/html/${entry.key}.html').writeAsStringSync(header + entry.value);

    index += '<a href="${entry.key}.html">${entry.key}</a>\n';
  }

  File('out/html/index.html').writeAsStringSync(index);
}