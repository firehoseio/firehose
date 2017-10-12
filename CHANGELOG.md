## master

- Allow passing custom HTTP headers to the Firehose::Client::Producer::Http which can be useful for things like passing along request trace headers

## 1.4.3
- Track errors and timeouts in metrics (type of error/timeout per channel and global error/timeout count)

## 1.4.2
- Ensure firehose server port is an integer and parsed correctly

## 1.4.1
- Fixed duplicate call to Rack async.callback which caused the server to send a PUT request response twice

## 1.4.0
- Update faraday gem (old version had a bug that could cause our specs to fail)
- Added metrics for channel & global events & expose them via HTTP as JSON at /metrics@firehose
- Lock down dependency version to prevent build failure & fix code climate reporter to work with latest version in travis build.
- Add support for defining & detecting deprecated channels that cause subscriptions and publishes to those channels to be logged.
- Add support for persisting channels & messages.

## 1.3.9
- Bugfix: Prevent channel sequence of 0 when there's messages buffered.

## 1.3.8
- Fix params parsing for multiplexed subscriptions
- Fix http long poll spec related to params parsing

## 1.3.7
- Configuration of Redis via the `Firehose::Server.redis` object.
- Less rubygem dependencies: JSON gem removed because its included in Ruby 2.x
- DEPRECATED: `firehose javascript` command will be removed. Those have been moved to https://github.com/firehoseio/js_client.
- Add support for per-subscriber message filtering via `Firehose::Server::MessageFilter` interface
- Add `Firehose::Server::ChannelSubscription::Failed` Exception which can be raised by custom message filters to abort a channel subscription and return an error to the client.

## 1.3.6

- DEPRECATION WARNING: `firehose javascript` has been removed from this project.
- BUG: The null message bug fix in 1.3.5 introduce different behavior into the messages delivered when a client reconnects with a last_sequence. This has been corrected and 1.3.5 will be yanked.

## 1.3.5

- Fix bug where null messages are sent over WebSockets to client. Issue https://github.com/firehoseio/firehose/issues/51.
- Drop support for Ruby 1.9.3. Documented official Ruby support policy in README.md
