require 'rbconfig'
require 'tempfile'
require 'tmpdir'
require 'open-uri'
require 'openssl'
require 'rake/testtask'
require 'bundler/gem_tasks'

TPKGVER = `ruby -Ilib -e "require 'tpkg'; puts Tpkg::VERSION"`.chomp
TARBALLFILE = "tpkg-client-#{TPKGVER}.tar.gz"
TARBALL = File.expand_path(TARBALLFILE)

BUILDROOT = '/var/tmp/tpkg-client-buildroot'

# Copies the tpkg client files to destdir.  If any of the dir options
# are not specified the files that would go in that directory will not
# be copied.
# options:
#  :bindir
#  :libdir
#  :etcdir
#  :mandir
#  :externalsdir
#  :schemadir
#  :profiledir
#  :ruby (#! lines in scripts will be changed to specified ruby)
#  :copythirdparty
#    If not specified the thirdparty directory will not be copied.  The
#    package will need to express appropriate dependencies as
#    replacements for the libraries contained in that directory.
def copy_tpkg_files(destdir, options={})
  if options[:bindir]
    bindir = File.join(destdir, options[:bindir])
    mkdir_p(bindir)
    binapps = ['tpkg', 'cpan2tpkg', 'gem2tpkg', 'tpkg_xml_to_yml']
    binapps.each do |binapp|
      if options[:ruby]
        # Change #! line
        File.open(File.join(bindir, binapp), 'w') do |newfile|
          File.open(File.join('bin', binapp)) do |oldfile|
            # Modify the first line
            firstline = oldfile.gets
            # Preserve any options.  I.e. #!/usr/bin/ruby -w
            shebang, shebangopts = firstline.split(' ', 2)
            newfile.puts "#!#{options[:ruby]} #{shebangopts}"
            # Then dump in the rest of the file
            newfile.write(oldfile.read)
          end
        end
      else
        cp(File.join('bin', binapp), bindir, :preserve => true)
      end
      chmod(0555, File.join(bindir, binapp))
    end
  end

  if options[:libdir]
    libdir = File.join(destdir, options[:libdir])
    mkdir_p(libdir)

    # Substitute TPKGVER into tpkg.rb
    # Substitute proper path into DEFAULT_CONFIGDIR in tpkg.rb if appropriate
    File.open(File.join(libdir, 'tpkg.rb'), 'w') do |newfile|
      IO.foreach(File.join('lib', 'tpkg.rb')) do |line|
        if line =~ /^\s*VERSION/
          line.sub!(/=.*/, "= '#{TPKGVER}'")
        end
        if options[:etcdir] && line =~ /^\s*DEFAULT_CONFIGDIR/
          line.sub!(/=.*/, "= '#{options[:etcdir]}'")
        end
        newfile.write(line)
      end
    end
    chmod(0444, File.join(libdir, 'tpkg.rb'))

    tpkglibdir = File.join(libdir, 'tpkg')
    mkdir_p(tpkglibdir)
    libs = ['deployer.rb', 'metadata.rb', 'os.rb', 'silently.rb', 'thread_pool.rb', 'version.rb', 'versiontype.rb']
    libs.each do |lib|
      cp(File.join('lib', 'tpkg', lib), tpkglibdir, :preserve => true)
      chmod(0444, File.join(tpkglibdir, lib))
    end
    tpkgoslibdir = File.join(tpkglibdir, 'os')
    mkdir_p(tpkgoslibdir)
    Dir.glob('lib/tpkg/os/*.rb').each do |lib|
      cp(lib, tpkgoslibdir, :preserve => true)
      chmod(0444, File.join(tpkgoslibdir, File.basename(lib)))
    end

    if options[:copythirdparty]
      # All the nice consistent usage of FileUtils and then this...
      system("cd lib/tpkg && find thirdparty -name .svn -prune -o -print | cpio -pdum #{tpkglibdir}")
    end
  end

  if options[:mandir]
    mandir = File.join(destdir, options[:mandir])
    Dir.chdir('man')
    Dir.glob('man*').each do |mansubdir|
      mansectiondir = File.join(mandir, mansubdir)
      mkdir_p(mansectiondir)
      Dir.chdir(mansubdir)
      Dir.glob('*').each do |manpage|
        cp(manpage, mansectiondir, :preserve => true)
        chmod(0444, File.join(mansectiondir, manpage))
      end
      Dir.chdir('..')
    end
    Dir.chdir('..')
  end

  if options[:etcdir]
    etcdir = File.join(destdir, options[:etcdir])
    mkdir_p(etcdir)
    cp('tpkg.conf', etcdir, :preserve => true)
    chmod(0644, File.join(etcdir, 'tpkg.conf'))
    # All of the supporting config files go into a subdirectory
    etctpkgdir = File.join(etcdir, 'tpkg')
    mkdir_p(etctpkgdir)
    etctpkgfiles = ['ca.pem']
    etctpkgfiles.each do |etctpkgfile|
      cp(etctpkgfile, etctpkgdir, :preserve => true)
      chmod(0644, File.join(etctpkgdir, etctpkgfile))
    end
  end

  if options[:externalsdir]
    externalsdir = File.join(destdir, options[:externalsdir])
    mkdir_p(externalsdir)
    Dir.glob(File.join('externals', '*')).each do |external|
      cp(external, externalsdir, :preserve => true)
      chmod(0555, File.join(externalsdir, File.basename(external)))
    end
  end

  if options[:schemadir]
    schemadir = File.join(destdir, options[:schemadir])
    mkdir_p(schemadir)
    Dir.glob(File.join('schema', '*')).each do |schema|
      cp(schema, schemadir, :preserve => true)
      chmod(0555, File.join(schemadir, File.basename(schema)))
    end
  end

  if options[:profiledir]
    profiledir = File.join(BUILDROOT, options[:profiledir])
    mkdir_p(profiledir)
    cp('tpkg_profile.sh', File.join(profiledir, 'tpkg.sh'), :preserve => true)
    chmod(0755, File.join(profiledir, 'tpkg.sh'))
  end
