# Firehose Protocol 2.0

This is an attempt to document the protocol and behavior of Firehose.

## Consumer

The consumer subscribes to a firehose channel to recieve a sequence of messages. Each message has a `sequence`, which is used by the client to recieved messages that may have been published while it was disconnected.

Firehose does not garauntee that all missing messages will be delivered. This usually happens if the client is "under water" struggling to keep up. This behavior is also very desirable in situations where old messages that are published are not of importance to the client.

The consumer client has the capabilities to detect if messages were dropped; thus, its the clients responisbility to fill the missing messages. For example, if a message is dropped, the client may request a collection of that data from a RESTful web service to fill the gap.

### Subscription message

A consumer may subscribe with the following message format:

```json
{
  "channel": "/the/channel",
  "metadata": {},              // Metadata may only be 1 level deep.
  "last_sequence": 0           // Sequence of the last message recieved.
}
```

`channel` - The name of the channel the client is subscribing to for messages.
`metadata` - may only be one level deep. This data is intended to be used by user-specified Firehose Channel middleware.
`last_sequence` - Last message sequence recieved by the client when the channel was subscribed. This is used by Firehose to give the client messages it may have missed while being disconnected.
