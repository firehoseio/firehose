## 1.3.6

- Configuration of Redis via the `Firehose::Server.redis` object.
- Less rubygem dependencies: JSON gem removed because its included in Ruby 2.x
- DEPRECATED: `firehose javascript` command will be removed. Those have been moved to https://github.com/firehoseio/js_client.

## 1.3.5

- Fix bug where null messages are sent over WebSockets to client. Issue https://github.com/firehoseio/firehose/issues/51.
- Drop support for Ruby 1.9.3. Documented official Ruby support policy in README.md
