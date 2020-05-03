RSpec.describe HrrRbLxns::Files::File do
  context "with valid namespace file path" do
    let(:path){ "/proc/self/ns/net" }

    it "takes the path to the namespace file and collects then keeps its inode" do
      file = described_class.new path

      expect( file.path ).to eq path
      expect( file.ino ).to be > 0
    end
  end

  context "with invalid (not exist) namespace file path" do
    let(:path){ "/proc/self/ns/does_not_exist" }

    it "keeps nil as inode number for the path" do
      file = described_class.new path

      expect( file.path ).to eq path
      expect( file.ino ).to be nil
    end
  end
end

