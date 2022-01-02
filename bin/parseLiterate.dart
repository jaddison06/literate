import 'package:markdown/markdown.dart';
import 'dart:io';
import 'dart:collection';

extension on File {
  String ext() => '.' + path.split('.').last;
}

void _indent(int level) {
  for (var i = 0; i < level; i++) {
    stdout.write(' ');
  }
}

void _printNode(Node node, [int level = 0]) {
  _indent(level);
  if (node is Text) {
    print("Text: '${node.text}'");
  } else if (node is Element) {
    print('Element with tag ${node.tag}:');
    //print("(textContent: '${node.textContent}')");
    for (var child in node.children!) {
      _printNode(child, level + 1);
    }
  } else {
    print('Node of type ${node.runtimeType}');
  }
}

/// WRITES SOURCE FILES, & outputs a map of page titles to HTML content
LinkedHashMap<String, String> parseLiterate(String fname) {
  final litFile = File(fname);

  if (litFile.ext() != '.lit') {
    print('Not a .lit file');
    exit(1);
  }

  final litSource = litFile.readAsLinesSync();
  //Document().parseLines(litSource).forEach(_printNode);

  Directory('out/src').createSync(recursive: true);

  final nodes = Document().parseLines(litSource);
  
  // node indexes which turned out to be code snippets
  final indexes = <int>[];

  // fnames to map of snippet names to snippet text
  final snippets =  <String, Map<String, String>>{};

  Node? pos;
  Node? name;

  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (node is Element && node.tag == 'pre' && (node.children!.first as Element).tag == 'code') {
      indexes.add(i);

      // raw text for the fname and maybe position of the snippet
      String posText = pos!.textContent;
      // name of the snippet
      String nameText = name!.textContent;
      // processed fname of the snippet
      String fname;
      // position of the snippet?
      String? after;
      if (posText.contains(', after ')) {
        final fnameAndPos = posText.split(', after ');
        fname = fnameAndPos[0];
        after = fnameAndPos[1];
      } else {
        fname = posText;
      }

      //print("got snippet '${node.textContent}', in file '$fname', after '$after'\n");

      final isNewFile = !snippets.containsKey(fname);

      if (isNewFile) {
        // new file - write snippet
        File('out/src/$fname').writeAsStringSync(node.textContent);
        snippets[fname] = {nameText: node.textContent};
      } else {
        String source = File('out/src/$fname').readAsStringSync();
        if (snippets[fname]!.containsKey(nameText)) {
          // known snippet name - overwrite the existing one
          final pos = source.indexOf(snippets[fname]![nameText]!);
          source = source.replaceFirst(snippets[fname]![nameText]!, '');
          final pre = source.substring(0, pos);
          final post = source.substring(pos);
          source = pre + node.textContent + post;
        } else if (after != null) {
          // unknown snippet name, position given - write snippet at position
          final afterString = snippets[fname]![after]!;
          final pos = source.indexOf(afterString) + afterString.length;
          final pre = source.substring(0, pos);
          final post = source.substring(pos);
          source = pre + node.textContent + post;
        } else {
          // unknown snippet name, position not specified - append snippet
          source += node.textContent;
        }
        File('out/src/$fname').writeAsStringSync(source);
      }

      snippets[fname]![nameText] = node.textContent;

    }

    pos = name;
    name = node;
  }

  // sort out attributes etc
  // we mutate indexes DURING ITERATION so we have to use i to iterate over an array OF INDEXES.
  // fucking hell i just want to go to bed
  for (var i = 0; i < indexes.length; i++) {
    final index = indexes[i];

    // get rid of annoying <pre> tags
    nodes[index] = (nodes[index] as Element).children!.first;

    // attributes

    nodes[index - 1] = Element.text("p", nodes[index - 1].textContent);
    (nodes[index - 1] as Element).attributes["class"] = "snippet-name";

    nodes[index - 2] = Element.text("p", nodes[index - 2].textContent);
    (nodes[index - 2] as Element).attributes["class"] = "snippet-pos";

    // removing the pre tag also gets rid of the fucking newline for some reason
    // so let's add that back in
    nodes.insert(index, Text('\n'));
    // AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    for (var j = i; j < indexes.length; j++) {
      indexes[j]++;
    }
  }

  final pages = LinkedHashMap<String, String>();
  String? title;
  List<Node>? previous;
  for (var node in nodes) {
    if (node is Element && node.tag == "h1") {
      if (title != null) {
        pages[title] = renderToHtml(previous!);
      }
      title = node.textContent;
      previous = [];
      continue;
    }
    // assumes the first tag will always be an h1, so previous will exist
    previous!.add(node);
  }

  // Add the final one
  pages[title!] = renderToHtml(previous!);
  
  return pages;
}
