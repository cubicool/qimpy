# vimrun! ruby /home/cubicool/projects/github/qimpy/qimpy
#
# QEMU Machine Protocol

# http://wiki.qemu.org/QMP
# /usr/share/doc/qemu/qmp-commands.txt

# @todo: MAKE ALL OF THE RESPONSE-HANDLINE ASYNCHRONOUS! This is so basic! Perhaps this means
#   creating a Qimpy::Connection and Qimpy::ASyncConnection, or something.

require 'socket'
require 'io/wait'
require 'base64'
require 'json'

module Qimpy
  class Error < RuntimeError; end

  # @todo: Somehow make this in instance within the Connection?
  # @todo: puts, gets, etc?
  class File
    attr_reader :path

    def initialize(connection, path, mode)
      @path = path
      @conn = connection
      @handle = @conn.execute 'file-open', path: path, mode: mode
    end

    # @return { count: bytes, eof: true/false, buf-b64: ... }
    def read(count)
      @conn.execute 'file-read', handle: @handle, count: count
    end

    # @return { count: bytes, eof: true/false }
    def write(data)
      @conn.execute 'file-write', handle: @handle, 'buf-b64' => Base64.encode64(data)
    end

    # @return { position, eof: true/false }
    def seek(offset, whence)
      @conn.execute 'file-seek', handle: @handle, offset: offset, whence: whence
    end

    # def flush
    #   @conn.execute 'file-flush', handle: @handle
    # end

    def close
      @conn.execute 'file-close', handle: @handle
    end

    # @todo: Add :binary mode.
    def readall(mode = :text)
      fail NotImplementedError unless mode == :text

      # When :binary mode is implemented, this will likely be a different kind of object.
      data = ''

      # Decode up to 256 bytes at a time, appending the result to data.
      loop do
        r = read 256

        data += Base64.decode64(r['buf-b64'])

        break if r['eof']
      end

      # Reset the file position to the beginning.
      seek 0, 0

      data
    end
  end

  class Connection
    attr_accessor :sock
    attr_reader :info

    Command = Struct.new :enabled, :name, :success_response
    Info = Struct.new :version, :supported_commands

    # Default path is the popular path used in QEMU documentation.
    def initialize(path = '/tmp/qga.sock', sync_id = 311_411)
      @sock = UNIXSocket.open path

      # Clear out any leftover data (if there is any).
      @sock.gets if @sock.ready?

      # Synchronize our connection.
      fail IOError, "couldn't sync connection" unless execute('sync', id: sync_id) == sync_id

      # Issue a 'guest-info' command and store the results in our custom structures. This data will
      # be used later to verify the success/failure of subsequent executions.
      info = execute 'info'
      commands = info['supported_commands'].map do |v|
        Command.new v['enabled'], v['name'], v['success-response']
      end

      @info = Info.new info['version'], commands
    end

    # Calls the passed-in command, returning only the 'return' key within QMP JSON response. Note
    # that the beginning 'guest-' portion of the command should be omitted, as it is automatically
    # prepended for you.  No error-checking or verification is performed, and exceptions are allowed
    # to propogate.
    def execute(cmd, args = nil)
      # Write JSON data, with optional arguments.
      json = { execute: 'guest-' + cmd }

      json[:arguments] = args unless args.nil?

      @sock.puts json.to_json

      # Read back result.
      json = JSON.load @sock.gets

      # @todo: Make the error-handling controllable; does the user want 1:1 exception matching, or
      # is it acceptable to simply wrap everything in a RuntimeError?
      if json.include? 'error'
        cls = json['error']['class']
        desc = json['error']['desc']

        # @todo: Find the Rubocop error for eval.
        # rubocop:disable all
        eval "class #{cls} < RuntimeError; end"

        fail eval("#{cls}"), desc
        # rubocop:enable all
      end

      json['return']
    end

    def ping
      execute 'ping'
    end

    # "r",          O_RDONLY
    # "rb",         O_RDONLY                      | O_BINARY
    # "w",          O_WRONLY | O_CREAT | O_TRUNC
    # "wb",         O_WRONLY | O_CREAT | O_TRUNC  | O_BINARY
    # "a",          O_WRONLY | O_CREAT | O_APPEND
    # "ab",         O_WRONLY | O_CREAT | O_APPEND | O_BINARY
    # "r+",         O_RDWR
    # "rb+", "r+b", O_RDWR                        | O_BINARY
    # "w+",         O_RDWR   | O_CREAT | O_TRUNC
    # "wb+", "w+b", O_RDWR   | O_CREAT | O_TRUNC  | O_BINARY
    # "a+",         O_RDWR   | O_CREAT | O_APPEND
    # "ab+", "a+b", O_RDWR   | O_CREAT | O_APPEND | O_BINARY
    #
    # Open the file specified at path/mode (on the HOST), and return a "handle" to be used in
    # subsequent function calls.
    def file_open(path, mode, &blk)
      fd = File.new self, path, mode

      return fd if blk.nil?

      blk.call fd

      fd.close
    end
  end

  module_function

  # Find the socket from the list of QEMU argument commandline; confirm with entry in
  # /proc/net/unix.
  def find_socket
    # ps axf | grep qemu-system | sed 's|.*qemu-system-x86_64 \(.*\)$|g'
  end
end