end

# rake test
# Run a specific file:  rake test TEST=test/make.rb
# Run a specific method:
#   rake test TEST=test/test_make.rb TESTOPTS="--name=test_make_osarch_names"
Rake::TestTask.new do |t|
  t.libs << "lib"
  t.verbose = true
end

# FlogTask is broken...
# begin
#   require 'flog_task'
#   FlogTask.new do |t|
#     t.dirs = ['lib']
#   end
# rescue LoadError
#   warn "Flog not installed"
# end
desc 'Run flog on code'
task :flog do
  system("flog -g lib")
end
namespace :flog do
  desc 'Just the flog summary'
  task :summary do
    system("flog -s lib")
  end
end
begin
  require 'flay'
  require 'flay_task'
  FlayTask.new do |t|
    t.dirs = ['lib']
  end
rescue LoadError
  warn "Flay gem not installed, flay rake tasks will be unavailable"
end

desc 'Build an tpkg client RPM on a Red Hat box'
task :redhat => [:redhatprep, :rpm]
desc 'Prep a Red Hat box for building an RPM'
task :redhatprep do
  # Install the package which contains the rpmbuild command
  system('rpm --quiet -q rpm-build || sudo yum install rpm-build')
end
desc 'Build an tpkg client RPM'
task :rpm do
  #
  # Create package file structure in build root
  #

  rm_rf(BUILDROOT)

  bindir = File.join('usr', 'bin')
  libdir = File.join('usr', 'lib', 'ruby', 'site_ruby', '1.8')
  mandir = File.join('usr', 'share', 'man')
  etcdir = '/etc'
  externalsdir = File.join('usr', 'lib', 'tpkg', 'externals')
  schemadir = File.join('etc', 'tpkg', 'schema')
  profiledir = File.join('etc', 'profile.d')
  copy_tpkg_files(BUILDROOT,
                  :bindir => bindir,
                  :libdir => libdir,
                  :mandir => mandir,
                  :etcdir => etcdir,
                  :externalsdir => externalsdir,
                  :schemadir => schemadir,
                  :profiledir => profiledir,
                  :copythirdparty => true)

  #
  # Prep spec file
  #

  spec = Tempfile.new('tpkgrpm')
  IO.foreach('tpkg.spec') do |line|
    line.sub!('%VER%', TPKGVER)
    spec.puts(line)
  end
  spec.flush

  #
  # Build the package
  #
  system("rpmbuild -bb --buildroot #{BUILDROOT} #{spec.path}")

  #
  # Cleanup
  #

  rm_rf(BUILDROOT)
