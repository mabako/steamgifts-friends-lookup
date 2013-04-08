require 'net/http'
require 'open-uri'
require 'uri'

class StalkerController < ApplicationController
  class Stalked
    def initialize name, steamid
      @name = name
      @steamid = steamid
    end
    
    def name
      @name
    end
    
    def sg_url
      "http://www.steamgifts.com/user/#{@name}"
    end
    
    def steam_url
      "http://steamcommunity.com/profiles/#{@steamid}"
    end

    def stalk_url
      "/#{@steamid}"
    end
  end

  class Stalkable
    def initialize type, id
      @type = type
      @id = id

      fetch_friends
    end
    
    def u
      @u || Stalked.new('?', 0)
    end
    
    def friends
      @friends
    end

    def friends_url
      puts "requesting friends of #{@id}"
      "http://steamcommunity.com/#{@type}/#{@id}/friends?xml=1"
    end

    def fetch_friends
      doc = Nokogiri::XML(open(friends_url).read)

      @friends = []
      doc.search('friend').each do |f|
        stalked = Rails.cache.read(f.content)
        unless stalked
          friend = f.content
          profile = get_profile friend
          stalked = Stalked.new(profile, friend) unless profile.nil?
          Rails.cache.write(f.content, stalked) unless stalked.nil?
        end
        @friends << stalked unless stalked.nil?
      end
      puts @friends
      @friends.sort!{ |a, b| a.name.downcase <=> b.name.downcase }

      doc.search('steamID64').each do |u|
        @u = Stalked.new(get_profile(u.content), u.content)
      end
    end

    def get_profile friend
      puts "fetching profile #{friend}"
      u = URI.parse("http://www.steamgifts.com/user/id/#{friend}")
      h = Net::HTTP.new u.host, u.port
      head = h.start do |ua|
        ua.head u.path
      end

      return nil if head['Location'].nil?
      head['Location'][6..-1]
    end
  end
  
  def id
    @s = Stalkable.new('id', params[:id])
    render :stalker
  end
  
  def profile
    @s = Stalkable.new('profiles', params[:id])
    render :stalker
  end
end
