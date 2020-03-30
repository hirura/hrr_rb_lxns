require "hrr_rb_lxns/version"
require "hrr_rb_lxns/hrr_rb_lxns"

# Utilities working with Linux namespaces for CRuby.
module HrrRbLxns

  # Constants that represent the flags for Linux namespaces operations.
  module Constants
  end

  # A wrapper around unshare(2) system call.
  #
  # @example
  #   # Disassociates uts namespace
  #   File.readlink "/proc/self/ns/uts"   # => uts:[aaa]
  #   HrrRbLxns.unshare HrrRbLxns::NEWUTS # => 0
  #   File.readlink "/proc/self/ns/uts"   # => uts:[xxx]
  #
  #   # Disassociates uts and mount namespaces
  #   File.readlink "/proc/self/ns/uts"   # => uts:[aaa]
  #   File.readlink "/proc/self/ns/mnt"   # => mnt:[bbb]
  #   HrrRbLxns.unshare "um"              # => 0
  #   File.readlink "/proc/self/ns/uts"   # => uts:[xxx]
  #   File.readlink "/proc/self/ns/mnt"   # => mnt:[yyy]
  #
  # @param flags [Integer] An integer value that represents namespaces to disassociate.
  # @param flags [String] A string that represents namespaces. The mapping of charactors and flags are: <br>
  #   "i" : NEWIPC <br>
  #   "m" : NEWNS <br>
  #   "n" : NEWNET <br>
  #   "p" : NEWPID <br>
  #   "u" : NEWUTS <br>
  #   "U" : NEWUSER <br>
  #   "C" : NEWCGROUP <br>
  #   "T" : NEWTIME <br>
  # @param options [Hash] For future use.
  # @return [Integer] 0.
  # @raise [ArgumentError] When given flags argument is not appropriate.
  # @raise [Errno::EXXX] In case unshare(2) system call failed.

  def self.unshare flags, options={}
    _flags = interpret_flags flags
    __unshare__ _flags
  end

  # A wrapper around setns(2) system call.
  #
  # @example
  #   pid = fork do
  #     # Disassociates uts namespace
  #     File.readlink "/proc/self/ns/uts"    # => uts:[xxx]
  #     HrrRbLxns.unshare HrrRbLxns::NEWUTS  # => 0
  #     File.readlink "/proc/self/ns/uts"    # => uts:[yyy]
  #     sleep
  #   end
  #   # Aassociates uts namespace
  #   File.readlink "/proc/self/ns/uts"      # => uts:[xxx]
  #   HrrRbLxns.setns HrrRbLxns::NEWUTS, pid # => 0
  #   File.readlink "/proc/self/ns/uts"      # => uts:[yyy]
  #
  # @param flags [Integer] An integer value that represents namespaces to disassociate.
  # @param flags [String] A string that represents namespaces. The mapping of charactors and flags are: <br>
  #   "i" : NEWIPC <br>
  #   "m" : NEWNS <br>
  #   "n" : NEWNET <br>
  #   "p" : NEWPID <br>
  #   "u" : NEWUTS <br>
  #   "U" : NEWUSER <br>
  #   "C" : NEWCGROUP <br>
  #   "T" : NEWTIME <br>
  # @param pid [Integer] Specifies a target process('s namespace) which the caller is to associate with. The paths specifying namespaces specified by pid are: <br>
  #   /proc/pid/ns/mnt :    mount namespace <br>
  #   /proc/pid/ns/uts :    uts namespace <br>
  #   /proc/pid/ns/ipc :    ipc namespace <br>
  #   /proc/pid/ns/net :    network namespace <br>
  #   /proc/pid/ns/pid :    pid namespace <br>
  #   /proc/pid/ns/user :   user namespace <br>
  #   /proc/pid/ns/cgroup : cgroup namespace <br>
  #   /proc/pid/ns/time :   time namespace <br>
  # @param options [Hash]
  # @option options [String] :mount A file which specifies the mount namespace to associate with.
  # @option options [String] :uts A file which specifies the uts namespace to associate with.
  # @option options [String] :ipc A file which specifies the ipc namespace to associate with.
  # @option options [String] :network A file which specifies the network namespace to associate with.
  # @option options [String] :pid A file which specifies the pid namespace to associate with.
  # @option options [String] :user A file which specifies the user namespace to associate with.
  # @option options [String] :cgroup A file which specifies the cgroup namespace to associate with.
  # @option options [String] :time A file which specifies the time namespace to associate with.
  # @return [Integer] 0.
  # @raise [ArgumentError] When given flags argument is not appropriate or when given pid and/or options are not appropriate for the given flags.
  # @raise [Errno::EXXX] In case setns(2) system call failed.
  def self.setns flags, pid, options={}
    _flags = interpret_flags flags
    files = get_files _flags, pid, options
    files.each do |path, nstype|
      begin
        file = File.open(path, File::RDONLY)
        __setns__ file.fileno, nstype
      ensure
        file.close rescue nil
      end
    end
  end

  private

  def self.interpret_flags arg
    case arg
    when Integer then arg
    when String  then chars_to_flags arg
    else raise TypeError, "unsupported flags: #{arg.inspect}"
    end
  end

  def self.chars_to_flags chars
    chars.each_char.inject(0) do |f, c|
      if    c == "i" && const_defined?(:NEWIPC)    then f | NEWIPC
      elsif c == "m" && const_defined?(:NEWNS)     then f | NEWNS
      elsif c == "n" && const_defined?(:NEWNET)    then f | NEWNET
      elsif c == "p" && const_defined?(:NEWPID)    then f | NEWPID
      elsif c == "u" && const_defined?(:NEWUTS)    then f | NEWUTS
      elsif c == "U" && const_defined?(:NEWUSER)   then f | NEWUSER
      elsif c == "C" && const_defined?(:NEWCGROUP) then f | NEWCGROUP
      elsif c == "T" && const_defined?(:NEWTIME)   then f | NEWTIME
      else raise ArgumentError, "unsupported flag charactor: #{c.inspect}"
      end
    end
  end

  def self.get_files flags, pid, options
    list = Array.new
    list.push ["ipc",    NEWIPC,    :ipc    ] if const_defined?(:NEWIPC)
    list.push ["mnt",    NEWNS,     :mount  ] if const_defined?(:NEWNS)
    list.push ["net",    NEWNET,    :network] if const_defined?(:NEWNET)
    list.push ["pid",    NEWPID,    :pid    ] if const_defined?(:NEWPID)
    list.push ["uts",    NEWUTS,    :uts    ] if const_defined?(:NEWUTS)
    list.push ["user",   NEWUSER,   :user   ] if const_defined?(:NEWUSER)
    list.push ["cgroup", NEWCGROUP, :cgroup ] if const_defined?(:NEWCGROUP)
    list.push ["time",   NEWTIME,   :time   ] if const_defined?(:NEWTIME)
    files = Array.new
    list.each do |name, flag, key|
      file = get_file name, (flags & flag), pid, key, options[key]
      files.push [file, flag] if file
    end
    files
  end

  def self.get_file name, flag, pid, key, option
    if flag.zero?.!
      if option
        option
      elsif pid
        "/proc/#{pid}/ns/#{name}"
      else
        raise ArgumentError, "neither pid nor options[:#{key}] specified for #{key} namespace"
      end
    else
      nil
    end
  end
end
