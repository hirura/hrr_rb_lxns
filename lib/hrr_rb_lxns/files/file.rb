module HrrRbLxns
  class Files

    # A class that takes a path to a namespace file and collects then keeps its inode.
    #
    # @example
    #   file = HrrRbLxns::Files::File.new "/proc/12345/ns/uts"
    #   file.path # => "/proc/12345/ns/uts"
    #   file.ino  # => 4026531839
    #
    class File

      # Returns the file information of attribute :path.
      #
      # @return [String] The path to the namespace file.
      #
      attr_reader :path

      # Returns the file information of attribute :ino.
      #
      # @return [Integer,nil] The inode number of the namespace file. If the path is not valid, then ino is nil.
      #
      attr_reader :ino

      # @param path [String] The path to a namespace file.
      #
      def initialize path
        @path = path
        @ino  = ::File.exist?(path) ? ::File.stat(path).ino : nil
      end
    end
  end
end
