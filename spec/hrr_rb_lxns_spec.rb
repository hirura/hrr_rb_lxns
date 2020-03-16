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

  describe ".unshare" do
    fork_yield1_yield2 = lambda{ |blk1, blk2|
      r, w = IO.pipe
      begin
        pid = fork do
          blk1.call
          w.write blk2.call
        end
        w.close
        Process.waitpid pid
        raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
        r.read
      ensure
        r.close
      end
    }

    fork_yield1_fork_yield2 = lambda{ |blk1, blk2|
      fork_yield1_yield2.call blk1, lambda{ fork_yield1_yield2.call lambda{}, blk2 }
    }

    namespaces = Hash.new
    namespaces["mnt"]    = {short: "m", long: "NEWNS",     flag: HrrRbLxns::NEWNS,     func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWNS
    namespaces["uts"]    = {short: "u", long: "NEWUTS",    flag: HrrRbLxns::NEWUTS,    func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWUTS
    namespaces["ipc"]    = {short: "i", long: "NEWIPC",    flag: HrrRbLxns::NEWIPC,    func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWIPC
    namespaces["net"]    = {short: "n", long: "NEWNET",    flag: HrrRbLxns::NEWNET,    func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWNET
    namespaces["pid"]    = {short: "p", long: "NEWPID",    flag: HrrRbLxns::NEWPID,    func: fork_yield1_fork_yield2} if HrrRbLxns.const_defined? :NEWPID
    namespaces["user"]   = {short: "U", long: "NEWUSER",   flag: HrrRbLxns::NEWUSER,   func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWUSER
    namespaces["cgroup"] = {short: "C", long: "NEWCGROUP", flag: HrrRbLxns::NEWCGROUP, func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWCGROUP
    namespaces["time"]   = {short: "T", long: "NEWTIME",   flag: HrrRbLxns::NEWTIME,   func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWTIME

    context "with no options" do
      0.upto(namespaces.size) do |n|
        namespaces.keys.combination(n).each do |c|
          targets = c
          others  = namespaces.keys - targets

          flags = targets.inject(""){|fs, t| fs + namespaces[t][:short]}

          context "with #{flags.inspect} flags" do
            unless targets.empty?
              it "disassociates #{targets.inspect} namespaces" do
                targets.each{ |ns|
                  before = File.readlink "/proc/self/ns/#{ns}"
                  after = namespaces[ns][:func].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                  expect( after ).not_to eq before
                }
              end
            end

            unless others.empty?
              it "keeps #{others.inspect} namespaces" do
                others.each{ |ns|
                  before = File.readlink "/proc/self/ns/#{ns}"
                  after = namespaces[ns][:func].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                  expect( after ).to eq before
                }
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
              it "disassociates #{targets.inspect} namespaces" do
                targets.each{ |ns|
                  before = File.readlink "/proc/self/ns/#{ns}"
                  after = namespaces[ns][:func].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                  expect( after ).not_to eq before
                }
              end
            end

            unless others.empty?
              it "keeps #{others.inspect} namespaces" do
                others.each{ |ns|
                  before = File.readlink "/proc/self/ns/#{ns}"
                  after = namespaces[ns][:func].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                  expect( after ).to eq before
                }
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
  end

  describe ".setns" do
    unshare = lambda{ |blk1, blk2|
      begin
        c2p_r, c2p_w, p2c_r, p2c_w = IO.pipe + IO.pipe
        pid = fork do
          p2c_w.close
          c2p_r.close
          blk1.call
          c2p_w.write blk2.call
          c2p_w.close
          p2c_r.read
        end
        c2p_w.close
        p2c_r.close
        [pid, [pid, c2p_r.read], p2c_w]
      ensure
        [c2p_r, c2p_w, p2c_r].each{ |io| io.close rescue nil }
      end
    }

    unshare_fork = lambda{ |blk1, blk2|
      begin
        c2p_r, c2p_w, p2c_r, p2c_w = IO.pipe + IO.pipe
        pid = fork do
          p2c_w.close
          c2p_r.close
          blk1.call
          pid, (pid_unshared, result), pipe = unshare.call lambda{ [c2p_w, p2c_r].each{ |io| io.close rescue nil } }, blk2
          c2p_w.write Marshal.dump([pid_unshared, result])
          c2p_w.close
          p2c_r.read
          pipe.close rescue nil
          Process.waitpid pid
          raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
        end
        c2p_w.close
        p2c_r.close
        [pid, Marshal.load(c2p_r.read), p2c_w]
      ensure
        [c2p_r, c2p_w, p2c_r].each{ |io| io.close rescue nil }
      end
    }

    fork_yield1_yield2 = lambda{ |blk1, blk2|
      r, w = IO.pipe
      begin
        pid = fork do
          blk1.call
          w.write blk2.call
        end
        w.close
        Process.waitpid pid
        raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
        r.read
      ensure
        r.close
      end
    }

    fork_yield1_fork_yield2 = lambda{ |blk1, blk2|
      fork_yield1_yield2.call blk1, lambda{ fork_yield1_yield2.call lambda{}, blk2 }
    }

    namespaces = Hash.new
    namespaces["mnt"]    = {short: "m", long: "NEWNS",     flag: HrrRbLxns::NEWNS,     unshare: unshare,      func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWNS
    namespaces["uts"]    = {short: "u", long: "NEWUTS",    flag: HrrRbLxns::NEWUTS,    unshare: unshare,      func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWUTS
    namespaces["ipc"]    = {short: "i", long: "NEWIPC",    flag: HrrRbLxns::NEWIPC,    unshare: unshare,      func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWIPC
    namespaces["net"]    = {short: "n", long: "NEWNET",    flag: HrrRbLxns::NEWNET,    unshare: unshare,      func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWNET
    namespaces["pid"]    = {short: "p", long: "NEWPID",    flag: HrrRbLxns::NEWPID,    unshare: unshare_fork, func: fork_yield1_fork_yield2} if HrrRbLxns.const_defined? :NEWPID
    namespaces["user"]   = {short: "U", long: "NEWUSER",   flag: HrrRbLxns::NEWUSER,   unshare: unshare,      func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWUSER
    namespaces["cgroup"] = {short: "C", long: "NEWCGROUP", flag: HrrRbLxns::NEWCGROUP, unshare: unshare,      func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWCGROUP
    namespaces["time"]   = {short: "T", long: "NEWTIME",   flag: HrrRbLxns::NEWTIME,   unshare: unshare,      func: fork_yield1_yield2     } if HrrRbLxns.const_defined? :NEWTIME

    context "with no options" do
      0.upto(namespaces.size) do |n|
        namespaces.keys.combination(n).each do |c|
          targets = c
          others  = namespaces.keys - targets

          flags = targets.inject(""){|fs, t| fs + namespaces[t][:short]}

          context "with #{flags.inspect} flags" do
            unless targets.empty?
              it "associates #{targets.inspect} namespaces" do
                targets.each{ |ns|
                  before = File.readlink "/proc/self/ns/#{ns}"
                  unshared = nil
                  after = nil
                  begin
                    pid, (unshared_pid, unshared), pipe = namespaces[ns][:unshare].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                    after = namespaces[ns][:func].call lambda{ HrrRbLxns.setns flags, unshared_pid }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                  ensure
                    pipe.close rescue nil
                    Process.waitpid pid
                    raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                  end
                  expect( after ).not_to eq before
                  expect( after ).to eq unshared
                }
              end
            end

            unless others.empty?
              it "keeps #{others.inspect} namespaces" do
                others.each{ |ns|
                  before = File.readlink "/proc/self/ns/#{ns}"
                  unshared = nil
                  after = nil
                  begin
                    pid, (unshared_pid, unshared), pipe = namespaces[ns][:unshare].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                    after = namespaces[ns][:func].call lambda{ HrrRbLxns.setns flags, unshared_pid }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                  ensure
                    pipe.close rescue nil
                    Process.waitpid pid
                    raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                  end
                  expect( after ).to eq before
                  expect( after ).to eq unshared
                }
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
              it "associates #{targets.inspect} namespaces" do
                targets.each{ |ns|
                  before = File.readlink "/proc/self/ns/#{ns}"
                  unshared = nil
                  after = nil
                  begin
                    pid, (unshared_pid, unshared), pipe = namespaces[ns][:unshare].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                    after = namespaces[ns][:func].call lambda{ HrrRbLxns.setns flags, unshared_pid }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                  ensure
                    pipe.close rescue nil
                    Process.waitpid pid
                    raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                  end
                  expect( after ).not_to eq before
                  expect( after ).to eq unshared
                }
              end
            end

            unless others.empty?
              it "keeps #{others.inspect} namespaces" do
                others.each{ |ns|
                  before = File.readlink "/proc/self/ns/#{ns}"
                  unshared = nil
                  after = nil
                  begin
                    pid, (unshared_pid, unshared), pipe = namespaces[ns][:unshare].call lambda{ HrrRbLxns.unshare flags }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                    after = namespaces[ns][:func].call lambda{ HrrRbLxns.setns flags, unshared_pid }, lambda{ File.readlink "/proc/self/ns/#{ns}" }
                  ensure
                    pipe.close rescue nil
                    Process.waitpid pid
                    raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                  end
                  expect( after ).to eq before
                  expect( after ).to eq unshared
                }
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
