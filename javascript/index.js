if ("webpack" != process.env.NODE_ENV) {
  require("coffee-script/register");
  __VERSION__ = require("../helpers/node").version
}

exports = module.exports = require("./lib/firehose");
exports.version = __VERSION__;
