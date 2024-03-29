import 'dart:convert';
import 'dart:io';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:http/http.dart';
import 'package:intl/intl.dart';

const _myBskyTimelineSectionStart =
    '<!-- MY-BSKY_TIMELINE:START - Do not remove or modify this section -->';
const _myBskyTimelineSectionEnd = '<!-- MY-BSKY_TIMELINE:END -->';

const _myDevToArticlesSectionStart =
    '<!-- MY-DEV-TO-ARTICLES:START - Do not remove or modify this section -->';
const _myDevToArticlesSectionEnd = '<!-- MY-DEV-TO-ARTICLES:END -->';

const _myZennArticlesSectionStart =
    '<!-- MY-ZENN-ARTICLES:START - Do not remove or modify this section -->';
const _myZennArticlesSectionEnd = '<!-- MY-ZENN-ARTICLES:END -->';

Future<void> main(List<String> arguments) async {
  await _updateBlueskyTimeline();
  await _updateDevToArticle();
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
    actor: Platform.environment['BLUESKY_IDENTIFIER']!,
  );

  final postUIs = <String>[];
  for (final feed in feeds.data.feed) {
    if (feed.reason != null) {
      //! Exclude reposts.
      continue;
    }

    final post = feed.post;
    final me = post.author;

    postUIs.add(
        '''\n> ${me.displayName} @${me.handle} ${post.indexedAt.toUtc().toIso8601String()}
>
> ${feed.post.record.text}
''');

    if (postUIs.length == 5) {
      break;
    }
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

Future<void> _updateDevToArticle() async {
  final response = await get(
    Uri.https(
      'dev.to',
      '/api/articles',
      {'username': 'shinyakato'},
    ),
  );

  if (response.statusCode != 200) {
    return;
  }

  final json = jsonDecode(response.body);
  final dateFormat = DateFormat('yyyy-MM-dd');

  final articles = <String>['- [Dev.to](https://dev.to/shinyakato)'];

  final now = DateTime.now();
  final oneWeekAgo = now.subtract(Duration(days: 7));

  for (final Map<String, dynamic> article in json) {
    final publishedAt = DateTime.parse(article['published_at']);

    if (publishedAt.isAfter(oneWeekAgo) && publishedAt.isBefore(now)) {
      articles.add(
        '  - 🆕 [${article['title']}](${article['url']}) (${dateFormat.format(publishedAt)})',
      );
    } else {
      articles.add(
        '  - [${article['title']}](${article['url']}) (${dateFormat.format(publishedAt)})',
      );
    }

    if (articles.length == 5) {
      break;
    }
  }

  final readme = File('README.md');
  String content = readme.readAsStringSync();

  readme.writeAsStringSync(
    _replaceFileContent(
      content,
      _myDevToArticlesSectionStart,
      _myDevToArticlesSectionEnd,
      '''\n${articles.join('\n')}\n''',
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

  final articles = <String>['- [Zenn.dev](https://zenn.dev/kato_shinya)'];

  final now = DateTime.now();
  final oneWeekAgo = now.subtract(Duration(days: 7));

  for (final Map<String, dynamic> article in json['articles']) {
    final publishedAt = DateTime.parse(article['published_at']);

    if (publishedAt.isAfter(oneWeekAgo) && publishedAt.isBefore(now)) {
      articles.add(
        '  - 🆕 [${article['title']}](https://zenn.dev${article['path']}) (${dateFormat.format(publishedAt)})',
      );
    } else {
      articles.add(
        '  - [${article['title']}](https://zenn.dev${article['path']}) (${dateFormat.format(publishedAt)})',
      );
    }
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
