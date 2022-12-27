import 'dart:io';

import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:twitter_api_v2/twitter_api_v2.dart';

const _myRankInGitHubSectionStart =
    '<!-- MY-RANK-IN-GITHUB:START - Do not remove or modify this section -->';
const _myRankInGitHubSectionEnd = '<!-- MY-RANK-IN-GITHUB:END -->';

const _myTweetSectionStart =
    '<!-- MY-TWEETS:START - Do not remove or modify this section -->';
const _myTweetSectionEnd = '<!-- MY-TWEETS:END -->';

Future<void> main(List<String> arguments) async {
  final twitter = TwitterApi(
    bearerToken: '',
    oauthTokens: OAuthTokens(
      consumerKey: Platform.environment['TWITTER_CONSUMER_KEY']!,
      consumerSecret: Platform.environment['TWITTER_CONSUMER_SECRET']!,
      accessToken: Platform.environment['TWITTER_ACCESS_TOKEN']!,
      accessTokenSecret: Platform.environment['TWITTER_ACCESS_TOKEN_SECRET']!,
    ),
    retryConfig: RetryConfig(
      maxAttempts: 10,
      onExecute: (event) => print(
        'Retry after ${event.intervalInSeconds} seconds... '
        '[${event.retryCount} times]',
      ),
    ),
  );

  final me = await twitter.users.lookupMe(
    userFields: [
      UserField.username,
      UserField.profileImageUrl,
    ],
  );

  final tweets = await twitter.tweets.lookupTweets(
    userId: me.data.id,
    maxResults: 5,
    tweetFields: [
      TweetField.createdAt,
    ],
  );

  final tweetUIs = <String>[];
  for (final tweet in tweets.data) {
    tweetUIs.add('''\n> ![${me.data.name}'s avatar](${me.data.profileImageUrl})
[${me.data.name}](https://twitter.com/${me.data.username}) [@${me.data.username}](https://twitter.com/${me.data.username}) [${tweet.createdAt!.toUtc().toIso8601String()}](https://twitter.com/${me.data.username}/status/${tweet.id})
>
> ${_getTweetText(tweet)}
>
> [Reply](https://twitter.com/intent/tweet?in_reply_to=${tweet.id})&emsp;[Retweet](https://twitter.com/intent/retweet?tweet_id=${tweet.id})&emsp;[Like](https://twitter.com/intent/favorite?tweet_id=${tweet.id})
''');
  }

  final readme = File('README.md');
  String content = readme.readAsStringSync();

  content = _replaceFileContent(
    content,
    _myTweetSectionStart,
    _myTweetSectionEnd,
    '\n---\n${tweetUIs.join('\n---\n')}\n---\n',
  );

  content = _replaceFileContent(
    content,
    _myRankInGitHubSectionStart,
    _myRankInGitHubSectionEnd,
    '''\n\n🤖 **Fun fact 1**: I'm currently [the ${await _getRankAsGitHubCommitter()} most active GitHub committer in Japan](https://commits.top/japan.html).</br>
🤖 **Fun fact 2**: I'm currently rated as [the ${await _getRankAsGitHubContributor()} most active GitHub contributor in Japan](https://commits.top/japan_public.html).</br>
🤖 **Fun fact 3**: I'm titled as **_Regular_** in [Twitter Forum](https://twittercommunity.com/u/kato_shinya/summary).\n\n''',
  );

  readme.writeAsStringSync(content);
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

String _getTweetText(final TweetData tweet) {
  return _activateHashtags(tweet.text).split('\n').join('\n> ');
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
