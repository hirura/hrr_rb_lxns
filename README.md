# HrrRbLxns

hrr_rb_lxns implements utilities working with Linux namespaces for CRuby.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hrr_rb_lxns'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install hrr_rb_lxns

## Usage

The basic usage is as follows.

```ruby
require "hrr_rb_lxns"

# Disassociates uts namespace
File.readlink "/proc/self/ns/uts"   # => uts:[aaa]
HrrRbLxns.unshare HrrRbLxns::NEWUTS # => 0
File.readlink "/proc/self/ns/uts"   # => uts:[xxx]

# Disassociates uts and mount namespaces
File.readlink "/proc/self/ns/uts"   # => uts:[aaa]
File.readlink "/proc/self/ns/mnt"   # => mnt:[bbb]
HrrRbLxns.unshare "um"              # => 0
File.readlink "/proc/self/ns/uts"   # => uts:[xxx]
File.readlink "/proc/self/ns/mnt"   # => mnt:[yyy]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hirura/hrr_rb_lxns. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/hirura/hrr_rb_lxns/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the HrrRbLxns project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/hirura/hrr_rb_lxns/blob/master/CODE_OF_CONDUCT.md).
