require "hrr_rb_lxns/version"
require "hrr_rb_lxns/hrr_rb_lxns"
require "hrr_rb_lxns/files"
require "hrr_rb_mount"

# Utilities working with Linux namespaces for CRuby.
module HrrRbLxns

  # Constants that represent the flags for Linux namespaces operations.
  module Constants
  end

  @@namespaces = Hash.new
  @@namespaces["mnt"]    = {char: "m", flag: NEWNS,     key: :mount,   file_to_bind: "mnt"              }.freeze if const_defined? :NEWNS
  @@namespaces["uts"]    = {char: "u", flag: NEWUTS,    key: :uts,     file_to_bind: "uts"              }.freeze if const_defined? :NEWUTS
  @@namespaces["ipc"]    = {char: "i", flag: NEWIPC,    key: :ipc,     file_to_bind: "ipc"              }.freeze if const_defined? :NEWIPC
  @@namespaces["net"]    = {char: "n", flag: NEWNET,    key: :network, file_to_bind: "net"              }.freeze if const_defined? :NEWNET
  @@namespaces["pid"]    = {char: "p", flag: NEWPID,    key: :pid,     file_to_bind: "pid_for_children" }.freeze if const_defined? :NEWPID
  @@namespaces["user"]   = {char: "U", flag: NEWUSER,   key: :user,    file_to_bind: "user"             }.freeze if const_defined? :NEWUSER
  @@namespaces["cgroup"] = {char: "C", flag: NEWCGROUP, key: :cgroup,  file_to_bind: "cgroup"           }.freeze if const_defined? :NEWCGROUP
  @@namespaces["time"]   = {char: "T", flag: NEWTIME,   key: :time,    file_to_bind: "time_for_children"}.freeze if const_defined? :NEWTIME
  @@namespaces.freeze

  # Collects namespace files information in /proc/PID/ns/ directory of a process.
  #
  # @example
  #   # Collects the caller process's or a specific process's namespace files information
  #   files = HrrRbLxns.files
  #   files = HrrRbLxns.files 12345
  #   files.uts.path # => "/proc/12345/ns/uts"
  #
  # @param pid [Integer,String] The pid of a process to collect namespace files information. If nil, assumes that it is the caller process.
  # @return [HrrRbLxns::Files]
  def self.files pid="self"
    Files.new pid
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
  # @param options [Hash] Optional arguments.
  # @option options [String] :mount   A persistent mount namespace to be created by bind mount.
  # @option options [String] :uts     A persistent uts namespace to be created by bind mount.
  # @option options [String] :ipc     A persistent ipc namespace to be created by bind mount.
  # @option options [String] :network A persistent network namespace to be created by bind mount.
  # @option options [String] :pid     A persistent pid namespace to be created by bind mount.
  # @option options [String] :user    A persistent user namespace to be created by bind mount.
  # @option options [String] :cgroup  A persistent cgroup namespace to be created by bind mount.
  # @option options [String] :time    A persistent time namespace to be created by bind mount.
  # @option options [Boolean] :fork If specified, the caller process forks after unshare.
  # @option options [String,Array<String>,Array<#to_i>,Array<Array<#to_i>>] :map_uid If specified, the caller process writes UID map in /proc/PID/uid_map.
  # @option options [String,Array<String>,Array<#to_i>,Array<Array<#to_i>>] :map_gid If specified, the caller process writes deny in /proc/PID/setgroups and GID map in /proc/PID/gid_map.
  # @option options [Numeric,String] :monotonic If specified, writes monotonic offset in /proc/PID/timens_offsets.
  # @option options [Numeric,String] :boottime If specified, writes boottime offset in /proc/PID/timens_offsets.
  # @return [Integer, nil] Usually 0. If :fork is specified in options, then PID of the child process in parent, nil in child (as same as Kernel.#fork).
  # @raise [ArgumentError] When given flags argument is not appropriate.
  # @raise [TypeError] When map_uid and/or map_gid value is not appropriate.
  # @raise [Errno::EXXX] In case unshare(2) system call failed.
  def self.unshare flags, options={}
    _flags = interpret_flags flags
    bind_ns_files_from_child(_flags, options) do
      ret = nil
      map_uid_gid_from_child(_flags, options) do
        ret = __unshare__ _flags
        set_timens_offsets(_flags, options)
      end
      if fork?(options)
        ret = fork
      end
      ret
    end
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
  # @param flags [Integer] An integer value that represents namespaces to associate.
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
  # @param options [Hash] Optional arguments.
  # @option options [String] :mount   A file which specifies the mount namespace to associate with.
  # @option options [String] :uts     A file which specifies the uts namespace to associate with.
  # @option options [String] :ipc     A file which specifies the ipc namespace to associate with.
  # @option options [String] :network A file which specifies the network namespace to associate with.
  # @option options [String] :pid     A file which specifies the pid namespace to associate with.
  # @option options [String] :user    A file which specifies the user namespace to associate with.
  # @option options [String] :cgroup  A file which specifies the cgroup namespace to associate with.
  # @option options [String] :time    A file which specifies the time namespace to associate with.
  # @return [Integer] 0.
  # @raise [ArgumentError] When given flags argument is not appropriate or when given pid and/or options are not appropriate for the given flags.
  # @raise [Errno::EXXX] In case setns(2) system call failed.
  def self.setns flags, pid, options={}
    _flags = interpret_flags flags
    nstype_file_h = get_nstype_file_h _flags, pid, options
    do_setns nstype_file_h
    return 0
  end

  private

  def self.namespaces
    @@namespaces
  end

  def self.interpret_flags arg
    case arg
    when Integer
      check_flags arg
      arg
    when String
      chars_to_flags arg
    else
      raise TypeError, "unsupported flags: #{arg.inspect}"
    end
  end

  def self.check_flags flags
    unless (flags - (flags & namespaces.map{|_,v| v[:flag]}.inject(:+))).zero?
      raise ArgumentError, "unsupported flags are set"
    end
  end

  def self.chars_to_flags chars
    invalid_chars = chars.chars - namespaces.map{|_,v| v[:char]}
    unless invalid_chars.empty?
      raise ArgumentError, "unsupported flag charactor: #{invalid_chars.inspect}"
    end
    namespaces.select{|_,v| chars.include?(v[:char])}.map{|_,v| v[:flag]}.inject(0){|lsum,flag| lsum | flag}
  end

  def self.fork? options
    options[:fork]
  end

  def self.bind_ns_files? options
    (namespaces.map{|_,v| v[:key]} & options.keys).empty?.!
  end

  # In some cases, namespace files need to be created by an external process.
  # Thus, this method calls fork and the child process creates the namespace files.
  def self.bind_ns_files_from_child flags, options
    if bind_ns_files? options
      pid_to_bind = Process.pid
      IO.pipe do |io_r, io_w|
        if pid = fork
          begin
            ret = yield
          rescue Exception
            Process.kill "KILL", pid
            Process.waitpid pid
            raise
          else
            IO.pipe do |io2_r, io2_w|
              if ret
                io_w.write "1"
                io_w.close
                Process.waitpid pid
                unless $?.to_i.zero?
                  if ret > 0
                    Process.kill "KILL", ret
                    Process.waitpid ret
                  end
                  raise Marshal.load(io_r.read) unless $?.to_i.zero?
                end
              else
                io_w.close
                io2_w.close
                io2_r.read
              end
            end
            ret
          end
        else
          begin
            io_r.read 1
            bind_ns_files flags, options, pid_to_bind
          rescue Exception => e
            io_w.write Marshal.dump(e)
            exit! false
          else
            exit! true
          end
        end
      end
    else
      yield
    end
  end

  def self.bind_ns_files flags, options, pid
    namespaces.map{|_,v| [v[:file_to_bind], v[:flag], v[:key]]}.each do |name, flag, key|
      if (flags & flag).zero?.! && options[key]
        HrrRbMount.bind "/proc/#{pid}/ns/#{name}", options[key]
      end
    end
  end

  def self.map_uid_gid? flags, options
    (flags & namespaces.fetch("user", {}).fetch(:flag, 0)).zero?.! && (options.has_key?(:map_uid) || options.has_key?(:map_gid))
  end

  # This method calls fork and the child process writes into /proc/PID/uid_map, /proc/PID/gid_map, and /proc/PID/setgroups.
  def self.map_uid_gid_from_child flags, options
    if map_uid_gid? flags, options
      pid_to_map = Process.pid
      IO.pipe do |io_r, io_w|
        if pid = fork
          begin
            ret = yield
          rescue Exception
            Process.kill "KILL", pid
            Process.waitpid pid
            raise
          else
            io_w.write "1"
            io_w.close
            Process.waitpid pid
            raise Marshal.load(io_r.read) unless $?.to_i.zero?
            ret
          end
        else
          begin
            io_r.read 1
            map_uid_gid options, pid_to_map
          rescue Exception => e
            io_w.write Marshal.dump(e)
            exit! false
          else
            exit! true
          end
        end
      end
    else
      yield
    end
  end

  def self.map_uid_gid options, pid
    if options.has_key?(:map_uid)
      write_id_map options[:map_uid], pid, "uid"
    end
    if options.has_key?(:map_gid)
      deny_setgroups pid
      write_id_map options[:map_gid], pid, "gid"
    end
  end

  def self.write_id_map mapping, pid, type
    path = "/proc/#{pid}/#{type}_map"
    _mapping = case mapping
               when String # "0 0 1", "0 0 1\n1 10000 1000\n"
                 mapping.chomp
               when Array
                 if mapping.all?{|e| e.respond_to?(:match?) && e.match?(/^\d+ \d+ \d+$/)} # ["0 0 1", "1 10000 1000"]
                   mapping.join("\n")
                 elsif mapping.all?{|e| e.respond_to?(:to_i)} # [0, 0, 1], ["0", "0", "1"]
                   mapping.map(&:to_i).join(" ")
                 elsif mapping.all?{|e| e.respond_to?(:all?) && e.all?{ |e2| e2.respond_to?(:to_i)}} # [[0, 0, 1], ["1", "10000", "1000"]]
                   mapping.map{|e| e.map(&:to_i).join(" ")}.join("\n")
                 else
                   raise TypeError, "map_#{type}"
                 end
               else
                 raise TypeError, "map_#{type}"
               end
    File.open(path, "w") do |f|
      f.puts _mapping
    end
  end

  def self.deny_setgroups pid
    File.open("/proc/#{pid}/setgroups", "w") do |f|
      f.puts "deny"
    end
  end

  def self.set_timens_offsets? flags, options
    (flags & namespaces.fetch("time", {}).fetch(:flag, 0)).zero?.! && (options.has_key?(:monotonic) || options.has_key?(:boottime))
  end

  def self.set_timens_offsets(flags, options)
    if set_timens_offsets? flags, options
      File.open("/proc/self/timens_offsets", "w") do |f|
        [
          [MONOTONIC, :monotonic],
          [BOOTTIME,  :boottime ],
        ].each do |clk_id, key|
          if options.has_key? key
            offset_secs     = options[key].to_i
            offset_nanosecs = ((Rational(options[key]) - offset_secs) * 10**9).to_i
            f.puts "#{clk_id} #{offset_secs} #{offset_nanosecs}"
          end
        end
      end
    end
  end

  def self.do_setns nstype_file_h
    list_without_user = nstype_file_h.keys - [NEWUSER]
    success = {}
    error = {}
    nstype_fileobj_h = {}
    begin
      nstype_file_h.each do |nstype, file|
        nstype_fileobj_h[nstype] = File.open(file, File::RDONLY)
      end
      (list_without_user + [NEWUSER] + list_without_user).each do |nstype|
        next unless nstype_file_h.has_key? nstype
        begin
          next if success.has_key? nstype
          fileobj = nstype_fileobj_h[nstype]
          __setns__ fileobj.fileno, nstype
        rescue
          raise if error.has_key? nstype
          error[nstype] = true
        else
          success[nstype] = true
        end
      end
    ensure
      nstype_fileobj_h.each do |nstype, fileobj|
        fileobj.close
      end
    end
  end

  def self.get_nstype_file_h flags, pid, options
    nstype_file_h = Hash.new
    namespaces.map{|k,v| [k, v[:flag], v[:key]]}.each do |name, flag, key|
      file = get_file name, (flags & flag), pid, key, options[key]
      nstype_file_h[flag] = file if file
    end
    nstype_file_h
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
