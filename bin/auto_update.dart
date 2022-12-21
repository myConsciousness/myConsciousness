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
    tweetUIs.add('''\n> [![${me.data.name}'s avatar](${me.data.profileImageUrl})
[${me.data.name}](https://twitter.com/${me.data.username}) [@${me.data.username}](https://twitter.com/${me.data.username}) [${tweet.createdAt!.toUtc().toIso8601String()}](https://twitter.com/${me.data.username}/status/${tweet.id})
>
> ${tweet.text}
>
> [![Reply](./images/reply_light.svg#gh-light-mode-only 'Reply')](https://twitter.com/intent/tweet?in_reply_to=${tweet.id}#gh-light-mode-only)[![Reply](./images/reply.svg#gh-dark-mode-only 'Reply')](https://twitter.com/intent/tweet?in_reply_to=${tweet.id}#gh-dark-mode-only)&emsp;[![Retweet](./images/retweet_light.svg#gh-light-mode-only 'Retweet')](https://twitter.com/intent/retweet?tweet_id=${tweet.id}#gh-light-mode-only)[![Retweet](./images/retweet.svg#gh-dark-mode-only 'Retweet')](https://twitter.com/intent/retweet?tweet_id=${tweet.id}#gh-dark-mode-only)&emsp;[![Like](./images/like_light.svg#gh-light-mode-only 'Like')](https://twitter.com/intent/favorite?tweet_id=${tweet.id}#gh-light-mode-only)[![Like](./images/like.svg#gh-dark-mode-only 'Like')](https://twitter.com/intent/favorite?tweet_id=${tweet.id}#gh-dark-mode-only)
''');
  }

  final readme = File('README.md');
  final content = readme.readAsStringSync();

  readme.writeAsStringSync(content.replaceRange(
    content.indexOf(_myTweetSectionStart) + _myTweetSectionStart.length,
    content.indexOf(_myTweetSectionEnd),
    '${tweetUIs.join('\n---\n')}\nLast Updated at ${DateTime.now().toUtc().toIso8601String()}\n',
  ));
}
