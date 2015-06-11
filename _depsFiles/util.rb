require 'Hpricot'
require 'open-uri'
require 'net/http'
require 'Win32API'
require 'fileutils'

module Util
  ROOT = "http://smartrack/svn"

  def self.getHrefs page
    doc = Hpricot(open(page))
    hrefs = doc.search("a").map {|e| e.get_attribute("href")}
  
    return hrefs
  end
  
  def self.isDir path
    return path =~ /\/$/ || File.extname(path) == ""
  end

  # Iterates through all servicesFolder
  # how to use: AllServiceFolders {|h| puts h}
  def self.AllServiceFolders
    getHrefs(ROOT).each do |href|
      yield href.delete('/') if isDir(href)
    end
  end

  def self.ServiceFolders
    File.open('ServicesWithSln.txt', 'r') do |f|
      while line = f.gets
	yield line.chomp unless line.nil?
      end
    end
  end

  #This takes a couple minutes to regenerate...
  def self.GetServicesWithSln 
    File.open('ServicesWithSln.txt', 'w') do |file|
      AllServiceFolders do |service|
        if !getSln(service).nil? and service =~ /PostPress|^ML00|Postage|ListRequest/
	  file.puts service
	  puts "Service successfully added!"
	end
      end
    end
  end

  # gets a service's .sln file
  def self.getSln service
    url = File.join(ROOT, service, "trunk", service + ".sln")
    begin 
      trunk = open(url)
    rescue OpenURI::HTTPError => e
      puts "The url #{url} was not found! error[#{e}]"
    end
  end

  # returns a service's .csprojs files
  def self.csprojs service
    res = getProjects(service).map do |proj|
      csproj = getCsProj(service, proj)
      csproj unless csproj.nil?
    end
    puts "*****no csprojs! for #{service}******" if res.length == 0 
    return res.compact
  end

  # returns a list of projects for a given service
  def self.getProjects service
    url = File.join(ROOT, service, "trunk", "src")
    url = File.join(url, service) if service =~ /ML0049_SRV/
    res = getHrefs(url).map do |proj|
      proj.chop if isDir(proj) and proj !~ /\.\./
    end
    return res.compact
  end

  #Helper function: gets a csproj file for a particular project
  def self.getCsProj service, project
    url = File.join(ROOT, service, "trunk", "src")
    url = File.join(url, service) if service =~ /ML0049_SRV/
    url = File.join(url, project, project + ".csproj")
    begin
      src = Hpricot(open(url))

    rescue
      puts "couldnt find #{url}.."
      res = Util.getHrefs(File.dirname(url)).select {|x| x =~ /\.csproj$/ }
      if !res.nil? and res.length > 0
        return Hpricot(open(File.join(File.dirname(url), res.pop)))
      else
        puts "The url #{url} was not found! error[#{$!}]"
      end
    end
  end
############################### DLL STUFF ##########################################


  def self.dllVersion filename
    s=""
    vsize=Win32API.new('version.dll', 'GetFileVersionInfoSize', 
                   ['P', 'P'], 'L').call(filename, s)
    #p vsize
    if (vsize > 0)
      result = ' '*vsize
      Win32API.new('version.dll', 'GetFileVersionInfo', 
               ['P', 'L', 'L', 'P'], 'L').call(filename, 0, vsize, result)
      rstring = result.unpack('v*').map{|s| s.chr if s<256}*''
      r = /FileVersion..(.*?)\000/.match(rstring)
      return r ? r[1] : 'unknown' 
    else
      puts "No Version Info"
    end
  end

  # gets the Dll version for a service (in ext_bin)
  def self.getDllVersion service, dll
    begin
      File.delete 'tmp.dll' if File.exists?('tmp.dll')
      url = File.join(ROOT, service, "trunk", "ext_bin", dll + ".dll")
      File.open('tmp.dll', 'wb') do |saved_file|
         open(url, 'rb') do |read_file|
   	   saved_file.write(read_file.read)
         end
      end
      version = dllVersion 'tmp.dll'
      File.delete 'tmp.dll'
      return version
    rescue
    end
  end

  def self.getExtBinFiles service
    url = File.join(ROOT, service, "trunk", "ext_bin")
    begin
      getHrefs(url).select{|e| !isDir e}
    rescue 
      puts "No ext bin found for #{url}! err: #{$!}"
    end
  end

  def self.tmStamp
    Date.today.to_s + "_%02d%02d%02d" % [Time.now.hour, Time.now.min, Time.now.sec]
  end

##################################################################################
 
  def self.getServices
    file = File.new("TeamCityArtifacts.txt", "w")
    dirs = []
    files = []
    getHrefs(ROOT).each do |href|
      if isDir(href)
        dirs.push(href)
      else
  	  files.push(href)
      end
    end
  
    dirs.each do |dir| 
      fullName = File.join(ROOT, dir, "trunk", "src")
      file.puts "Service:  #{dir}"
      puts dir
      begin
        getHrefs(fullName).each do |href|
          if isDir(href) and !href.upcase.include?("TEST")
            file.puts "src\\#{href.chop}\\bin\\Release\\*.dll => out\\release"
          end
        end
      rescue
      end
    end
  end
  

  def self.copyNdeep from, to, level, verbose=false
        directories = []
        files = []
        Dir.entries(from).each do |entry| 
  	    absPath = File.join(from, entry)
  	    next if entry =~ /^\.{1,2}$/
  	    if File.directory?(absPath)
  		  directories.push(entry)
  	    else
  		  files.push(entry)
  	    end
  	    files.each do |file|
  		  begin
  			 FileUtils.copy(File.join(from, file), to)
  		  rescue
  			puts "error: #{$!}, moving to the next file" if verbose
  		  end
  	    end
        end
        directories.each do |d|
        	  unless File.exist?(File.join(to, d))
        	        puts "copying from [#{File.join(from, d)}] to [#{File.join(to, d)}]" if verbose
  		addFolder(d, to)
        		copyNdeep(File.join(from, d), File.join(to, d), level-1) unless level <= 0
        	  else
        		puts "Skipping service #{File.join(to, d)}" if verbose
        	  end	
        end
  end
  
  
end

if __FILE__ == $0
	
end
  
  
