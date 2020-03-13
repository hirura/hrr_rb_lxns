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

  fork_yield1_yield2 = lambda{ |blk1, blk2|
    r, w = IO.pipe
    begin
      pid = fork do
        blk1.call
        w.write blk2.call
      end
      w.close
      Process.waitpid pid
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

  describe ".unshare" do
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
end
