#
# Module of code shared by all of the tpkg test cases
#

# Ensure that we're pulling in the local copy of the tpkg libraries, it
# doesn't do us any good to test copies that are already installed on the
# system.
$:.unshift(File.expand_path('../lib', File.dirname(__FILE__)))
require 'test/unit'
require 'fileutils'
require 'tpkg'
require 'tempfile'
require 'tmpdir'
require 'facter'
require 'mocha/setup'

Tpkg::set_debug(true) if ENV['debug']

require 'stringio'

module Kernel

  def capture_stdout
    out = StringIO.new
    $stdout = out
    yield
    return out
  ensure
    $stdout = STDOUT
  end

end

# Ruby 1.8.7 and newer have a Dir.mktmpdir
# "Backport" it for earlier versions.  This is copied straight out of the
# 1.8.7 tmpdir.rb
unless Dir.respond_to?(:mktmpdir)
  module Dir
    def Dir.mktmpdir(prefix_suffix=nil, tmpdir=nil)
      case prefix_suffix
      when nil
        prefix = "d"
        suffix = ""
      when String
        prefix = prefix_suffix
        suffix = ""
      when Array
        prefix = prefix_suffix[0]
        suffix = prefix_suffix[1]
      else
        raise ArgumentError, "unexpected prefix_suffix: #{prefix_suffix.inspect}"
      end
      tmpdir ||= Dir.tmpdir
      t = Time.now.strftime("%Y%m%d")
      n = nil
      begin
        path = "#{tmpdir}/#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
        path << "-#{n}" if n
        path << suffix
        Dir.mkdir(path, 0700)
      rescue Errno::EEXIST
        n ||= 0
        n += 1
        retry
      end

      if block_given?
        begin
          yield path
        ensure
          FileUtils.remove_entry_secure path
        end
      else
        path
      end
    end
  end
end

