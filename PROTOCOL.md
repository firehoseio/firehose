## Protocol

Firehose is designed to publish messages to flakey clients. Each message is published to the client with a sequence number. If the client gets disconnected it reconnects to Firehose with the last sequence number and tries to obtain the remaining messages.

### HTTP Long Polling

For clients that don't support web sockets, HTTP long polling may be utilized to recieve messages from Firehose.

#### Single

A single HTTP long polling connection subsribes to a channel via an HTTP request:

```
GET /my/channel/name?last_message_sequence=1&whisky=tango
```

The `last_message_sequence` parameter is used by Firehose reply messages to the client that may have been published while the client was disconnected.

All other query parameters are passed into the channel as channel params.

#### Multiplexing

A client may listen for messages from multiple Firehose channels over one HTTP connection. The client initiates the connection via:

```
POST /channels@firehose

{
  "/my/channel": "1",
  "/another/channel": "2"
}
```

To subscribe to multiple channels with params over long polling, the following format may be utilized:

```
POST /channels@firehose

{
  "/my/channel": {
    "last_message_sequence": "1",
    "whisky": "tango"
  },
  "/another/channel": {
    "last_message_sequence": "2",
    "hotel": "foxtrot"
  }
}
```

The key is the channel name and the value is the current message sequence of the message.