end

desc 'Build an tpkg client deb'
task :deb do
  #
  # Create package file structure in build root
  #

  system("sudo rm -rf #{BUILDROOT}")

  mkdir_p(File.join(BUILDROOT, 'DEBIAN'))
  File.open(File.join(BUILDROOT, 'DEBIAN', 'control'), 'w') do |control|
    IO.foreach('control') do |line|
      next if line =~ /^\s*#/  # Remove comments
      line.sub!('%VER%', TPKGVER)
      control.puts(line)
    end
  end

  bindir = File.join('usr', 'bin')
  libdir = File.join('usr', 'local', 'lib', 'site_ruby')
  mandir = File.join('usr', 'share', 'man')
  etcdir = '/etc'
  externalsdir = File.join('usr', 'lib', 'tpkg', 'externals')
  schemadir = File.join('etc', 'tpkg', 'schema')
  copy_tpkg_files(BUILDROOT,
                  :bindir => bindir,
                  :libdir => libdir,
                  :mandir => mandir,
                  :etcdir => etcdir,
                  :externalsdir => externalsdir,
                  :schemadir => schemadir,
                  :copythirdparty => true)

  #
  # Set permissions
  #

  system("sudo chown -R 0:0 #{BUILDROOT}")

  #
  # Build the package
  #

  system("dpkg --build #{BUILDROOT} tpkg-#{TPKGVER}.deb")

  #
  # Cleanup
  #

  system("sudo rm -rf #{BUILDROOT}")
end

desc 'Build tpkg client SysV packages for Solaris'
task :solaris => [:sysvpkg]
desc 'Build an tpkg client SysV package'
task :sysvpkg do
  #
  # Create package file structure in build root
  #

  rm_rf(BUILDROOT)

  bindir = File.join('usr', 'bin')
  libdir = File.join('opt', 'csw', 'lib', 'ruby', 'site_ruby', '1.8')
  mandir = File.join('usr', 'share', 'man')
  etcdir = '/etc'
  externalsdir = File.join('usr', 'lib', 'tpkg', 'externals')
  schemadir = File.join('etc', 'tpkg', 'schema')
  profiledir = File.join('etc', 'profile.d')
  copy_tpkg_files(BUILDROOT,
                  :bindir => bindir,
                  :libdir => libdir,
                  :mandir => mandir,
                  :etcdir => etcdir,
                  :externalsdir => externalsdir,
                  :schemadir => schemadir,
                  :profiledir => profiledir,
                  :copythirdparty => true,
                  :ruby => '/opt/csw/bin/ruby')

  #
  # Prep packaging files
  #

  rm_rf('solbuild')
  mkdir('solbuild')
  File.open(File.join('solbuild', 'pkginfo'), 'w') do |pkginfo|
    IO.foreach('pkginfo') do |line|
      line.sub!('%VER%', TPKGVER)
      pkginfo.puts(line)
    end
  end
  File.open(File.join('solbuild', 'prototype'), 'w') do |prototype|
    prototype.puts("i pkginfo=./pkginfo")
    cp('depend', 'solbuild/depend')
    prototype.puts("i depend=./depend")
    cp('postinstall.solaris', 'solbuild/postinstall')
    prototype.puts("i postinstall=./postinstall")
    cp('postremove.solaris', 'solbuild/postremove')
    prototype.puts("i postremove=./postremove")
    # The tail +2 removes the first line, which is the base directory
    # and doesn't need to be included in the package.
    IO.popen("find #{BUILDROOT} | tail +2 | pkgproto") do |pipe|
      pipe.each do |line|
        # Clean up the directory names
        line.sub!(BUILDROOT, '')
        # Don't force our permissions on directories
        if line =~ /^d/
          line.sub!(/\S+ \S+ \S+$/, '? ? ?')
        end
        prototype.write(line)
      end
    end
  end

  #
  # Build the package
  #

  system("cd solbuild && pkgmk -r #{BUILDROOT} -d $PWD/solbuild")
  system("pkgtrans solbuild ../OSStpkg-#{TPKGVER}.pkg OSStpkg")

  #
  # Cleanup
  #

  rm_rf('solbuild')
  rm_rf(BUILDROOT)