module TpkgTests
  # Directory with test package contents
  TESTPKGDIR = File.expand_path('testpkg', File.dirname(__FILE__))
  # Fake command used in place of system commands
  TESTCMDDIR = File.expand_path('testcmds', File.dirname(__FILE__))
  TESTCMD = File.join(TESTCMDDIR, 'testcmd')
  # Passphrase used for encrypting/decrypting packages
  PASSPHRASE = 'password'

  def create_metadata_file(filename, options={})
    format = :xml
    if options[:format]
      format = options[:format]
      # FIXME
      if format != :xml
        raise "Support for metadata file formats other than XML not yet implemented"
      end
    end
    change = {}
    if options[:change]
      change = options[:change]
    end
    remove = []
    if options[:remove]
      remove = options[:remove]
    end
    file_defaults = {}
    if options[:file_defaults]
      file_defaults = options[:file_defaults]
    end
    files = {}
    if options[:files]
      files = options[:files]
    end
    dependencies = {}
    if options[:dependencies]
      dependencies = options[:dependencies]
    end
    conflicts = {}
    if options[:conflicts]
      conflicts = options[:conflicts]
    end
    externals = {}
    if options[:externals]
      externals = options[:externals]
    end

    # FIXME:  We currently assume the specified filename exists and is a valid
    # template file that we make changes to.  We should create the metadata
    # file from scratch. That would eliminate the need for :remove, which
    # seems hacky.  And eliminate the need for this half-baked parsing and
    # manipulation, which is super hacky.
    tpkgdst = Tempfile.new(File.basename(filename), File.dirname(filename))
    IO.foreach(filename) do |line|
      if line =~ /^\s*<(\w+)>/
        field = $1
        if change.has_key?(field)
          line.sub!(/^(\s*<\w+>).*(<\/\w+>)/, '\1' + change[$1] + '\2')
        elsif remove.include?(field)
          line = ''
        end
      end

      # Insert dependencies right before the files section
      if line =~ /^\s*<files>/ && !dependencies.empty?
        tpkgdst.puts('  <dependencies>')
        dependencies.each do |name, opts|
          tpkgdst.puts('    <dependency>')
          tpkgdst.puts("      <name>#{name}</name>")
          ['minimum_version', 'maximum_version', 'minimum_package_version', 'maximum_package_version'].each do |opt|
            if opts[opt]
              tpkgdst.puts("      <#{opt}>#{opts[opt]}</#{opt}>")
            end
          end
          if opts['native']
            tpkgdst.puts('      <native/>')
          end
          tpkgdst.puts('    </dependency>')
        end
        tpkgdst.puts('  </dependencies>')
      end

      # Insert conflicts right before the files section
      if line =~ /^\s*<files>/ && !conflicts.empty?
        tpkgdst.puts('  <conflicts>')
        conflicts.each do |name, opts|
          tpkgdst.puts('    <conflict>')
          tpkgdst.puts("      <name>#{name}</name>")
          ['minimum_version', 'maximum_version', 'minimum_package_version', 'maximum_package_version'].each do |opt|
            if opts[opt]
              tpkgdst.puts("      <#{opt}>#{opts[opt]}</#{opt}>")
            end
          end
          if opts['native']
            tpkgdst.puts('      <native/>')
          end
          tpkgdst.puts('    </conflict>')
        end
        tpkgdst.puts('  </conflicts>')
      end

      # Insert externals right before the files section
      if line =~ /^\s*<files>/ && !externals.empty?
        tpkgdst.puts('  <externals>')
        externals.each do |name, opts|
          tpkgdst.puts('    <external>')
          tpkgdst.puts("      <name>#{name}</name>")
          if opts['data']
            tpkgdst.puts("      <data>#{opts['data']}</data>")
          elsif opts['datafile']
            tpkgdst.puts("      <datafile>#{opts['datafile']}</datafile>")
          elsif opts['datascript']
            tpkgdst.puts("      <datascript>#{opts['datascript']}</datascript>")
          end
          tpkgdst.puts('    </external>')
        end
        tpkgdst.puts('  </externals>')
      end

      # Insert file_defaults settings at the end of the files section
      if line =~ /^\s*<\/files>/ && !file_defaults.empty?
        tpkgdst.puts('    <file_defaults>')
        if file_defaults['owner'] || file_defaults['group'] || file_defaults['perms']
          tpkgdst.puts('      <posix>')
          ['owner', 'group', 'perms'].each do |opt|
            if file_defaults[opt]
              tpkgdst.puts("        <#{opt}>#{file_defaults[opt]}</#{opt}>")
            end
          end
          tpkgdst.puts('      </posix>')
        end
        tpkgdst.puts('    </file_defaults>')
      end

      # Insert additional file entries at the end of the files section
      if line =~ /^\s*<\/files>/ && !files.empty?
        files.each do |path, opts|
          tpkgdst.puts('    <file>')
          tpkgdst.puts("      <path>#{path}</path>")
          if opts['owner'] || opts['group'] || opts['perms']
            tpkgdst.puts('      <posix>')
            ['owner', 'group', 'perms'].each do |opt|
              if opts[opt]
                tpkgdst.puts("        <#{opt}>#{opts[opt]}</#{opt}>")
              end
            end
            tpkgdst.puts('      </posix>')
          end
          if opts['config']
            tpkgdst.puts('      <config/>')
          end
          if opts['encrypt']
            if opts['encrypt'] = 'precrypt'
              tpkgdst.puts('      <encrypt precrypt="true"/>')
            else
              tpkgdst.puts('      <encrypt/>')
            end
          end
          if opts['init']
            tpkgdst.puts('      <init>')
            if opts['init']['start']
              tpkgdst.puts("        <start>#{opts['init']['start']}</start>")
            end
            if opts['init']['levels']
              tpkgdst.puts("        <levels>#{opts['init']['levels']}</levels>")
            end
            tpkgdst.puts('      </init>')
          end
          if opts['crontab']
            if opts['crontab']['user']
              tpkgdst.puts("      <crontab><user>#{opts['crontab']['user']}</user></crontab>")
            else
              tpkgdst.puts('      <crontab/>')
            end
          end
          tpkgdst.puts('    </file>')
        end
      end

      tpkgdst.write(line)
    end
    tpkgdst.close
    File.rename(tpkgdst.path, filename)
  end

  # Make up our regular test package, substituting any fields and adding
  # dependencies as requested by the caller
  def make_package(options={})
    source_directory = TESTPKGDIR
    if options[:source_directory]
      source_directory = options[:source_directory]
    end
    output_directory = nil
    if options[:output_directory]
      output_directory = options[:output_directory]
    end
    passphrase = PASSPHRASE
    if options[:passphrase]
      passphrase = options[:passphrase]
    end

    pkgfile = nil
    Dir.mktmpdir('pkgdir') do |pkgdir|
      # Copy package contents into working directory
      system("#{Tpkg::find_tar} -C #{source_directory} --exclude .svn --exclude 'tpkg-*.xml' --exclude 'tpkg*.yml' -cf - . | #{Tpkg::find_tar} -C #{pkgdir} -xpf -")
      create_metadata_file(File.join(pkgdir, 'tpkg.xml'), options)
      pkgfile = Tpkg.make_package(pkgdir, passphrase, options)
    end

    # move the pkgfile to designated directory (if user specifies it)
    if output_directory
      FileUtils.mkdir_p(output_directory)
      FileUtils.move(pkgfile, output_directory)
      pkgfile = File.join(output_directory, File.basename(pkgfile))
    end

    pkgfile
  end

end

