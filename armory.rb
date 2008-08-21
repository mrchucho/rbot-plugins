#
# World of Warcraft Armory plugin for rbot
# by MrChucho (mrchucho@mrchucho.net)
# Copyright (C) 2008 Ralph M. Churchill
#
require 'hpricot'
require 'open-uri'

class Armory
  def basic_info(realm,player)
  begin
    doc = open("http://armory.worldofwarcraft.com/character-sheet.xml?r=#{realm}&n=#{player}",
	       "User-Agent" => "Mozilla/5.0 Gecko/20070219 Firefox/2.0.0.2") {|f| Hpricot(f)}

    char = (doc/'character').first
    name = char['name']
    level = char['level']
    klass = char['class']
    kills = (doc/'pvp/lifetimehonorablekills').first['value']
    buffs = (doc/'buffs/spell').collect {|b| b['name']}

    desc = "#{name} is a level #{level} #{klass} with #{kills} HKs!\n"
    desc << "Current Buffs: #{buffs.join(', ')}"
    desc
  rescue OpenURI::HTTPError => e
	      case e
	      when /304/:
	      when /404/:
		  raise "Data for #{@station} not found"
	      else
		  raise "Error retrieving data: #{e}"
	      end
  rescue Exception => e
    puts "Error: #{e}"
  end
  end
end

class ArmoryPlugin < Plugin
  USAGE = "armory <realm> <character> => display info about a player"
  def help(plugin,topic="")
    USAGE
  end
  def usage(m,params={})
    m.reply USAGE
  end
  def armory(m,params)
    a = Armory.new
    m.reply a.basic_info(params[:realm],params[:player])
  end
end
plugin = ArmoryPlugin.new
plugin.map "armory :realm :player"
