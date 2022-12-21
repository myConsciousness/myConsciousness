import 'dart:io';

import 'package:twitter_api_v2/twitter_api_v2.dart';

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
> ${tweet.text}
>
> [Reply](https://twitter.com/intent/tweet?in_reply_to=${tweet.id})&emsp;[Retweet]](https://twitter.com/intent/retweet?tweet_id=${tweet.id})emsp;[Like](https://twitter.com/intent/favorite?tweet_id=${tweet.id})
''');
  }

  final readme = File('README.md');
  final content = readme.readAsStringSync();

  readme.writeAsStringSync(content.replaceRange(
    content.indexOf(_myTweetSectionStart) + _myTweetSectionStart.length,
    content.indexOf(_myTweetSectionEnd),
    '${tweetUIs.join('\n---\n')}\n**_Last Updated at ${DateTime.now().toUtc().toIso8601String()}_**\n',
  ));
}
