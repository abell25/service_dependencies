require 'yaml'

@d = []
@s = []
@lines = []

def make_file
end

def run
  contents = File.read("./stats.rb")
  @stats = YAML::load(contents)
  @s = @stats.map{|s| s[0] }.uniq.compact
  @d = @stats.map{|s| s[1]["dependencies"]}.flatten.uniq.compact
  #dups
  #@d = @d.map {|a| @dups.key?(a) ? @dups[a] : a }
  @s.sort.each do |service|
    deps = @stats[service]["dependencies"]
    deps = deps.map{|a| a.split(".").join("-") unless a.nil?}.compact
    #deps = deps.map {|a| @dups.key?(a) ? @dups[a] : a }
    @lines << "{\"name\":\"#{service}\",\"size\":1,\"imports\":[#{deps.nil? ? "" : deps.map{|e| "\"#{e}\""}.join(",")}]}"
  end

  (@d-@s).sort.each do |elem|
    name = elem.split(".").join("-")
    @lines << "{\"name\":\"#{name}\",\"size\":1,\"imports\":[]}"
  end
  makeFile
end

def makeFile
  File.open("stats.json", "w") do |file|
    file.puts "[\n#{@lines.join(",\n")}\n]"
  end
end

def getDups
  
end

def dups
  @seen = []
  @dups = {}
  @d.sort.each do |e|
    @seen.each do |s| 
      if e[/^#{s}/] 
        puts "[#{e}] and [#{s}]"
        @dups[s] = "#{s}.Duplicate"
      end
    end
    @seen << e
  end
end

if __FILE__ == $0
  run()
end
