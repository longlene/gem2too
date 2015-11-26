#!/usr/bin/ruby

require 'rubygems'
require 'rubygems/package'

class RubyEbuild
  PORTDIRS=%w(/usr/portage /usr/local/portage /var/lib/layman/ /home/clx/ruby-overlay .)
  attr_accessor :name, :version, :comment, :eapi, :description, :homepage, :src_uri, :licenses, :slot, :keywords, :iuse, :depend, :rdepend

  def initialize(name, version)
    @name = name
    @version = version
    @comment = "# Distributed under the terms of the GNU General Public License v2"
    @eapi = 5
    @licenses = []
    @slot = "0"
    @keywords = ["~x86", "~amd64", "~arm"]
    @iuse = []
    @depend = []
    @rdepend = []
  end

  def exist?
    PORTDIRS.any? do |dir|
      File.exist? "#{dir}/dev-ruby/#{@name}/#{@name}-#{@version}.ebuild"
    end
  end

  def to_s
    s = ""
    s << @comment << "\n\n"
    s << "EAPI=#{@eapi}\n"
    s << "USE_RUBY=\"ruby19 ruby20 ruby21 ruby22\"\n\n"
    s << "RUBY_FAKEGEM_TASK_DOC=\"\"\n"
    s << "RUBY_FAKEGEM_EXTRADOC=\"README.md\"\n"
    s << "RUBY_FAKEGEM_GEMSPEC=\${PN}.gemspec\n\n"
    s << "inherit ruby-fakegem\n\n"
    s << "DESCRIPTION=\"#{@description}\"\n"
    s << "HOMEPAGE=\"#{@homepage}\"\n\n"
    if @licenses == nil || @licenses.length == 0
      if @description.include? "MIT"
        s << "LICENSE=\"MIT\"\n"
      else
        s << "LICENSE=\"\"\n"
      end
    else
      s << "LICENSE=\"#{@licenses.join(" ")}\"\n"
    end
    s << "SLOT=\"#{@slot}\"\n"
    s << "KEYWORDS=\"#{@keywords.join(" ")}\"\n"
    s << "IUSE=\"#{@iuse.join(" ")}\"\n\n"

    @rdepend.each do |x|
      s << "ruby_add_rdepend \"#{x}\"\n"
    end
    s << "\n"
  end


  def generate
    path = "dev-ruby"
    ebuild_dir = path + "/" + @name
    Dir.mkdir(path) unless Dir.exist?(path)
    Dir.mkdir(ebuild_dir) unless Dir.exist?(ebuild_dir)
    ebuild_file = ebuild_dir + "/" + "#{@name}-#{@version}.ebuild"
    metafile = ebuild_dir + "/" + "metadata.xml"
    File.open(ebuild_file, "w") do |file|
      file.print(to_s)
    end

    unless File.exist?(metafile)
      File.open(metafile, "w") do |file|
        file.print(metadata)
      end
    end

    File.open("mask.list", "a+") do |file|
      file.puts("#-----------------------------------")
      file.puts("##{Time.now}")
      file.puts("=dev-ruby/#{@name}-#{@version}")
    end
  end

  def metadata
    author = "loong0"
    email = "longlene@gmail.com"
    tool = "gbuild.rb"
    s = ""
    s << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    s << "<!DOCTYPE pkgmetadata SYSTEM \"http://www.gentoo.org/dtd/metadata.dtd\">\n"
    s << "\t<pkgmetadata>\n"
    s << "\t\t<maintainer>\n"
    s << "\t\t\t<email>#{email}</email>\n"
    s << "\t\t\t<name>#{author}</name>\n"
    s << "\t\t\t<tool>#{tool}</tool>\n"
    s << "\t\t</maintainer>\n"
    s << "\t\t<longdescription>\n"
    s << "#{@description}\n"
    s << "\t\t</longdescription>\n"
    s << "\t</pkgmetadata>\n"
  end
end

CACHE_FILE = "name.dat"
PORTDIRS = %w(/usr/portage /usr/local/portage /var/lib/layman/ /home/clx/ruby-overlay .)
DISTDIR = "distfiles"

#URL = "http://rubygems.org/gems"
URL = "https://ruby.taobao.org/gems"

ARGV.each do |para|
  puts "--------------------------------------------------------->"

  index = para.rindex("-")
  

  if index.nil?
    puts "Usage: #{__FILE__} name-version"
    exit 1
  end
  name = para[0, index]
  version = para[(index+1)..-1]

  if PORTDIRS.any? { |dir| File.exist? "#{dir}/dev-ruby/#{name}/#{name}-#{version}.ebuild" }
    puts "The ebuild: #{name} #{version} already exist"
    next
  end


  unless File.exist?("#{DISTDIR}/#{name}-#{version}.gem")
    puts "Downloading gem: #{name}-#{version} ..."
    system "wget -q --random-wait -O #{DISTDIR}/#{name}-#{version}.gem #{URL}/#{name}-#{version}.gem"
  end

  package = Gem::Package.new "#{DISTDIR}/#{name}-#{version}.gem"

  ebuild = RubyEbuild.new(name, version)
  if package.spec.description != nil
    ebuild.description = package.spec.description.include?(".") ? package.spec.description[0, package.spec.description.index(".")] : package.spec.description
  else
    ebuild.description = ""
  end
  ebuild.homepage = package.spec.homepage
  ebuild.licenses = package.spec.licenses
  package.spec.dependencies.each do |d|
    ebuild.rdepend << d.requirement.to_s.sub(" ", "dev-ruby/#{d.name}-").sub("~>", ">=")
  end

  puts "Generating ebuild ..."
  ebuild.generate
end
