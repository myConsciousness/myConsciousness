import 'dart:convert';
import 'dart:io';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:http/http.dart';
import 'package:intl/intl.dart';

const _myBskyTimelineSectionStart =
    '<!-- MY-BSKY_TIMELINE:START - Do not remove or modify this section -->';
const _myBskyTimelineSectionEnd = '<!-- MY-BSKY_TIMELINE:END -->';

const _myZennArticlesSectionStart =
    '<!-- MY-ZENN-ARTICLES:START - Do not remove or modify this section -->';
const _myZennArticlesSectionEnd = '<!-- MY-ZENN-ARTICLES:END -->';

Future<void> main(List<String> arguments) async {
  await _updateBlueskyTimeline();
  await _updateZennArticles();
}

Future<void> _updateBlueskyTimeline() async {
  final session = await bsky.createSession(
    identifier: Platform.environment['BLUESKY_IDENTIFIER']!,
    password: Platform.environment['BLUESKY_PASSWORD']!,
  );

  final bluesky = bsky.Bluesky.fromSession(
    session.data,
    retryConfig: bsky.RetryConfig(
      maxAttempts: 10,
      onExecute: (event) => print(
        'Retry after ${event.intervalInSeconds} seconds... '
        '[${event.retryCount} times]',
      ),
    ),
  );

  final feeds = await bluesky.feeds.findFeed(
    actor: 'shinyakato.dev',
    limit: 5,
  );

  final postUIs = <String>[];
  for (final feed in feeds.data.feed) {
    final post = feed.post;
    final me = post.author;

    postUIs.add(
        '''\n> ${me.displayName} @${me.handle} ${post.indexedAt.toUtc().toIso8601String()}
>
> ${feed.post.record.text}
''');
  }

  final readme = File('README.md');
  String content = readme.readAsStringSync();

  readme.writeAsStringSync(
    _replaceFileContent(
      content,
      _myBskyTimelineSectionStart,
      _myBskyTimelineSectionEnd,
      '\n---\n${postUIs.join('\n---\n')}\n---\n',
    ),
  );
}

Future<void> _updateZennArticles() async {
  final response = await get(
    Uri.https('zenn.dev', '/api/articles', {
      'username': 'kato_shinya',
      'count': '5',
      'order': 'latest',
    }),
  );

  if (response.statusCode != 200) {
    return;
  }

  final json = jsonDecode(response.body);
  final dateFormat = DateFormat('yyyy-MM-dd');

  final articles = <String>['- [Zenn](https://zenn.dev/kato_shinya)'];
  for (final Map<String, dynamic> article in json['articles']) {
    final publishedAt = DateTime.parse(article['published_at']);

    articles.add(
      '  - ${article['emoji']} [${article['title']}](https://zenn.dev${article['path']}) (${dateFormat.format(publishedAt)})',
    );
  }

  final readme = File('README.md');
  String content = readme.readAsStringSync();

  readme.writeAsStringSync(
    _replaceFileContent(
      content,
      _myZennArticlesSectionStart,
      _myZennArticlesSectionEnd,
      '''\n${articles.join('\n')}\n''',
    ),
  );
}

String _replaceFileContent(
  final String content,
  final String startSection,
  final String endSection,
  final String newContent,
) =>
    content.replaceRange(
      content.indexOf(startSection) + startSection.length,
      content.indexOf(endSection),
      newContent,
    );
