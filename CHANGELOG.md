## master

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
