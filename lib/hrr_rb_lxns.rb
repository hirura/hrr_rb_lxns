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
  # @param options [Hash] For future use.
  # @return [Integer] 0.
  # @raise [ArgumentError] When given flags argument is not appropriate.
  # @raise [Errno::EXXX] In case setns(2) system call failed.
  def self.setns flags, pid, options={}
    _flags = interpret_flags flags
    fds = get_fds _flags, pid
    fds.each do |path, nstype|
      begin
        fd = File.open(path, File::RDONLY)
        __setns__ fd.fileno, nstype
      ensure
        fd.close rescue nil
      end
    end
  end

  def self.get_fds flags, pid
    list = Array.new
    list.push ["ipc",    NEWIPC   ] if const_defined?(:NEWIPC)
    list.push ["mnt",    NEWNS    ] if const_defined?(:NEWNS)
    list.push ["net",    NEWNET   ] if const_defined?(:NEWNET)
    list.push ["pid",    NEWPID   ] if const_defined?(:NEWPID)
    list.push ["uts",    NEWUTS   ] if const_defined?(:NEWUTS)
    list.push ["user",   NEWUSER  ] if const_defined?(:NEWUSER)
    list.push ["cgroup", NEWCGROUP] if const_defined?(:NEWCGROUP)
    list.push ["time",   NEWTIME  ] if const_defined?(:NEWTIME)
    fds = Array.new
    list.each do |name, flag|
      fd = get_fd name, (flags & flag), pid
      fds.push [fd, flag] if fd
    end
    fds
  end

  def self.get_fd name, flag, pid
    if flag.zero?.! && pid
      "/proc/#{pid}/ns/#{name}"
    else
      nil
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
end
