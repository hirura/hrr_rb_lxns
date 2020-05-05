RSpec.describe HrrRbLxns::Files do
  it "includes Enumerable module" do
    expect(HrrRbLxns::Files.ancestors).to include ::Enumerable
  end

  context "with no pid specified" do
    let(:pid){ "self" }

    it "returns the namespace files information of the current process" do
      files = described_class.new

      file = "/proc/#{pid}/ns/mnt";               expect( files.mnt.path               ).to eq file
      file = "/proc/#{pid}/ns/uts";               expect( files.uts.path               ).to eq file
      file = "/proc/#{pid}/ns/ipc";               expect( files.ipc.path               ).to eq file
      file = "/proc/#{pid}/ns/net";               expect( files.net.path               ).to eq file
      file = "/proc/#{pid}/ns/pid";               expect( files.pid.path               ).to eq file
      file = "/proc/#{pid}/ns/pid_for_children";  expect( files.pid_for_children.path  ).to eq file
      file = "/proc/#{pid}/ns/user";              expect( files.user.path              ).to eq file
      file = "/proc/#{pid}/ns/cgroup";            expect( files.cgroup.path            ).to eq file
      file = "/proc/#{pid}/ns/time";              expect( files.time.path              ).to eq file
      file = "/proc/#{pid}/ns/time_for_children"; expect( files.time_for_children.path ).to eq file

      file = "/proc/#{pid}/ns/mnt";               expect( files.mnt.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/uts";               expect( files.uts.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/ipc";               expect( files.ipc.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/net";               expect( files.net.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/pid";               expect( files.pid.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/pid_for_children";  expect( files.pid_for_children.ino  ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/user";              expect( files.user.ino              ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/cgroup";            expect( files.cgroup.ino            ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/time";              expect( files.time.ino              ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/time_for_children"; expect( files.time_for_children.ino ).to eq (File.exist?(file) ? File.stat(file).ino : nil)

      expect( files[:mnt]               ).to be files.mnt
      expect( files[:uts]               ).to be files.uts
      expect( files[:ipc]               ).to be files.ipc
      expect( files[:net]               ).to be files.net
      expect( files[:pid]               ).to be files.pid
      expect( files[:pid_for_children]  ).to be files.pid_for_children
      expect( files[:user]              ).to be files.user
      expect( files[:cgroup]            ).to be files.cgroup
      expect( files[:time]              ).to be files.time
      expect( files[:time_for_children] ).to be files.time_for_children

      expect( files["mnt"]               ).to be files.mnt
      expect( files["uts"]               ).to be files.uts
      expect( files["ipc"]               ).to be files.ipc
      expect( files["net"]               ).to be files.net
      expect( files["pid"]               ).to be files.pid
      expect( files["pid_for_children"]  ).to be files.pid_for_children
      expect( files["user"]              ).to be files.user
      expect( files["cgroup"]            ).to be files.cgroup
      expect( files["time"]              ).to be files.time
      expect( files["time_for_children"] ).to be files.time_for_children
    end
  end

  context "with pid specified" do
    let(:pid){ Process.ppid }

    it "returns the namespace files information of the specified process" do
      files = described_class.new pid

      file = "/proc/#{pid}/ns/mnt";               expect( files.mnt.path               ).to eq file
      file = "/proc/#{pid}/ns/uts";               expect( files.uts.path               ).to eq file
      file = "/proc/#{pid}/ns/ipc";               expect( files.ipc.path               ).to eq file
      file = "/proc/#{pid}/ns/net";               expect( files.net.path               ).to eq file
      file = "/proc/#{pid}/ns/pid";               expect( files.pid.path               ).to eq file
      file = "/proc/#{pid}/ns/pid_for_children";  expect( files.pid_for_children.path  ).to eq file
      file = "/proc/#{pid}/ns/user";              expect( files.user.path              ).to eq file
      file = "/proc/#{pid}/ns/cgroup";            expect( files.cgroup.path            ).to eq file
      file = "/proc/#{pid}/ns/time";              expect( files.time.path              ).to eq file
      file = "/proc/#{pid}/ns/time_for_children"; expect( files.time_for_children.path ).to eq file

      file = "/proc/#{pid}/ns/mnt";               expect( files.mnt.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/uts";               expect( files.uts.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/ipc";               expect( files.ipc.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/net";               expect( files.net.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/pid";               expect( files.pid.ino               ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/pid_for_children";  expect( files.pid_for_children.ino  ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/user";              expect( files.user.ino              ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/cgroup";            expect( files.cgroup.ino            ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/time";              expect( files.time.ino              ).to eq (File.exist?(file) ? File.stat(file).ino : nil)
      file = "/proc/#{pid}/ns/time_for_children"; expect( files.time_for_children.ino ).to eq (File.exist?(file) ? File.stat(file).ino : nil)

      expect( files[:mnt]               ).to be files.mnt
      expect( files[:uts]               ).to be files.uts
      expect( files[:ipc]               ).to be files.ipc
      expect( files[:net]               ).to be files.net
      expect( files[:pid]               ).to be files.pid
      expect( files[:pid_for_children]  ).to be files.pid_for_children
      expect( files[:user]              ).to be files.user
      expect( files[:cgroup]            ).to be files.cgroup
      expect( files[:time]              ).to be files.time
      expect( files[:time_for_children] ).to be files.time_for_children

      expect( files["mnt"]               ).to be files.mnt
      expect( files["uts"]               ).to be files.uts
      expect( files["ipc"]               ).to be files.ipc
      expect( files["net"]               ).to be files.net
      expect( files["pid"]               ).to be files.pid
      expect( files["pid_for_children"]  ).to be files.pid_for_children
      expect( files["user"]              ).to be files.user
      expect( files["cgroup"]            ).to be files.cgroup
      expect( files["time"]              ).to be files.time
      expect( files["time_for_children"] ).to be files.time_for_children
    end
  end

  describe "#each" do
    let(:keys){ [:mnt, :uts, :ipc, :net, :pid, :pid_for_children, :user, :cgroup, :time, :time_for_children] }
    let(:pid){ Process.pid }

    it "iterates for each namespace file" do
      files = described_class.new

      expect( files.each ).to be_an_instance_of ::Enumerator

      files.each do |file|
        expect( keys.include? file[0] ).to be true
        expect( file[1] ).to be_an_instance_of HrrRbLxns::Files::File
      end
    end
  end
end
