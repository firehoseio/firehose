if ("webpack" != process.env.NODE_ENV) {
  require("coffee-script/register");
}
module.exports = require("./lib/firehose");
