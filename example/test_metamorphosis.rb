require 'metamorphosis'

module Project
  VERSION = 0.1

  class Speaker
    def say something
      "say: #{something}"
    end
  end

  module Template
    class Templator
    end
  end

  class Server
    Project.extend Metamorphosis

    #Project.metamorphose!

    puts "default:"
    s = Project::Speaker.new
    p s.say 'hello world'
    puts

    puts "backward plugin:"
    Project.activate 'backward'
    puts "previous object: #{s.say 'hello world'}"
    s2 = Project::Speaker.new
    puts "new object: #{s2.say 'hello world'}"
    puts

    puts "loudness + backward plugin:"
    Project.activate 'loudness'
    p Project::Speaker.new.say "super loud!"

    #puts Base.plugins

    #TODO
    #Base.shutdown "backward"
  end

end

Project::Server.new
