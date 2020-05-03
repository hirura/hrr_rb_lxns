module HrrRbLxns

  # Represents namespace files information in /proc/PID/ns/ directory of a process.
  #
  # @example
  #   # Collects the caller process's or a specific process's namespace files information
  #   files = HrrRbLxns::Files.new
  #   files = HrrRbLxns::Files.new 12345
  #
  #   # Each namespace file is accessible as a method or a Hash-like key
  #   files.uts.path    # => "/proc/12345/ns/uts"
  #   files[:uts].path  # => "/proc/12345/ns/uts"
  #   files["uts"].path # => "/proc/12345/ns/uts"
  class Files
    include Enumerable

    # Returns the file information of attribute :mnt.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :mnt

    # Returns the file information of attribute :uts.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :uts

    # Returns the file information of attribute :ipc.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :ipc

    # Returns the file information of attribute :net.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :net

    # Returns the file information of attribute :pid.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :pid

    # Returns the file information of attribute :pid_for_children.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :pid_for_children

    # Returns the file information of attribute :user.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :user

    # Returns the file information of attribute :cgroup.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :cgroup

    # Returns the file information of attribute :time.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :time

    # Returns the file information of attribute :time_for_children.
    #
    # @return [HrrRbLxns::Files::File]
    #
    attr_reader :time_for_children

    # @param pid [Integer] The pid of a process to collect namespace files information. If nil, uses the caller process's pid.
    #
    def initialize pid=nil
      pid ||= Process.pid
      @mnt               = File.new "/proc/#{pid}/ns/mnt"
      @uts               = File.new "/proc/#{pid}/ns/uts"
      @ipc               = File.new "/proc/#{pid}/ns/ipc"
      @net               = File.new "/proc/#{pid}/ns/net"
      @pid               = File.new "/proc/#{pid}/ns/pid"
      @pid_for_children  = File.new "/proc/#{pid}/ns/pid_for_children"
      @user              = File.new "/proc/#{pid}/ns/user"
      @cgroup            = File.new "/proc/#{pid}/ns/cgroup"
      @time              = File.new "/proc/#{pid}/ns/time"
      @time_for_children = File.new "/proc/#{pid}/ns/time_for_children"
    end

    # Returns the file information of the specified key.
    #
    # @example
    #   files = HrrRbLxns::Files.new 12345
    #   files[:uts].path  # => "/proc/12345/ns/uts"
    #   files["uts"].path # => "/proc/12345/ns/uts"
    #
    # @param key [Symbol,String] The namespace file name, which is :mnt, :uts, pid, :pid_for_children, ....
    # @return [HrrRbLxns::Files::File]
    #
    def [] key
      __send__ key
    end

    # Calls the given block once for each key with associated file information.
    # If no block is given, an Enumerator is returned.
    #
    # @example
    #   files = HrrRbLxns::Files.new 12345
    #   files.each do |type, namespace_file|
    #     # at first iteration
    #     type                # => :cgroup
    #     namespace_file.path # => "/proc/12345/ns/cgroup"
    #   end
    #
    def each
      keys_with_files = [:mnt, :uts, :ipc, :net, :pid, :pid_for_children, :user, :cgroup, :time, :time_for_children].map{ |key| [key, __send__(key)] }
      if block_given?
        keys_with_files.each do |kv|
          yield kv
        end
      else
        keys_with_files.each
      end
    end
  end
end

require "hrr_rb_lxns/files/file"
