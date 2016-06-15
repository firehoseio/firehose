path                = require("path")
webpack             = require("webpack")
CleanWebpackPlugin  = require("clean-webpack-plugin")
version             = require("./package.json").version

module.exports =
  entry:
    firehose: path.join(__dirname, "helpers", "webpack.coffee")
    vendor: ["jquery"]
  output:
    path: path.join(__dirname, "dist")
    filename: "[name].js"
  plugins: [
    new webpack.DefinePlugin(
      "process.env":
        NODE_ENV: '"webpack"'
      __VERSION__: JSON.stringify(version)
    )
    new webpack.optimize.CommonsChunkPlugin("vendor", "firehose.vendor.js")
    new CleanWebpackPlugin ["dist"], root: process.cwd()
  ]
  resolveLoader:
    root: path.join(__dirname, "node_modules")
  module:
    loaders: [
      {
        test: /\.coffee$/
        loader: "coffee-loader"
      }
      {
        test: /\.json$/
        loader: "json-loader"
      }
    ]
  resolve:
    extensions: ["", ".webpack.js", ".web.js", ".js", ".coffee"]
