#!/usr/bin/ruby -w

#
# Test tpkg's query features
#

require 'test/unit'
require File.dirname(__FILE__) + '/tpkgtest'

class TpkgQueryTests < Test::Unit::TestCase
  include TpkgTests
  
  def setup
    Tpkg::set_prompt(false)
    
    @tempoutdir = Tempdir.new("tempoutdir")  # temp dir that will automatically get deleted at end of test run
                                             # can be used for storing packages

    # Make up our regular test package
    @pkgfile = make_package(:output_directory => @tempoutdir)
  end

  def test_metadata_for_installed_packages
    testbase = Tempdir.new("testbase")
    apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => '2.0' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
    tpkg = Tpkg.new(:base => testbase, :sources => [apkg])
    tpkg.install(['a'], PASSPHRASE)
    metadata = tpkg.metadata_for_installed_packages
    assert_equal(1, metadata.length)
    assert_equal('a', metadata.first[:name])
    FileUtils.rm_f(apkg)
    FileUtils.rm_rf(testbase)
  end

  def test_installed_packages
    # FIXME
  end
  
  def test_installed_packages_that_meet_requirement
    testbase = Tempdir.new("testbase")
    tpkg = Tpkg.new(:base => testbase)
    pkgfiles = []
    ['1.0', '2.0'].each do |ver|
      srcdir = Tempdir.new("srcdir")
      FileUtils.cp(File.join(TESTPKGDIR, 'tpkg-nofiles.xml'), File.join(srcdir, 'tpkg.xml'))
      pkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => ver }, :source_directory => srcdir, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg.install([pkg], PASSPHRASE)
      pkgfiles << pkg
      FileUtils.rm_rf(srcdir)
    end
    result = tpkg.installed_packages_that_meet_requirement
    assert_equal(2, result.length)
    result = tpkg.installed_packages_that_meet_requirement({:name => 'a'})
    assert_equal(2, result.length)
    result = tpkg.installed_packages_that_meet_requirement({:name => 'a', :minimum_version => '2.0'})
    assert_equal(1, result.length)
    pkgfiles.each { |pkg| FileUtils.rm_f(pkg) }
    FileUtils.rm_rf(testbase)
  end
  
  def test_files_for_installed_packages
    pkgfiles = []
    # Make up a couple of packages with different files in them so that
    # they don't conflict
    ['a', 'b'].each do |pkgname|
      srcdir = Tempdir.new("srcdir")
      FileUtils.cp(File.join(TESTPKGDIR, 'tpkg-nofiles.xml'), File.join(srcdir, 'tpkg.xml'))
      FileUtils.mkdir_p(File.join(srcdir, 'reloc', 'directory'))
      File.open(File.join(srcdir, 'reloc', 'directory', pkgname), 'w') do |file|
        file.puts pkgname
      end
      pkgfiles << make_package(:output_directory => @tempoutdir, :change => {'name' => pkgname}, :source_directory => srcdir, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      FileUtils.rm_rf(srcdir)
    end
    
    testbase = Tempdir.new("testbase")
    tpkg = Tpkg.new(:base => testbase, :sources => pkgfiles)
    tpkg.install(['a', 'b'], PASSPHRASE)
    
    files = tpkg.files_for_installed_packages
    assert_equal(2, files.length)
    files.each do |pkgfile, fip|
      assert_equal(0, fip[:root].length)  # Neither package has non-relocatable files
      assert_equal(2, fip[:reloc].length)  # Each package has two relocatable files (a directory and a file)
      pkgname = fip[:metadata][:name]
      assert_equal(File.join('directory', ''), fip[:reloc].first)
      assert_equal(File.join('directory', pkgname), fip[:reloc].last)
      assert_equal(File.join(testbase, 'directory', ''), fip[:normalized].first)
      assert_equal(File.join(testbase, 'directory', pkgname), fip[:normalized].last)
    end
    
    files = tpkg.files_for_installed_packages(pkgfiles.first)
    assert_equal(1, files.length)
    
    FileUtils.rm_rf(testbase)
    pkgfiles.each { |pkg| FileUtils.rm_f(pkg) }
  end
  
  def test_files_in_package
    files = Tpkg::files_in_package(@pkgfile)
    assert_equal(0, files[:root].length)
    pwd = Dir.pwd
    Dir.chdir(File.join(TESTPKGDIR, 'reloc'))
    reloc_expected = Dir.glob('*')
    Dir.chdir(pwd)
    assert_equal(reloc_expected.length, files[:reloc].length)
    reloc_expected.each { |r| assert(files[:reloc].include?(r)) }
    files[:reloc].each { |r| assert(reloc_expected.include?(r)) }
  end
end

