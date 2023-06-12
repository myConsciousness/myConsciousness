import 'dart:convert';
import 'dart:io';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:nasa/nasa.dart';

// const _myRankInGitHubSectionStart =
//     '<!-- MY-RANK-IN-GITHUB:START - Do not remove or modify this section -->';
// const _myRankInGitHubSectionEnd = '<!-- MY-RANK-IN-GITHUB:END -->';

const _myBskyTimelineSectionStart =
    '<!-- MY-BSKY_TIMELINE:START - Do not remove or modify this section -->';
const _myBskyTimelineSectionEnd = '<!-- MY-BSKY_TIMELINE:END -->';

const _myZennArticlesSectionStart =
    '<!-- MY-ZENN-ARTICLES:START - Do not remove or modify this section -->';
const _myZennArticlesSectionEnd = '<!-- MY-ZENN-ARTICLES:END -->';

const _apodSectionStart =
    '<!-- APOD:START - Do not remove or modify this section -->';
const _apodSectionEnd = '<!-- APOD:END -->';

Future<void> main(List<String> arguments) async {
  // await _updateGitHubRanking();
  await _updateBlueskyTimeline();
  // await _updateAPOD();
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

// Future<void> _updateGitHubRanking() async {
//   final readme = File('README.md');
//   String content = readme.readAsStringSync();

//   readme.writeAsStringSync(
//     _replaceFileContent(
//       content,
//       _myRankInGitHubSectionStart,
//       _myRankInGitHubSectionEnd,
//       '''\n\n🤖 **Fun fact 1**: I'm currently [the ${await _getRankAsGitHubCommitter()} most active GitHub committer in Japan](https://commits.top/japan.html).</br>
// 🤖 **Fun fact 2**: I'm currently rated as [the ${await _getRankAsGitHubContributor()} most active GitHub contributor in Japan](https://commits.top/japan_public.html).</br>
// 🤖 **Fun fact 3**: I'm described in [Wikipedia](https://ja.wikipedia.org/wiki/加藤真也_(プログラマ)).\n\n''',
//     ),
//   );
// }

Future<void> _updateAPOD() async {
  final nasa = NasaApi(token: Platform.environment['NASA_APIS_TOKEN']!);

  final image = await nasa.apod.lookupImage();

  final readme = File('README.md');
  String content = readme.readAsStringSync();

  readme.writeAsStringSync(
    _replaceFileContent(
      content,
      _apodSectionStart,
      _apodSectionEnd,
      '''\n---\n
> ${image.data.description}
> ![APOD](${image.data.url})
${_getCopyright(image.data)}
\n---\n''',
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

  final articles = <String>[];
  for (final Map<String, dynamic> article in json['articles']) {
    final publishedAt = DateTime.parse(article['published_at']);

    articles.add(
      '- ${article['emoji']} [${article['title']}](https://zenn.dev${article['path']}) (${dateFormat.format(publishedAt)})',
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

Future<String> _getRankAsGitHubCommitter() async {
  final response = await get(Uri.https('commits.top', '/japan.html'));

  return _getRank(response.body);
}

Future<String> _getRankAsGitHubContributor() async {
  final response = await get(Uri.https('commits.top', '/japan_public.html'));

  return _getRank(response.body);
}

String _getRank(final String html) {
  final document = parse(html);

  for (final element in document.body!.querySelectorAll('tr')) {
    if (element.innerHtml.contains('https://github.com/myConsciousness')) {
      final rank = element.querySelector('td')!.innerHtml;

      return _getRankWithUnit(rank.substring(0, rank.indexOf('.')));
    }
  }

  return 'N/A';
}

String _getRankWithUnit(final String rank) {
  if (rank.endsWith('1')) {
    return '${rank}st';
  } else if (rank.endsWith('2')) {
    return '${rank}nd';
  } else if (rank.endsWith('3')) {
    return '${rank}rd';
  }

  return '${rank}th';
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

String _getCopyright(final APODData image) =>
    image.copyright != null ? '> &copy; ${image.copyright}' : '';
