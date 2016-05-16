# Firehose Protocol

Firehose streams a sequence of messages from the server to the client. When the client recieves a message, it makes a request to the server with the `last_sequence` of the latest message received. If the server has the message it responds immediatly with the message. If the server doesn't have the message it subscribes the client to a pub/sub stream. When the message is published to Firehose, it is published to the subscribers.

## Transports

Firehose has two transports: WebSockets and HTTP long polling. Firehose streams a sequence of messages over these transports.

## Messages

A message consists of a payload and a sequence:

* **message** (String) - Contents of the message. For example, this may be stringified JSON from your application or it could just be plain text.
* **last_sequence** (Integer) - The order of the message. Starts at `1` and increments by 1. The sequence is used by the server and the client to detect if and when messages are dropped.

## Channels

Firehose streams messages over channels.

### Single resource channel

The message may be encoded in JSON as:

```json
{
  "message": "Hello there",
  "last_sequence": 1
}
```

or as an HTTP payload:

```
GET /resources/1 HTTP/1.1
Host: firehose.io
User-Agent: curl/7.43.0
Accept: */*
Content-Length: 11
Content-Type: application/x-www-form-urlencoded
Firehose-Last-Sequence: 1

Hello there
```

### Multiplexed resources channel

When consuming multiple channels, it may be more efficient to open one connection to subscribe to many channels. Firehose can stream multiple channels over one connection using multiplexing.

## Consumer

## Publisher
