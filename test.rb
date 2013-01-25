#!/usr/bin/env ruby

require 'rubygems'
require 'inotify'
require 'find'
require 'cloudfiles'




#Include Configs

require './config.conf'



username = "ryuujinx"
api_key = "f23e5cd588ae1cc7267764ac132811c8"
auth_point = "us"
container = "test"
watchdir = "/home/dewey/testing/watch/"


#Setup AUTH_URL
if auth_point.downcase == "us"
	authurl = CloudFiles::AUTH_USA
elsif auth_point.downcase == "uk"
	authurl = CloudFiles::AUTH_UK
else
	raise("Invalid Auth Point, Change to either us or uk")
end

#Establish connection
conn = CloudFiles::Connection.new(:username => username, :api_key => api_key, :auth_url => authurl)
contobj = conn.container(container)


#path.gsub(Regexp.new(watchdir + "(.*)"), '\1')



i = Inotify.new
dirs = {}

t = Thread.new do
        i.each_event do |ev|
                p ev.inspect
                p ev.name
		path = File.join(dirs[ev.wd], ev.name)
		
                if ev.mask & Inotify::DELETE > 0
			if ev.mask & Inotify::ISDIR > 0
				i.rm_watch(ev.wd)
				p "removed watch " + path
			end
                        p "delete " + ev.name
			contobj.delete_object(path.gsub(Regexp.new(watchdir + "(.*)"), '\1'))

                elsif ev.mask & Inotify::CREATE > 0
			if ev.mask & Inotify::ISDIR > 0
                                i.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::CLOSE_WRITE)
                                p "added watch " + path
			else
				o = contobj.create_object(path.gsub(Regexp.new(watchdir + "(.*)"), '\1'), make_path = true)
				o.load_from_filename(path)
			end	
                        p "create " + ev.name

                elsif ev.mask & Inotify::MOVED_TO > 0
			if ev.mask & Inotify::ISDIR > 0
                                i.add_watch(File.join(dirs[ev.wd], ev.name), Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::CLOSE_WRITE)
                                p "added watch " + path
                        end
                        p "moved " + ev.name
			o = contobj.create_object(path.gsub(Regexp.new(watchdir + "(.*)"), '\1'))
                        o.load_from_filename(path)


		elsif ev.mask & Inotify::CLOSE_WRITE > 0
			p "modified " + ev.name
			o = contobj.object(path.gsub(Regexp.new(watchdir + "(.*)"), '\1'))
                        o.load_from_filename(path)
					
                end
        end
end


Find.find(watchdir) do |dir|
        if ['.svn', 'CVS', 'RCS'].include? File.basename(dir) or !File.directory? dir
                Find.prune
        else
                begin
                        puts "Adding #{dir}"
                        wd = i.add_watch(dir, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::CLOSE_WRITE)
                        dirs[wd] = dir
                rescue
                        puts "Skipping #{dir}: #{$!}"
                end
        end
end

t.join

