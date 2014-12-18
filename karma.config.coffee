# Karma configuration
# Generated on Mon Jul 07 2014 12:32:37 GMT-0700 (PDT)
module.exports = (config) ->
  config.set
    # base path that will be used to resolve all patterns (eg. files, exclude)
    basePath: ""

    # frameworks to use
    # available frameworks: https://npmjs.org/browse/keyword/karma-adapter
    frameworks: [
      "sprockets-mincer"
      "jasmine"
    ]

    # list of files / patterns to load in the browser
    files: []

    # list of files to exclude
    exclude: []

    # preprocess matching files before serving them to the browser
    # available preprocessors: https://npmjs.org/browse/keyword/karma-preprocessor
    preprocessors:
      "**/*.coffee": ["coffee"]

    # test results reporter to use
    # possible values: 'dots', 'progress'
    # available reporters: https://npmjs.org/browse/keyword/karma-reporter
    reporters: ["progress", "dots"]

    # web server port
    port: 9876

    # enable / disable colors in the output (reporters and logs)
    colors: true

    # level of logging
    # possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO

    # enable / disable watching file and executing tests whenever any file changes
    autoWatch: true

    # start these browsers
    # available browser launchers: https://npmjs.org/browse/keyword/karma-launcher
    browsers: ["Chrome", "PhantomJS"]

    # Continuous Integration mode
    # if true, Karma captures browsers, runs the tests and exits
    singleRun: false

    plugins: [
      "karma-jasmine"
      "karma-chrome-launcher"
      "karma-coffee-preprocessor"
      "karma-sprockets-mincer"
      "karma-phantomjs-launcher"
      "karma-junit-reporter"
    ]

    sprocketsPaths: [
      "lib/assets/javascripts"
      "spec/javascripts"
    ]

    sprocketsBundles: [
      "support/spec_helper.coffee"
      "firehose.js.coffee"
    ]

    # The spec files to run and watch changes for
    files: [
      'spec/javascripts/**/*_spec.coffee'
    ]

    junitReporter: {
      outputFile: 'tmp/spec-results.xml',
      suite: ''
    }

    coffeePreprocessor:
      # options passed to the coffee compiler
      options:
        bare: true
        sourceMap: false

      # transforming the filenames
      transformPath: (path) ->
        path.replace /\.js\.coffee$/, ".js"