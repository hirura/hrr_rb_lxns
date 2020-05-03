# HrrRbLxns

[![Build Status](https://travis-ci.com/hirura/hrr_rb_lxns.svg?branch=master)](https://travis-ci.com/hirura/hrr_rb_lxns)
[![Gem Version](https://badge.fury.io/rb/hrr_rb_lxns.svg)](https://badge.fury.io/rb/hrr_rb_lxns)

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

hrr_rb_lxns provides unshare and setns wrappers, and namespace files information collector.

### Unshare

HrrRbLxns.unshare method wraps around unshare(2) system call. The system call disassociates the caller process's namespace.

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

HrrRbLxns.unshare supports creating persistent namespaces files by bind-mount. The files are specified in an options hash. The keys which are available in the hash for each namespace are `:mount`, `:uts`, `:ipc`, `:network`, `:pid`, `:user`, `:cgroup`, and `:time`.
Note that files that namespaces are bind-mounted must exist. The library does just bind-mount, not create the files. And the files and their mount information are kept after the caller process is finished.
When unsharing pid namespace, the namespace file should be bind-mounted against the caller's child process. For this case, `:fork` option is supported.

```ruby
File.readlink "/proc/self/ns/uts"            # => uts:[aaa]
# Prepare an options hash to specify a file that namespaces are bind-mounted
options = {:uts => "/path/to/myns/uts"}
HrrRbLxns.unshare HrrRbLxns::NEWUTS, options # => 0
File.readlink "/proc/self/ns/uts"            # => uts:[xxx]
File.stat(options[:uts]).ino                 # => xxx

# For mount namespace, the parent directory's propagation needs to be private
FileUtils.mkdir "/path/to/myns"
HrrRbMount.bind "/path/to/myns" "/path/to/myns"
HrrRbMount.make_private "/path/to/myns"
FileUtils.touch "/path/to/myns/mnt"
options = {:mount => "/path/to/myns/mnt"}
HrrRbLxns.unshare HrrRbLxns::NEWNS, options # => 0

# For pid namespace, :fork option is available
options = {:pid => "/path/to/myns/pid", :fork => true}
# .unshare method with :fork option works like Kernel.#fork after unshare(2)
if pid = HrrRbLxns.unshare HrrRbLxns::NEWPID, options
  # In parent, .unshare returns the child process's PID (In this case, it is 1 because unsharing PID namespace)
  # Do something
  Process.waitpid pid
else
  # In child, .unshare returns nil
  # Do something
end
```

### Setns

HrrRbLxns.setns method wraps around setns(2) system call. The system call associate the caller process's namespace to an existing one, which is disassociated by some other process.

```ruby
# Before doing setns, prepare a disassociated namespace with using unshare.
# The unshare(2) system call disassociate the caller process's namespace, so
# do fork the process and unshare in the child process.
# To keep the disassociated namespase, do sleep at last in the child.
pid = fork do
  # Disassociates uts namespace
  File.readlink "/proc/self/ns/uts"    # => uts:[xxx]
  HrrRbLxns.unshare HrrRbLxns::NEWUTS  # => 0
  File.readlink "/proc/self/ns/uts"    # => uts:[yyy]
  sleep
end

# Aassociates uts namespace
File.readlink "/proc/self/ns/uts"      # => uts:[xxx]
HrrRbLxns.setns HrrRbLxns::NEWUTS, pid # => 0
File.readlink "/proc/self/ns/uts"      # => uts:[yyy]
```

HrrRbLxns.setns can associate namespaces using files which specify namespaces, instead of specifying pid. The files are specified in an options hash. The keys which are available in the hash for each namespace are `:mount`, `:uts`, `:ipc`, `:network`, `:pid`, `:user`, `:cgroup`, and `:time`.

```ruby
# Create a network namespace using the ip netns command. The command generates "/run/netns/ns0" file, which is a bind-mounted namespace file.
system "ip netns add ns0"
# Then associate with the network namespace with specifying the file instead of pid.
HrrRbLxns.setns HrrRbLxns::NETNET, nil, {network: "/run/netns/ns0"}
```

### Files

HrrRbLxns.files Collects the caller process's or a specific process's namespace files information, which are the file path and its inode number.

```ruby
# Collects the caller process's namespace files information
files = HrrRbLxns.files
# Collects a specific process's namespace files information
files = HrrRbLxns.files 12345

# Then, paths and their inode numbers are accesible
files.uts.path    # => "/proc/12345/ns/uts"
files[:ipc].ino   # => 4026531839
files["net"].ino  # => 4026531840
```

## Note

Some of the namespace operations are not multi-thread friendly. The library expects that only main thread is running before unshare or setns operation.

In particular, note that there are some limitations on the use of the library with Ruby version 2.5.x or earlier. This is because of the background timer thread of Ruby.

- Unshare user namespace (with NEWUSER flag) on Ruby 2.5.x or earlier fails.
- Unshare pid namespace (with NEWPID flag) then Kernel.#fork on Ruby 2.5.x or earlier gets a timer thread related warning.
- Unshare pid namespace (with NEWPID flag) then Kernel.#fork on Ruby 2.2.x or earlier fails.
- Setns user namespace (with NEWUSER flag) on Ruby 2.5.x or earlier fails.
- Setns pid namespace (with NEWPID flag) then Kernel.#fork on Ruby 2.5.x or earlier gets a timer thread related warning.
- Setns pid namespace (with NEWPID flag) then Kernel.#fork on Ruby 2.2.x or earlier fails.
- Setns mount namespace (with NEWNS flag) on Ruby 2.5.x or earlier fails.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hirura/hrr_rb_lxns. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/hirura/hrr_rb_lxns/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the HrrRbLxns project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/hirura/hrr_rb_lxns/blob/master/CODE_OF_CONDUCT.md).