end

# Install based on Config::CONFIG paths
task :install, :destdir do |t, args|
  destdir = nil
  if args.destdir
    destdir = args.destdir
  else
    destdir = '/'
  end
  copy_tpkg_files(destdir,
                  :bindir => Config::CONFIG['bindir'],
                  :libdir => Config::CONFIG['sitelibdir'],
                  :mandir => Config::CONFIG['mandir'],
                  :etcdir => Config::CONFIG['sysconfdir'],
                  # Can't find a better way to get the path to the current ruby
                  :ruby => File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name']),
                  :copythirdparty => true)
end

desc 'Fetch tarball from github'
task :fetch do
  if !File.exist?(TARBALL)
    url = "http://cloud.github.com/downloads/tpkg/client/#{TARBALLFILE}"
    puts "Fetching tarball from #{url}"
    open(url) do |df|
      open(TARBALL, 'w') do |lf|
        lf.write(df.read)
      end
    end
  end
end

desc 'Prepare portfile for submission to MacPorts'
task :macport => :fetch do
  md5 = `openssl md5 #{TARBALL}`.chomp.split.last
  sha1 = `openssl sha1 #{TARBALL}`.chomp.split.last
  rmd160 = `openssl rmd160 #{TARBALL}`.chomp.split.last
  sha256 = `openssl sha256 #{TARBALL}`.chomp.split.last

  portfile = File.join(Dir.tmpdir, 'Portfile')
  rm_f(portfile)
  File.open(portfile, 'w') do |newfile|
    IO.foreach('Portfile.template') do |line|
      line.sub!('%VER%', TPKGVER)
      line.sub!('%MD5%', md5)
      line.sub!('%SHA1%', sha1)
      line.sub!('%RMD160%', rmd160)
      line.sub!('%SHA256%', sha256)
      newfile.puts(line)
    end
  end
  puts "Portfile is #{portfile}"
end

# It may seem odd to package tpkg with tpkg, but if users want to
# program against the tpkg library it is handy for them to be able to
# install and depend on the library along with other tpkgs.
# In order to reduce confusion this package does not contain any of the
# executables that go in the normal packages.
desc 'Build tpkg of tpkg library'
task :tpkgpkg do
  #
  # Create package file structure in build root
  #

  rm_rf(BUILDROOT)

  libdir = ENV['libdir'].nil?? File.join('root', 'opt', 'tpkg', 'lib', 'site_ruby', '1.8') : File.join('root', ENV['libdir'])

  copy_tpkg_files(BUILDROOT,
                  :libdir => libdir,
                  :copythirdparty => true)

  #
  # Prep tpkg.xml
  #
  File.open(File.join(BUILDROOT, 'tpkg.xml'), 'w') do |tpkgxml|
    IO.foreach('tpkg.xml') do |line|
      line.sub!('%VER%', TPKGVER)
      tpkgxml.puts(line)
    end
  end

  #
  # Build the package
  #

  system("tpkg --make #{BUILDROOT}")

  #
  # Cleanup
  #

  rm_rf(BUILDROOT)
end

