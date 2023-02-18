import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:nasa/nasa.dart';
import 'package:twitter_api_v2/twitter_api_v2.dart' as v2;

const _myRankInGitHubSectionStart =
    '<!-- MY-RANK-IN-GITHUB:START - Do not remove or modify this section -->';
const _myRankInGitHubSectionEnd = '<!-- MY-RANK-IN-GITHUB:END -->';

const _myTweetSectionStart =
    '<!-- MY-TWEETS:START - Do not remove or modify this section -->';
const _myTweetSectionEnd = '<!-- MY-TWEETS:END -->';

const _myZennArticlesSectionStart =
    '<!-- MY-ZENN-ARTICLES:START - Do not remove or modify this section -->';
const _myZennArticlesSectionEnd = '<!-- MY-ZENN-ARTICLES:END -->';

const _apodSectionStart =
    '<!-- APOD:START - Do not remove or modify this section -->';
const _apodSectionEnd = '<!-- APOD:END -->';

Future<void> main(List<String> arguments) async {
  await _updateGitHubRanking();
  await _updateTweets();
  await _updateAPOD();
  await _updateZennArticles();
}

Future<void> _updateGitHubRanking() async {
  final readme = File('README.md');
  String content = readme.readAsStringSync();

  readme.writeAsStringSync(
    _replaceFileContent(
      content,
      _myRankInGitHubSectionStart,
      _myRankInGitHubSectionEnd,
      '''\n\n🤖 **Fun fact 1**: I'm currently [the ${await _getRankAsGitHubCommitter()} most active GitHub committer in Japan](https://commits.top/japan.html).</br>
🤖 **Fun fact 2**: I'm currently rated as [the ${await _getRankAsGitHubContributor()} most active GitHub contributor in Japan](https://commits.top/japan_public.html).</br>
🤖 **Fun fact 3**: I'm titled as **_Regular_** in [Twitter Forum](https://twittercommunity.com/u/kato_shinya/summary).\n\n''',
    ),
  );
}

Future<void> _updateTweets() async {
  final twitter = v2.TwitterApi(
    bearerToken: '',
    oauthTokens: v2.OAuthTokens(
      consumerKey: Platform.environment['TWITTER_CONSUMER_KEY']!,
      consumerSecret: Platform.environment['TWITTER_CONSUMER_SECRET']!,
      accessToken: Platform.environment['TWITTER_ACCESS_TOKEN']!,
      accessTokenSecret: Platform.environment['TWITTER_ACCESS_TOKEN_SECRET']!,
    ),
    retryConfig: v2.RetryConfig(
      maxAttempts: 10,
      onExecute: (event) => print(
        'Retry after ${event.intervalInSeconds} seconds... '
        '[${event.retryCount} times]',
      ),
    ),
  );

  final me = await twitter.users.lookupMe(
    userFields: [
      v2.UserField.username,
      v2.UserField.profileImageUrl,
    ],
  );

  final tweets = await twitter.tweets.lookupTweets(
    userId: me.data.id,
    maxResults: 5,
    expansions: [
      v2.TweetExpansion.attachmentsMediaKeys,
    ],
    tweetFields: [
      v2.TweetField.createdAt,
      v2.TweetField.attachments,
    ],
    mediaFields: [
      v2.MediaField.altText,
      v2.MediaField.url,
    ],
  );

  final tweetUIs = <String>[];
  for (final tweet in tweets.data) {
    tweetUIs.add('''\n> ![${me.data.name}'s avatar](${me.data.profileImageUrl})
[${me.data.name}](https://twitter.com/${me.data.username}) [@${me.data.username}](https://twitter.com/${me.data.username}) [${tweet.createdAt!.toUtc().toIso8601String()}](https://twitter.com/${me.data.username}/status/${tweet.id})
>
> ${_getTweetText(me.data, tweet, tweets.includes)}
>
> [Reply](https://twitter.com/intent/tweet?in_reply_to=${tweet.id})&emsp;[Retweet](https://twitter.com/intent/retweet?tweet_id=${tweet.id})&emsp;[Like](https://twitter.com/intent/favorite?tweet_id=${tweet.id})
''');
  }

  final readme = File('README.md');
  String content = readme.readAsStringSync();

  readme.writeAsStringSync(
    _replaceFileContent(
      content,
      _myTweetSectionStart,
      _myTweetSectionEnd,
      '\n---\n${tweetUIs.join('\n---\n')}\n---\n',
    ),
  );
}

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

String _getTweetText(
  final v2.UserData me,
  final v2.TweetData tweet,
  final v2.Includes? includes,
) {
  final textElements = _activateUserReference(
    _activateHashtags(tweet.text),
  ).split('\n');

  if (tweet.attachments != null) {
    final attachments = tweet.attachments!;

    if (attachments.mediaKeys != null) {
      for (final mediaKey in attachments.mediaKeys!) {
        for (final media in includes!.media!) {
          if (media.key == mediaKey) {
            textElements.add(
              '![${media.altText ?? 'No AltText'}](${media.url!})',
            );
          }
        }
      }
    }
  }

  return textElements.join('\n> ');
}

String _activateUserReference(final String text) {
  final activatedText = <String>[];

  final elements = text.split(' ');
  for (final element in elements) {
    if (element.startsWith('@')) {
      activatedText
          .add('[$element](https://twitter.com/${element.substring(1)})');
    } else {
      activatedText.add(element);
    }
  }

  return activatedText.join(' ');
}

String _activateHashtags(final String text) {
  final activatedText = <String>[];

  final elements = text.split(' ');
  for (final element in elements) {
    if (element.startsWith('#')) {
      activatedText.add(
          '[$element](https://twitter.com/hashtag/${element.substring(1)}?src=hashtag_click)');
    } else {
      activatedText.add(element);
    }
  }

  return activatedText.join(' ');
}

String _getCopyright(final APODData image) =>
    image.copyright != null ? '> &copy; ${image.copyright}' : '';
