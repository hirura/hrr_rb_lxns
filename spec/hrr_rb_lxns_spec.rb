require "etc"
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


  fork_yld = lambda{ |blk|
    r, w, err_r, err_w = IO.pipe + IO.pipe
    begin
      pid = fork do
        begin
          w.write Marshal.dump(blk.call)
        rescue Exception => e
          err_w.write Marshal.dump(e)
          exit! false
        else
          exit! true
        end
      end
      w.close; err_w.close
      Process.waitpid pid
      raise Marshal.load(err_r.read) unless $?.to_i.zero?
      Marshal.load(r.read)
    ensure
      r.close; err_r.close
    end
  }

  fork_yld1_yld2 = lambda{ |blk1, blk2|
    r, w, err_r, err_w = IO.pipe + IO.pipe
    begin
      pid = fork do
        begin
          _r, _w, _err_r, _err_w = IO.pipe + IO.pipe
          # blk1.call can fork, 0 for no fork, >1 for parent, nil for child
          if _pid = blk1.call
            # blk1.call did not fork
            if _pid == 0
              w.write Marshal.dump(blk2.call)
            # blk1.call did fork
            else
              _w.close; _err_w.close
              Process.waitpid _pid
              raise Marshal.load(_err_r.read) unless $?.to_i.zero?
              w.write Marshal.dump(Marshal.load(_r.read))
            end
          # blk1.call did fork
          else
            begin
              _w.write Marshal.dump(blk2.call)
            rescue Exception => e
              _err_w.write Marshal.dump(e)
              exit! false
            else
              exit! true
            end
          end
        rescue Exception => e
          err_w.write Marshal.dump(e)
          exit! false
        else
          exit! true
        end
      end
      w.close; err_w.close
      Process.waitpid pid
      raise Marshal.load(err_r.read) unless $?.to_i.zero?
      Marshal.load(r.read)
    ensure
      r.close; err_r.close
    end
  }

  fork_yld1_fork_yld2 = lambda{ |blk1, blk2|
    fork_yld1_yld2.call blk1, lambda{ fork_yld1_yld2.call lambda{0}, blk2 }
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
  namespaces["mnt"]    = {short: "m", long: "NEWNS",     flag: HrrRbLxns::NEWNS,     key: :mount  } if HrrRbLxns.const_defined? :NEWNS
  namespaces["uts"]    = {short: "u", long: "NEWUTS",    flag: HrrRbLxns::NEWUTS,    key: :uts    } if HrrRbLxns.const_defined? :NEWUTS
  namespaces["ipc"]    = {short: "i", long: "NEWIPC",    flag: HrrRbLxns::NEWIPC,    key: :ipc    } if HrrRbLxns.const_defined? :NEWIPC
  namespaces["net"]    = {short: "n", long: "NEWNET",    flag: HrrRbLxns::NEWNET,    key: :network} if HrrRbLxns.const_defined? :NEWNET
  namespaces["pid"]    = {short: "p", long: "NEWPID",    flag: HrrRbLxns::NEWPID,    key: :pid    } if HrrRbLxns.const_defined? :NEWPID
  namespaces["user"]   = {short: "U", long: "NEWUSER",   flag: HrrRbLxns::NEWUSER,   key: :user   } if HrrRbLxns.const_defined? :NEWUSER
  namespaces["cgroup"] = {short: "C", long: "NEWCGROUP", flag: HrrRbLxns::NEWCGROUP, key: :cgroup } if HrrRbLxns.const_defined? :NEWCGROUP
  namespaces["time"]   = {short: "T", long: "NEWTIME",   flag: HrrRbLxns::NEWTIME,   key: :time   } if HrrRbLxns.const_defined? :NEWTIME


  describe ".files" do
    let(:keys){ [:mnt, :uts, :ipc, :net, :pid, :pid_for_children, :user, :cgroup, :time, :time_for_children] }

    context "with no pid specified" do
      let(:pid){ "self" }

      it "returns the namespace files information of the current process" do
        files = HrrRbLxns.files

        keys.each do |key|
          file = "/proc/#{pid}/ns/#{key}"
          expect( files[key].path ).to eq file
          expect( files[key].ino  ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
        end
      end
    end

    context "with pid specified" do
      context "which pid is the current process" do
        let(:pid){ Process.pid }

        it "returns the files of the current process" do
          files = HrrRbLxns.files pid

          keys.each do |key|
            file = "/proc/#{pid}/ns/#{key}"
            expect( files[key].path ).to eq file
            expect( files[key].ino  ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
          end
        end
      end

      context "which pid is not the current process" do
        let(:pid){ Process.ppid }

        it "returns the files of the process" do
          files = HrrRbLxns.files pid

          keys.each do |key|
            file = "/proc/#{pid}/ns/#{key}"
            expect( files[key].path ).to eq file
            expect( files[key].ino  ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
          end
        end
      end
    end
  end


  describe ".unshare" do
    context "with invalid flags" do
      context "when unsupported charactor" do
        it "raises ArgumentError" do
          expect{ fork_yld.call lambda{ HrrRbLxns.unshare (("A".."Z").to_a + ("a".."z").to_a).join("") } }.to raise_error ArgumentError
        end
      end

      context "when invalid value" do
        it "raises ArgumentError" do
          expect{ fork_yld.call lambda{ HrrRbLxns.unshare -1 } }.to raise_error ArgumentError
        end
      end
    end

    context "with no options" do
      0.upto(namespaces.size) do |n|
        namespaces.keys.combination(n).each do |targets|
          others  = namespaces.keys - targets
          [
            [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
            [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
          ].each do |flags, pretty_flags|
            context "with #{pretty_flags} flags" do
              if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                # Do nothing because unshare with NEWPID flag fails
              elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                it "raises SystemCallError" do
                  expect{ fork_yld.call lambda{ HrrRbLxns.unshare flags } }.to raise_error SystemCallError
                end
              else
                it "disassociates #{targets.inspect} namespaces and keeps #{others.inspect} namespaces" do
                  before = HrrRbLxns.files
                  after = fork_yld1_fork_yld2.call lambda{ HrrRbLxns.unshare flags }, lambda{ HrrRbLxns.files }
                  targets.each do |ns|
                    expect( after[ns].ino ).not_to eq before[ns].ino
                  end
                  others.each do |ns|
                    expect( after[ns].ino ).to eq before[ns].ino
                  end
                end
              end
            end
          end
        end
      end
    end

    context "with options" do
      context "with namespace file specified" do
        before :example do
          @tmpdir = Dir.mktmpdir
          HrrRbMount.bind @tmpdir, @tmpdir
          HrrRbMount.make_private @tmpdir
          @persist_files = Hash[namespaces.keys.map{|ns| [ns, Tempfile.new(ns, @tmpdir)]}]
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
          namespaces.keys.combination(n).each do |targets|
            others  = namespaces.keys - targets
            [
              [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
              [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
            ].each do |flags, pretty_flags|
              context "with #{pretty_flags} flags" do
                if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                  # Do nothing because unshare with NEWPID flag fails
                elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                  it "raises SystemCallError" do
                    options = Hash[targets.map{|key| [namespaces[key][:key], @persist_files[key].path]}]
                    expect{ fork_yld.call lambda{ HrrRbLxns.unshare flags, options } }.to raise_error SystemCallError
                  end
                else
                  [
                    [true,  "with :fork option"   ],
                    [false, "without :fork option"],
                  ].each do |with_fork, pretty_with_fork|
                    context "#{pretty_with_fork}" do
                      if targets.include?("pid") && with_fork.!
                        it "raises SystemCallError" do
                          options = Hash[targets.map{|key| [namespaces[key][:key], @persist_files[key].path]}]
                          expect{ fork_yld.call lambda{ HrrRbLxns.unshare flags, options } }.to raise_error SystemCallError
                        end
                      else
                        it "disassociates #{targets.inspect} namespaces and bind-mounts them" do
                          options = Hash[targets.map{|key| [namespaces[key][:key], @persist_files[key].path]}]
                          options[:fork] = true if with_fork
                          before = HrrRbLxns.files
                          after = fork_yld1_fork_yld2.call lambda{ HrrRbLxns.unshare flags, options }, lambda{ HrrRbLxns.files }
                          targets.each do |ns|
                            expect( after[ns].ino ).not_to eq before[ns].ino
                            expect( HrrRbMount.mountpoint?(@persist_files[ns].path) ).to be true
                            expect( File.stat(@persist_files[ns].path).ino ).to eq after[ns].ino
                          end
                          others.each do |ns|
                            expect( after[ns].ino ).to eq before[ns].ino
                            expect( HrrRbMount.mountpoint?(@persist_files[ns].path) ).to be false
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
      end

      if (Gem.ruby_version < Gem::Version.create("2.6")).! && namespaces.include?("user")
        context "with no map_uid/map_gid specified" do
          targets = ["user"]
          [
            [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
            [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
          ].each do |flags, pretty_flags|
            it "disassociates #{targets.inspect} namespaces and neither /proc/PID/uid_map nor /proc/PID/gid_map are created" do
              before = HrrRbLxns.files
              begin
                pid_to_wait, (pid_target, after), pipe = fork_yld1_fork_yld2_wait.call lambda{ HrrRbLxns.unshare flags }, lambda{ HrrRbLxns.files }
                uid_map_empty = File.empty? "/proc/#{pid_target}/uid_map"
                gid_map_empty = File.empty? "/proc/#{pid_target}/gid_map"
              ensure
                pipe.close rescue nil
                Process.waitpid pid_to_wait
                raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
              end
              targets.each do |ns|
                expect( after[ns].ino ).not_to eq before[ns].ino
              end
              expect( uid_map_empty ).to be true
              expect( gid_map_empty ).to be true
            end
          end
        end

        context "with map_uid/map_gid specified" do
          uid_maps = [
            {option: "0 0 1",                             expect: /^\s*0\s+0\s+1\n$/},
            {option: ["0 0 1", "1 10000 1000"],           expect: /^\s*0\s+0\s+1\n\s*1\s+10000\s+1000\n$/},
            {option: [0, 0, 1],                           expect: /^\s*0\s+0\s+1\n$/},
            {option: [[0, 0, 1], ["1", "10000", "1000"]], expect: /^\s*0\s+0\s+1\n\s*1\s+10000\s+1000\n$/},
          ]
          gid_maps = [
            {option: "0 0 1",                             expect: /^\s*0\s+0\s+1\n$/},
            {option: ["0 0 1", "1 10000 1000"],           expect: /^\s*0\s+0\s+1\n\s*1\s+10000\s+1000\n$/},
            {option: [0, 0, 1],                           expect: /^\s*0\s+0\s+1\n$/},
            {option: [[0, 0, 1], ["1", "10000", "1000"]], expect: /^\s*0\s+0\s+1\n\s*1\s+10000\s+1000\n$/},
          ]

          uid_maps.each do |uid_map|
            context "when uid_map is #{uid_map[:option].inspect}" do
              options = {map_uid: uid_map[:option]}
              targets = ["user"]
              [
                [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
                [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
              ].each do |flags, pretty_flags|
                it "disassociates #{targets.inspect} namespaces and writes /proc/PID/uid_map" do
                  before = HrrRbLxns.files
                  begin
                    pid_to_wait, (pid_target, after), pipe = fork_yld1_fork_yld2_wait.call lambda{ HrrRbLxns.unshare flags, options }, lambda{ HrrRbLxns.files }
                    uid_map_result   = File.read "/proc/#{pid_target}/uid_map"
                    setgroups_result = File.read "/proc/#{pid_target}/setgroups"
                    gid_map_result   = File.read "/proc/#{pid_target}/gid_map"
                  ensure
                    pipe.close rescue nil
                    Process.waitpid pid_to_wait
                    raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                  end
                  targets.each do |ns|
                    expect( after[ns].ino ).not_to eq before[ns].ino
                  end
                  expect( uid_map_result   ).to match uid_map[:expect]
                  expect( setgroups_result ).to eq "allow\n"
                  expect( gid_map_result   ).to eq ""
                end
              end
            end
          end

          gid_maps.each do |gid_map|
            context "when gid_map is #{gid_map[:option].inspect}" do
              options = {map_gid: gid_map[:option]}
              targets = ["user"]
              [
                [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
                [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
              ].each do |flags, pretty_flags|
                it "disassociates #{targets.inspect} namespaces and writes /proc/PID/gid_map and writes deny in /proc/PID/setgroups" do
                  before = HrrRbLxns.files
                  begin
                    pid_to_wait, (pid_target, after), pipe = fork_yld1_fork_yld2_wait.call lambda{ HrrRbLxns.unshare flags, options }, lambda{ HrrRbLxns.files }
                    uid_map_result   = File.read "/proc/#{pid_target}/uid_map"
                    setgroups_result = File.read "/proc/#{pid_target}/setgroups"
                    gid_map_result   = File.read "/proc/#{pid_target}/gid_map"
                  ensure
                    pipe.close rescue nil
                    Process.waitpid pid_to_wait
                    raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                  end
                  targets.each do |ns|
                    expect( after[ns].ino ).not_to eq before[ns].ino
                  end
                  expect( uid_map_result   ).to eq ""
                  expect( setgroups_result ).to eq "deny\n"
                  expect( gid_map_result   ).to match gid_map[:expect]
                end
              end
            end
          end

          context "when uid_map is #{uid_maps[0][:option].inspect} and gid_map is #{gid_maps[0][:option].inspect}" do
            options = {map_uid: uid_maps[0][:option], map_gid: gid_maps[0][:option]}
            targets = ["user"]
            [
              [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
              [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
            ].each do |flags, pretty_flags|
              it "disassociates #{targets.inspect} namespaces and writes /proc/PID/uid_map and /proc/PID/gid_map and writes deny in /proc/PID/setgroups" do
                before = HrrRbLxns.files
                begin
                  pid_to_wait, (pid_target, after), pipe = fork_yld1_fork_yld2_wait.call lambda{ HrrRbLxns.unshare flags, options }, lambda{ HrrRbLxns.files }
                  uid_map_result   = File.read "/proc/#{pid_target}/uid_map"
                  setgroups_result = File.read "/proc/#{pid_target}/setgroups"
                  gid_map_result   = File.read "/proc/#{pid_target}/gid_map"
                ensure
                  pipe.close rescue nil
                  Process.waitpid pid_to_wait
                  raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                end
                targets.each do |ns|
                  expect( after[ns].ino ).not_to eq before[ns].ino
                end
                expect( uid_map_result   ).to match uid_maps[0][:expect]
                expect( setgroups_result ).to eq "deny\n"
                expect( gid_map_result   ).to match gid_maps[0][:expect]
              end
            end
          end
        end
      end

      if namespaces.include?("time")
        context "with monotonic/boottime options specified" do
          [
            {options: {},                                    expect: /^monotonic +0 +0\nboottime +0 +0\n$/      },
            {options: {monotonic: 123},                      expect: /^monotonic +123 +0\nboottime +0 +0\n$/    },
            {options: {boottime: "123.456"},                 expect: /^monotonic +0 +0\nboottime +123 +456000000\n$/  },
            {options: {monotonic: "123.456", boottime: 123}, expect: /^monotonic +123 +456000000\nboottime +123 +0\n$/},
          ].each do |spec|
            context "when options are #{spec[:options].inspect}" do
              targets = ["time"]
              [
                [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
                [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
              ].each do |flags, pretty_flags|
                context "with #{pretty_flags} flags" do
                  it "disassociates #{targets.inspect} namespaces and writes /proc/PID/timens_offsets" do
                    options = spec[:options]
                    before = HrrRbLxns.files
                    begin
                      pid_to_wait, (pid_target, after), pipe = fork_yld1_fork_yld2_wait.call lambda{ HrrRbLxns.unshare flags, options }, lambda{ HrrRbLxns.files }
                      timens_offsets = File.read "/proc/#{pid_target}/timens_offsets"
                    ensure
                      pipe.close rescue nil
                      Process.waitpid pid_to_wait
                      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                    end
                    targets.each do |ns|
                      expect( after[ns].ino ).not_to eq before[ns].ino
                    end
                    expect( timens_offsets ).to match spec[:expect]
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
    context "with invalid flags" do
      context "when unsupported charactor" do
        it "raises ArgumentError" do
          expect{ fork_yld.call lambda{ HrrRbLxns.setns (("A".."Z").to_a + ("a".."z").to_a).join(""), Process.pid } }.to raise_error ArgumentError
        end
      end

      context "when invalid value" do
        it "raises ArgumentError" do
          expect{ fork_yld.call lambda{ HrrRbLxns.setns -1, Process.pid } }.to raise_error ArgumentError
        end
      end
    end

    context "with no options" do
      0.upto(namespaces.size) do |n|
        namespaces.keys.combination(n).each do |targets|
          others  = namespaces.keys - targets
          [
            [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
            [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
          ].each do |flags, pretty_flags|
            context "with #{pretty_flags} flags" do
              unless targets.empty?
                if (Gem.ruby_version < Gem::Version.create("2.3")) && targets.include?("pid")
                  # Do nothing because unshare with NEWPID flag fails
                elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("user")
                  # Do nothing because unshare with NEWUSER flag fails
                elsif (Gem.ruby_version < Gem::Version.create("2.6")) && targets.include?("mnt")
                  it "raises SystemCallError" do
                    begin
                      pid_to_wait, (pid_target, target), pipe = fork_yld1_fork_yld2_wait.call lambda{ HrrRbLxns.unshare flags }, lambda{ HrrRbLxns.files }
                      expect{ fork_yld.call lambda{ HrrRbLxns.setns flags, pid_target } }.to raise_error SystemCallError
                    ensure
                      pipe.close rescue nil
                      Process.waitpid pid_to_wait
                      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                    end
                  end
                else
                  it "associates #{targets.inspect} namespaces and keeps #{others.inspect} namespaces" do
                    before = HrrRbLxns.files
                    begin
                      pid_to_wait, (pid_target, target), pipe = fork_yld1_fork_yld2_wait.call lambda{ HrrRbLxns.unshare flags }, lambda{ HrrRbLxns.files }
                      after = fork_yld1_fork_yld2.call lambda{ HrrRbLxns.setns flags, pid_target }, lambda{ HrrRbLxns.files }
                    ensure
                      pipe.close rescue nil
                      Process.waitpid pid_to_wait
                      raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
                    end
                    targets.each do |ns|
                      expect( after[ns].ino ).not_to eq before[ns].ino
                      expect( after[ns].ino ).to eq target[ns].ino
                    end
                    others.each do |ns|
                      expect( after[ns].ino ).to eq before[ns].ino
                      expect( after[ns].ino ).to eq target[ns].ino
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    context "with options" do
      context "with namespace file specified" do
        [
          [true,  "with pid",    Process.pid],
          [false, "without pid", nil        ],
        ].each do |with_pid, pretty_with_pid, pid|
          context "#{pretty_with_pid}" do
            0.upto(namespaces.size) do |n|
              namespaces.keys.combination(n).each do |targets|
                [
                  [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
                  [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
                ].each do |flags, pretty_flags|
                  0.upto(n) do |m|
                    targets.combination(m).each do |options_targets|
                      options = Hash[options_targets.map{|ns| [namespaces[ns][:key], "/path/to/mnt/bind/#{ns}"]}]

                      context "with #{pretty_flags} flags and #{options} options" do
                        if with_pid || (targets - options_targets).empty?
                          it "associates #{options_targets.inspect} namespaces specified by files and #{(targets - options_targets).inspect} namespaces specified by pid" do
                            arg = Hash[options_targets.map{|ns| [namespaces[ns][:flag], "/path/to/mnt/bind/#{ns}"]} + (targets - options_targets).map{|ns| [namespaces[ns][:flag], "/proc/#{pid}/ns/#{ns}"]}]
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
      end
    end

    unless (Gem.ruby_version < Gem::Version.create("2.6"))
      context "as not root user" do
        nobody_uid = Etc.getpwnam("nobody").uid
        nobody_gid = Etc.getgrnam("nobody").gid

        before :example do
          @tmpdir = Dir.mktmpdir
          HrrRbMount.bind @tmpdir, @tmpdir
          HrrRbMount.make_private @tmpdir
          @persist_files = Hash[namespaces.keys.map{|ns| [ns, Tempfile.new(ns, @tmpdir)]}]
          FileUtils.chown_R nobody_uid, nobody_gid, @tmpdir
        end

        after :example do
          @persist_files.values.each do |tmpfile|
            nil while system "mountpoint -q #{tmpfile.path} && umount #{tmpfile.path}"
            tmpfile.close!
          end
          nil while system "mountpoint -q #{@tmpdir} && umount #{@tmpdir}"
          FileUtils.remove_entry_secure @tmpdir
        end

        targets = namespaces.keys
        [
          [targets.inject(""){|fs, t| fs + namespaces[t][:short]}, "#{targets.inject(""){|fs, t| fs + namespaces[t][:short]}.inspect}"       ],
          [targets.inject(0 ){|fs, t| fs | namespaces[t][:flag ]}, "(#{targets.inject([]){|fs, t| fs + [namespaces[t][:long]]}.join(" | ")})"],
        ].each do |flags, pretty_flags|
          context "with #{pretty_flags} flags" do
           it "associates #{targets.inspect} namespaces" do
             before = HrrRbLxns.files
             begin
               chpr = lambda{ Process::GID.change_privilege(nobody_gid); Process::UID.change_privilege(nobody_uid) }
               pid_to_wait, (pid_target, target), pipe = fork_yld1_fork_yld2_wait.call lambda{ chpr.call; HrrRbLxns.unshare flags }, lambda{ HrrRbLxns.files }
               File.open("/proc/#{pid_to_wait}/uid_map",   "w"){ |f| f.puts "0 #{nobody_uid} 1" }
               File.open("/proc/#{pid_to_wait}/setgroups", "w"){ |f| f.puts "deny"              }
               File.open("/proc/#{pid_to_wait}/gid_map",   "w"){ |f| f.puts "0 #{nobody_gid} 1" }
               namespaces.each{|k,v| HrrRbMount.bind "/proc/#{pid_target}/ns/#{k}", @persist_files[k].path}
               setns_options = Hash[namespaces.map{|k,v| [v[:key], @persist_files[k].path]}]
               after = fork_yld1_fork_yld2.call lambda{ chpr.call; HrrRbLxns.setns flags, pid_target, setns_options }, lambda{ HrrRbLxns.files }
             ensure
               pipe.close rescue nil
               Process.waitpid pid_to_wait
               raise RuntimeError, "forked process exited with non-zero status." unless $?.to_i.zero?
             end
             targets.each do |ns|
               expect( after[ns].ino ).not_to eq before[ns].ino
               expect( after[ns].ino ).to eq target[ns].ino
             end
           end
         end
        end
      end
    end
  end
end
