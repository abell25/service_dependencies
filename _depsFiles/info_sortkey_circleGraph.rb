require 'Hpricot'
require 'open-uri'
require 'net/http'

require 'util'

@res = {}

def jsonStats
  stats = getstats
  allDeps = []
  services = []
  json = []
  stats.sort.each do |service, v|
    stat = stats[service]
    deps =  stat["dependencies"].nil? "" : stat["dependencies"].map{|dep| "\"#{dep}\""}.join(",")
    allDeps += stat["dependencies"]  unless stat["dependencies"].nil?
    services << service

    jsonLine = "{\"name\": \"#{service}\", \"size\":1, \"imports\": [#{deps}]}"
    json << jsonLine
  end
  servicesToBeAdded = allDeps.uniq - services.uniq
  servicesToBeAdded.each {|s| json << "{\"name\": \"#{s}\", \"size\":1, \"imports\": []}" }

  resultStr = "[#{json.join(",")}]"
  File.open("depsJsonTemp.html", "a") do |file|
    file.puts resultStr
  end
end

def tableStats
  stats = getstats
  table = "<table class=\"sortable\"><tr><th>Service</th><th>.Net</th><th>VS version</th>" \
    + "<th>Quad<br />Framework</th><th>dependencies</th></tr>"
  stats.sort.each do |service, v|
    stat = stats[service]
    table += "<tr>"
    table += "<td>" + service + "</td>"
    table += "<td>" + stat["netVersion"] + "</td>"
    table += "<td>" + stat["vsVersion"] + "</td>"
    table += "<td>" + stat["QuadFramework"] + "</td>"
    table += "<td sorttable_customkey=\"#{ stat["dependencies"].nil? ? 0 : stat["dependencies"].length }\" >" \
   		    + stat["dependencies"].join(", ") + "</td>"
    table += "</tr>"
  end
  table += "</table>"
  filename = "statsTable#{Util.tmStamp}.html"
  FileUtils.cp("header.html", filename)
  File.open(filename, "a") do |file|
    file.puts "<body>"
    file.puts table
    file.puts "</body></html>"
  end
end

def getstats
  return @res if @res.any?
  Util.ServiceFolders do |service|
    @res[service] = {
      "dependencies" => uniqDependencies(service),
      "vsVersion"    => vsVersion(service),
      "netVersion"   => highestDotNetVersion(service),
      "QuadFramework" => getQuadFramework(service)
    }
    # @res[service]["deps"] = getDependencies(service)
    # @res[service]["vsVersion"] = vsVersion(service)
    # @res[service]["netVersion"] = highestDotNetVersion(service)
  end
  return @res
end

def getQuadFramework service
  version = Util.getDllVersion(service, "QuadFramework")
  if version.nil?
    return "n/a"
  else
    return "#{version[0..2]} <br /> #{version[0..2] < '2.1' ? "Needs<br />upgrade" : ''}"
  end
end

#Takes a string and returns the Visual Studio version
def vsVersion service
  slnFile = Util.getSln(service)
  while line = slnFile.readline
    return line[/Visual Studio \d{4}/] if line =~ /Visual Studio \d{4}/
  end
  #version = slnFile.readline.chomp
  #return version[2..-1]
end

def uniqDependencies service
  deps = getDependencies(service)
  selfOwned = findProjs(service)
  deps = deps.select {|d| !selfOwned.member?(d) } if !selfOwned.nil?
  blackList = /System|Ibatis|Microsoft|Logging|log4net|Rhino|nunit|Sybase|Castle|IDesign|Monorail|Proxy|NVelocity/
  deps = deps.select {|d| d !~ blackList}
  return deps
end

#Returns an array of dependencies
def getDependencies service
  deps = []
  Util.csprojs(service).each do |csproj|
    deps += getDeps(csproj) 
  end
  return deps.uniq
end

# Returns all self-owned projs for a solution
def findProjs service
  slnFile = Util.getSln(service)
  return nil if slnFile.nil?
  projs = []
  slnFile.readlines.each do |line|
    if line =~ /^Project\(\"[^\"]+\"\)\s*=\s*\"([^\"]+)\"/
      projs.push line.match(/^Project\(\"[^\"]+\"\)\s*=\s*\"([^\"]+)\"/)[1]
    end
  end
  return projs
end

def highestDotNetVersion service
  versions = []
  Util.csprojs(service).each do |csproj|
    versions << dotNetVersion(csproj)
  end
  return "unknown" if !versions.any?
  return versions.max
end

# takes xml file and returns .net version
def dotNetVersion csproj
  return csproj.search("targetframeworkversion").text
end

# ** make actually just get this from the dependancy list **
def quadCoreVersion csproj
  csproj.search("reference") do |ref|
    match = get_attribute("include").match(/Quad.Core/)
    return match[0] if !match.nil?
  end
end

# return list of dependencies from csproj file
def getDeps csproj
  deps = []
  csproj.search("reference") do |ref|
    deps << ref.get_attribute("include").match(/^([^,]+),*/)[1]
  end
  return deps
end




