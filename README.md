# S3encrypt

This Gem allows the encrypted upload or download of files from S3.
It's the gemified version of https://github.com/DonMills/ruby-KMS-S3
## Installation

Add this line to your application's Gemfile:

```ruby
gem 's3encrypt'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install s3encrypt

## Usage

```ruby
require 's3encrypt'
S3encrypt.putfile("local_filename", "remote_filename", "bucket", "context", "masterkmskey")
S3encrypt.getfile("local_filename", "remote_filename", "bucket", "context")
```

To do kms managed SSE:

```ruby
S3encrypt.putfile_ssekms("local_filename", "remote_filename", "bucket", "context", "masterkmskey")
```

To do S3 managed SSE:

```ruby
S3encrypt.putfile_sses3("local_filename", "remote_filename", "bucket", "context", "masterkmskey")
```

When Using EC2 roles:

Don't forget to set the region (usually as an environment variable) as the SDK will not extrapolate it from the metadata...

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/DonMills/s3encrypt.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

