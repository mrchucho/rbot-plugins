#
# Dictionary plugin for rbot
# by MrChucho (mrchucho@mrchucho.net)
# Copyright (C) 2008 Ralph M. Churchill
#
require 'open-uri'
require 'hpricot'

module Dictionary

    def query_definition(word)
        url = "http://search.yahoo.com/search?p=define+#{word}"
        begin
		doc = Hpricot(open(url))
		definitions = [ 
		  doc.search("//div[@id='yschiy']//a[@class='yschttl']").text,
		  doc.search("//div[@id=yschiy]/dl/").text 
		]   
		definitions.reject{|d| d.nil?}.join(" ")
        rescue => err
            raise err
        end
    end
end

class DictionaryPlugin < Plugin
    include Dictionary
    USAGE="define [WORD] => define a word"
    def help(plugin,topic="")
        USAGE
    end
    def usage(m,params={})
        m.reply USAGE
    end
    def define(m,params)
        word = params[:word].join('+')
        if word =~ /rbot/ then
            m.reply "NOUN: 1. A totally kickass IRC rbot written in Ruby"
            return
        end
        begin
            rply = query_definition(word)
            if rply
                m.reply rply
            else
                m.reply "Couldn't find a definition for your \"word\"..."
            end
        rescue => e
            m.reply "Error"
        end
    end
end

class Tester
    include Dictionary
    def define(word)
        puts query_definition(word)
    end
end

plugin = DictionaryPlugin.new
plugin.map 'define *word', :defaults => {:word => false}
