require "tmpdir"
require "tempfile"
require "fileutils"

RSpec.describe HrrRbLxns do
  it "has a version number" do
    expect(HrrRbLxns::VERSION).not_to be nil
  end

  it "has constants module" do
    expect(HrrRbLxns::Constants).not_to be nil
  end

  it "includes constants defined in Constants module" do
    expect(HrrRbLxns.ancestors).to include HrrRbLxns::Constants
    expect(HrrRbLxns::Constants.constants).to include *HrrRbLxns::Constants.constants
  end


  fork_yld1_yld2 = lambda{ |blk1, blk2|
    r, w = IO.pipe
    begin
      pid = fork do
        blk1.call
        w.write Marshal.dump(blk2.call)
      end
      w.close
      Process.waitpid pid
      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
      Marshal.load(r.read)
    ensure
      r.close
    end
  }

  fork_yld1_fork_yld2 = lambda{ |blk1, blk2|
    fork_yld1_yld2.call blk1, lambda{ fork_yld1_yld2.call lambda{}, blk2 }
  }

  fork_yld1_yld2_wait = lambda{ |blk1, blk2|
    begin
      c2p_r, c2p_w, p2c_r, p2c_w = IO.pipe + IO.pipe
      pid = fork do
        p2c_w.close
        c2p_r.close
        blk1.call
        c2p_w.write Marshal.dump(blk2.call)
        c2p_w.close
        p2c_r.read
      end
      c2p_w.close
      p2c_r.close
      [pid, [pid, Marshal.load(c2p_r.read)], p2c_w]
    ensure
      [c2p_r, c2p_w, p2c_r].each{ |io| io.close rescue nil }
    end
  }

  fork_yld1_fork_yld2_wait = lambda{ |blk1, blk2|
    begin
      c2p_r, c2p_w, p2c_r, p2c_w = IO.pipe + IO.pipe
      pid = fork do
        p2c_w.close
        c2p_r.close
        blk1.call
        pid_to_wait, (pid_target, target), pipe = fork_yld1_yld2_wait.call lambda{ [c2p_w, p2c_r].each{ |io| io.close rescue nil } }, blk2
        c2p_w.write Marshal.dump([pid_target, target])
        c2p_w.close
        p2c_r.read
        pipe.close rescue nil
        Process.waitpid pid_to_wait
        raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
      end
      c2p_w.close
      p2c_r.close
      [pid, Marshal.load(c2p_r.read), p2c_w]
    ensure
      [c2p_r, c2p_w, p2c_r].each{ |io| io.close rescue nil }
    end
  }

  namespaces = Hash.new
  namespaces["mnt"]    = {short: "m", long: "NEWNS",     flag: HrrRbLxns::NEWNS,     key: :mount,   func1: fork_yld1_yld2,      func2: fork_yld1_yld2_wait     } if HrrRbLxns.const_defined? :NEWNS
  namespaces["uts"]    = {short: "u", long: "NEWUTS",    flag: HrrRbLxns::NEWUTS,    key: :uts,     func1: fork_yld1_yld2,      func2: fork_yld1_yld2_wait     } if HrrRbLxns.const_defined? :NEWUTS
  namespaces["ipc"]    = {short: "i", long: "NEWIPC",    flag: HrrRbLxns::NEWIPC,    key: :ipc,     func1: fork_yld1_yld2,      func2: fork_yld1_yld2_wait     } if HrrRbLxns.const_defined? :NEWIPC
  namespaces["net"]    = {short: "n", long: "NEWNET",    flag: HrrRbLxns::NEWNET,    key: :network, func1: fork_yld1_yld2,      func2: fork_yld1_yld2_wait     } if HrrRbLxns.const_defined? :NEWNET
  namespaces["pid"]    = {short: "p", long: "NEWPID",    flag: HrrRbLxns::NEWPID,    key: :pid,     func1: fork_yld1_fork_yld2, func2: fork_yld1_fork_yld2_wait} if HrrRbLxns.const_defined? :NEWPID
  namespaces["user"]   = {short: "U", long: "NEWUSER",   flag: HrrRbLxns::NEWUSER,   key: :user,    func1: fork_yld1_yld2,      func2: fork_yld1_yld2_wait     } if HrrRbLxns.const_defined? :NEWUSER
  namespaces["cgroup"] = {short: "C", long: "NEWCGROUP", flag: HrrRbLxns::NEWCGROUP, key: :cgroup,  func1: fork_yld1_yld2,      func2: fork_yld1_yld2_wait     } if HrrRbLxns.const_defined? :NEWCGROUP
  namespaces["time"]   = {short: "T", long: "NEWTIME",   flag: HrrRbLxns::NEWTIME,   key: :time,    func1: fork_yld1_yld2,      func2: fork_yld1_yld2_wait     } if HrrRbLxns.const_defined? :NEWTIME

  describe ".unshare" do
    context "with no options" do
      0.upto(namespaces.size) do |n|
        namespaces.keys.combination(n).each do |c|
          targets = c
          others  = namespaces.keys - targets

          flags = targets.inject(""){|fs, t| fs + namespaces[t][:short]}

          context "with #{flags.inspect} flags" do
            unless targets.empty?
              if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                # Do nothing because unshare with NEWPID flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                it "raises SystemCallError" do
                  expect{ HrrRbLxns.unshare flags }.to raise_error SystemCallError
                end
              else
                it "disassociates #{targets.inspect} namespaces" do
                  targets.each{ |ns|
                    before = File.stat("/proc/self/ns/#{ns}").ino
                    after = namespaces[ns][:func1].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                    expect( after ).not_to eq before
                  }
                end
              end
            end

            unless others.empty?
              if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                # Do nothing because unshare with NEWPID flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                # Do nothing because unshare with NEWUSER flag fails
              else
                it "keeps #{others.inspect} namespaces" do
                  others.each{ |ns|
                    before = File.stat("/proc/self/ns/#{ns}").ino
                    after = namespaces[ns][:func1].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                    expect( after ).to eq before
                  }
                end
              end
            end
          end
        end
      end

      0.upto(namespaces.size) do |n|
        namespaces.keys.combination(n).each do |c|
          targets = c
          others  = namespaces.keys - targets

          flags = targets.inject(0){|fs, t| fs | namespaces[t][:flag]}

          context "with (#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")}) flags" do
            unless targets.empty?
              if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                # Do nothing because unshare with NEWPID flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                it "raises SystemCallError" do
                  expect{ HrrRbLxns.unshare flags }.to raise_error SystemCallError
                end
              else
                it "disassociates #{targets.inspect} namespaces" do
                  targets.each{ |ns|
                    before = File.stat("/proc/self/ns/#{ns}").ino
                    after = namespaces[ns][:func1].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                    expect( after ).not_to eq before
                  }
                end
              end
            end

            unless others.empty?
              if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                # Do nothing because unshare with NEWPID flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                # Do nothing because unshare with NEWUSER flag fails
              else
                it "keeps #{others.inspect} namespaces" do
                  others.each{ |ns|
                    before = File.stat("/proc/self/ns/#{ns}").ino
                    after = namespaces[ns][:func1].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                    expect( after ).to eq before
                  }
                end
              end
            end
          end
        end
      end
    end

    context "with invalid flags" do
      context "when unsupported charactor" do
        it "raises ArgumentError" do
          expect{ HrrRbLxns.unshare (("A".."Z").to_a + ("a".."z").to_a).join("") }.to raise_error ArgumentError
        end
      end

      context "when invalid value" do
        it "raises SystemCallError" do
          expect{ HrrRbLxns.unshare -1 }.to raise_error SystemCallError
        end
      end
    end

    context "with options" do
      context "with namespace file specified" do
        before :example do
          @tmpdir = Dir.mktmpdir
          HrrRbMount.bind @tmpdir, @tmpdir
          HrrRbMount.make_private @tmpdir
          @persist_files = {
                             "mnt"    => Tempfile.new("mnt",    @tmpdir),
                             "uts"    => Tempfile.new("uts",    @tmpdir),
                             "ipc"    => Tempfile.new("ipc",    @tmpdir),
                             "net"    => Tempfile.new("net",    @tmpdir),
                             "pid"    => Tempfile.new("pid",    @tmpdir),
                             "user"   => Tempfile.new("user",   @tmpdir),
                             "cgroup" => Tempfile.new("cgroup", @tmpdir),
                             "time"   => Tempfile.new("time",   @tmpdir),
                           }
        end

        after :example do
          @persist_files.values.each do |tmpfile|
            nil while system "mountpoint -q #{tmpfile.path} && umount #{tmpfile.path}"
            tmpfile.close!
          end
          nil while system "mountpoint -q #{@tmpdir} && umount #{@tmpdir}"
          FileUtils.remove_entry_secure @tmpdir
        end

        0.upto(namespaces.size) do |n|
          namespaces.keys.combination(n).each do |c|
            targets = c
            others  = namespaces.keys - targets

            flags = targets.inject(""){|fs, t| fs + namespaces[t][:short]}

            context "with #{flags.inspect} flags" do
              unless targets.empty?
                if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                  # Do nothing because unshare with NEWPID flag fails
                elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                  it "raises SystemCallError" do
                    options = Hash.new
                    targets.each do |key|
                      options[namespaces[key][:key]] = @persist_files[key].path
                    end
                    expect{ HrrRbLxns.unshare flags, options }.to raise_error SystemCallError
                  end
                else
                  it "disassociates #{targets.inspect} namespaces and bind-mounts them" do
                    options = Hash.new
                    targets.each do |key|
                      options[namespaces[key][:key]] = @persist_files[key].path
                    end
                    targets.each{ |ns|
                      before = File.stat("/proc/self/ns/#{ns}").ino
                      after = namespaces[ns][:func1].call lambda{ HrrRbLxns.unshare flags, options }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      expect( after ).not_to eq before
                      if ns != "pid"
                        expect( HrrRbMount.mountpoint?(@persist_files[ns].path) ).to be true
                        expect( File.stat(@persist_files[ns].path).ino ).to eq after
                      end
                    }
                  end
                end
              end

              unless others.empty?
                if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                  # Do nothing because unshare with NEWPID flag fails
                elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                  # Do nothing because unshare with NEWUSER flag fails
                else
                  it "keeps #{others.inspect} namespaces" do
                    options = Hash.new
                    targets.each do |key|
                      options[namespaces[key][:key]] = @persist_files[key].path
                    end
                    others.each{ |ns|
                      before = File.stat("/proc/self/ns/#{ns}").ino
                      after = namespaces[ns][:func1].call lambda{ HrrRbLxns.unshare flags, options }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      expect( after ).to eq before
                      expect( HrrRbMount.mountpoint?(@persist_files[ns].path) ).to be false
                    }
                  end
                end
              end
            end
          end
        end

        0.upto(namespaces.size) do |n|
          namespaces.keys.combination(n).each do |c|
            targets = c
            others  = namespaces.keys - targets

            flags = targets.inject(0){|fs, t| fs | namespaces[t][:flag]}

            context "with (#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")}) flags" do
              unless targets.empty?
                if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                  # Do nothing because unshare with NEWPID flag fails
                elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                  it "raises SystemCallError" do
                    options = Hash.new
                    targets.each do |key|
                      options[namespaces[key][:key]] = @persist_files[key].path
                    end
                    expect{ HrrRbLxns.unshare flags, options }.to raise_error SystemCallError
                  end
                else
                  it "disassociates #{targets.inspect} namespaces and bind-mounts them" do
                    options = Hash.new
                    targets.each do |key|
                      options[namespaces[key][:key]] = @persist_files[key].path
                    end
                    targets.each{ |ns|
                      before = File.stat("/proc/self/ns/#{ns}").ino
                      after = namespaces[ns][:func1].call lambda{ HrrRbLxns.unshare flags, options }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      expect( after ).not_to eq before
                      if ns != "pid"
                        expect( HrrRbMount.mountpoint?(@persist_files[ns].path) ).to be true
                        expect( File.stat(@persist_files[ns].path).ino ).to eq after
                      end
                    }
                  end
                end
              end

              unless others.empty?
                if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                  # Do nothing because unshare with NEWPID flag fails
                elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                  # Do nothing because unshare with NEWUSER flag fails
                else
                  it "keeps #{others.inspect} namespaces" do
                    options = Hash.new
                    targets.each do |key|
                      options[namespaces[key][:key]] = @persist_files[key].path
                    end
                    others.each{ |ns|
                      before = File.stat("/proc/self/ns/#{ns}").ino
                      after = namespaces[ns][:func1].call lambda{ HrrRbLxns.unshare flags, options }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      expect( after ).to eq before
                      expect( HrrRbMount.mountpoint?(@persist_files[ns].path) ).to be false
                    }
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  describe ".setns" do
    context "with no options" do
      0.upto(namespaces.size) do |n|
        namespaces.keys.combination(n).each do |c|
          targets = c
          others  = namespaces.keys - targets

          flags = targets.inject(""){|fs, t| fs + namespaces[t][:short]}

          context "with #{flags.inspect} flags" do
            unless targets.empty?
              if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                # Do nothing because unshare with NEWPID flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                # Do nothing because unshare with NEWUSER flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("mnt")
                it "raises SystemCallError" do
                  targets.each{ |ns|
                    begin
                      pid_to_wait, (pid_target, target), pipe = namespaces[ns][:func2].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      expect{ HrrRbLxns.setns flags, pid_target }.to raise_error SystemCallError
                    ensure
                      pipe.close rescue nil
                      Process.waitpid pid_to_wait
                      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                    end
                  }
                end
              else
                it "associates #{targets.inspect} namespaces" do
                  targets.each{ |ns|
                    before = File.stat("/proc/self/ns/#{ns}").ino
                    target = nil
                    after = nil
                    begin
                      pid_to_wait, (pid_target, target), pipe = namespaces[ns][:func2].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      after = namespaces[ns][:func1].call lambda{ HrrRbLxns.setns flags, pid_target }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                    ensure
                      pipe.close rescue nil
                      Process.waitpid pid_to_wait
                      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                    end
                    expect( after ).not_to eq before
                    expect( after ).to eq target
                  }
                end
              end
            end

            unless others.empty?
              if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                # Do nothing because unshare with NEWPID flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                # Do nothing because unshare with NEWUSER flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("mnt")
                # Do nothing because unshare with NEWUSER flag fails
              else
                it "keeps #{others.inspect} namespaces" do
                  others.each{ |ns|
                    before = File.stat("/proc/self/ns/#{ns}").ino
                    target = nil
                    after = nil
                    begin
                      pid_to_wait, (pid_target, target), pipe = namespaces[ns][:func2].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      after = namespaces[ns][:func1].call lambda{ HrrRbLxns.setns flags, pid_target }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                    ensure
                      pipe.close rescue nil
                      Process.waitpid pid_to_wait
                      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                    end
                    expect( after ).to eq before
                    expect( after ).to eq target
                  }
                end
              end
            end
          end
        end
      end

      0.upto(namespaces.size) do |n|
        namespaces.keys.combination(n).each do |c|
          targets = c
          others  = namespaces.keys - targets

          flags = targets.inject(0){|fs, t| fs | namespaces[t][:flag]}

          context "with (#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")}) flags" do
            unless targets.empty?
              if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                # Do nothing because unshare with NEWPID flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                # Do nothing because unshare with NEWUSER flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("mnt")
                it "raises SystemCallError" do
                  targets.each{ |ns|
                    begin
                      pid_to_wait, (pid_target, target), pipe = namespaces[ns][:func2].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      expect{ HrrRbLxns.setns flags, pid_target }.to raise_error SystemCallError
                    ensure
                      pipe.close rescue nil
                      Process.waitpid pid_to_wait
                      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                    end
                  }
                end
              else
                it "associates #{targets.inspect} namespaces" do
                  targets.each{ |ns|
                    before = File.stat("/proc/self/ns/#{ns}").ino
                    target = nil
                    after = nil
                    begin
                      pid_to_wait, (pid_target, target), pipe = namespaces[ns][:func2].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      after = namespaces[ns][:func1].call lambda{ HrrRbLxns.setns flags, pid_target }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                    ensure
                      pipe.close rescue nil
                      Process.waitpid pid_to_wait
                      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                    end
                    expect( after ).not_to eq before
                    expect( after ).to eq target
                  }
                end
              end
            end

            unless others.empty?
              if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                # Do nothing because unshare with NEWPID flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                # Do nothing because unshare with NEWUSER flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("mnt")
                # Do nothing because unshare with NEWUSER flag fails
              else
                it "keeps #{others.inspect} namespaces" do
                  others.each{ |ns|
                    before = File.stat("/proc/self/ns/#{ns}").ino
                    target = nil
                    after = nil
                    begin
                      pid_to_wait, (pid_target, target), pipe = namespaces[ns][:func2].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                      after = namespaces[ns][:func1].call lambda{ HrrRbLxns.setns flags, pid_target }, lambda{ File.stat("/proc/self/ns/#{ns}").ino }
                    ensure
                      pipe.close rescue nil
                      Process.waitpid pid_to_wait
                      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                    end
                    expect( after ).to eq before
                    expect( after ).to eq target
                  }
                end
              end
            end
          end
        end
      end
    end

    context "with options" do
      context "with namespace file specified" do
        persist_files = {
                          "mnt"    => "mount ns file",
                          "uts"    => "uts ns file",
                          "ipc"    => "ipc ns file",
                          "net"    => "network ns file",
                          "pid"    => "pid ns file",
                          "user"   => "user ns file",
                          "cgroup" => "cgroup ns file",
                          "time"   => "time ns file",
                        }

        context "with pid" do
          pid = Process.pid
          pid_ns_files = {
                           "mnt"    => "/proc/#{pid}/ns/mnt",
                           "uts"    => "/proc/#{pid}/ns/uts",
                           "ipc"    => "/proc/#{pid}/ns/ipc",
                           "net"    => "/proc/#{pid}/ns/net",
                           "pid"    => "/proc/#{pid}/ns/pid",
                           "user"   => "/proc/#{pid}/ns/user",
                           "cgroup" => "/proc/#{pid}/ns/cgroup",
                           "time"   => "/proc/#{pid}/ns/time",
                         }

          0.upto(namespaces.size) do |n|
            namespaces.keys.combination(n).each do |c|
              targets = c

              flags = targets.inject(""){|fs, t| fs + namespaces[t][:short]}

              0.upto(n) do |m|
                targets.combination(m).each do |cc|
                  options_targets = cc

                  options = Hash.new
                  options_targets.each do |key|
                    options[namespaces[key][:key]] = persist_files[key]
                  end

                  arg = Hash.new
                  options_targets.each do |key|
                    arg[namespaces[key][:flag]] = persist_files[key]
                  end
                  (targets - options_targets).each do |key|
                    arg[namespaces[key][:flag]] = pid_ns_files[key]
                  end

                  context "with #{flags.inspect} flags and #{options} options" do
                    it "associates #{(targets - options_targets).inspect} namespaces specified by pid and #{options_targets.inspect} namespaces specified by files" do
                      expect(HrrRbLxns).to receive(:do_setns).with(arg).once
                      HrrRbLxns.setns flags, pid, options
                    end
                  end
                end
              end
            end
          end

          0.upto(namespaces.size) do |n|
            namespaces.keys.combination(n).each do |c|
              targets = c

              flags = targets.inject(0){|fs, t| fs | namespaces[t][:flag]}

              0.upto(n) do |m|
                targets.combination(m).each do |cc|
                  options_targets = cc

                  options = Hash.new
                  options_targets.each do |key|
                    options[namespaces[key][:key]] = persist_files[key]
                  end

                  arg = Hash.new
                  options_targets.each do |key|
                    arg[namespaces[key][:flag]] = persist_files[key]
                  end
                  (targets - options_targets).each do |key|
                    arg[namespaces[key][:flag]] = pid_ns_files[key]
                  end

                  context "with (#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")}) flags and #{options} options" do
                    it "associates #{(targets - options_targets).inspect} namespaces specified by pid and #{options_targets.inspect} namespaces specified by files" do
                      expect(HrrRbLxns).to receive(:do_setns).with(arg).once
                      HrrRbLxns.setns flags, pid, options
                    end
                  end
                end
              end
            end
          end
        end

        context "with no pid" do
          pid = nil

          0.upto(namespaces.size) do |n|
            namespaces.keys.combination(n).each do |c|
              targets = c

              flags = targets.inject(""){|fs, t| fs + namespaces[t][:short]}

              0.upto(n) do |m|
                targets.combination(m).each do |cc|
                  options_targets = cc

                  options = Hash.new
                  options_targets.each do |key|
                    options[namespaces[key][:key]] = persist_files[key]
                  end

                  arg = Hash.new
                  options_targets.each do |key|
                    arg[namespaces[key][:flag]] = persist_files[key]
                  end

                  context "with #{flags.inspect} flags and #{options} options" do
                    if (targets - options_targets).empty?
                      it "associates #{options_targets.inspect} namespaces specified by files" do
                        expect(HrrRbLxns).to receive(:do_setns).with(arg).once
                        HrrRbLxns.setns flags, pid, options
                      end
                    else
                      it "raises ArgumentError" do
                        expect{ HrrRbLxns.setns flags, pid, options }.to raise_error ArgumentError
                      end
                    end
                  end
                end
              end
            end
          end

          0.upto(namespaces.size) do |n|
            namespaces.keys.combination(n).each do |c|
              targets = c

              flags = targets.inject(""){|fs, t| fs + namespaces[t][:short]}

              0.upto(n) do |m|
                targets.combination(m).each do |cc|
                  options_targets = cc

                  options = Hash.new
                  options_targets.each do |key|
                    options[namespaces[key][:key]] = persist_files[key]
                  end

                  arg = Hash.new
                  options_targets.each do |key|
                    arg[namespaces[key][:flag]] = persist_files[key]
                  end

                  context "with (#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")}) flags and #{options} options" do
                    if (targets - options_targets).empty?
                      it "associates #{options_targets.inspect} namespaces specified by files" do
                        expect(HrrRbLxns).to receive(:do_setns).with(arg).once
                        HrrRbLxns.setns flags, pid, options
                      end
                    else
                      it "raises ArgumentError" do
                        expect{ HrrRbLxns.setns flags, pid, options }.to raise_error ArgumentError
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    context "with invalid flags" do
      context "when unsupported charactor" do
        it "raises ArgumentError" do
          expect{ HrrRbLxns.setns (("A".."Z").to_a + ("a".."z").to_a).join(""), Process.pid }.to raise_error ArgumentError
        end
      end

      context "when invalid value" do
        it "raises SystemCallError" do
          expect{ HrrRbLxns.setns -1, Process.pid }.to raise_error SystemCallError
        end
      end
    end
  end
end
