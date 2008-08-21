#
# World of Warcraft Realm Status plugin for rbot
# by MrChucho (mrchucho@mrchucho.net)
# Copyright (C) 2008 Ralph M. Churchill
#
# Requires: insatiable appetite for World of Warcraft
#
require 'rexml/document'

class Realm
    attr_accessor :name,:status,:type,:pop
    def initialize(name,status,type,pop)
        self.name = pretty_realm(name)
        self.status = pretty_status(status)
        self.type = pretty_type(type)
        self.pop = pretty_pop(pop)
    end
    def Realm.get_realm_status(realm_name,&http_get_function)
        begin
            xmldoc = yield URI.parse("http://www.worldofwarcraft.com/realmstatus/status.xml")
            return "Error retrieving realm status." unless xmldoc
            realm_list = (REXML::Document.new xmldoc).root
            realm_data = realm_list.elements["r[@n=\"#{realm_name}\"]"]
            if realm_data and realm_data.attributes.any? then
                realm = Realm.new(
                    realm_data.attributes['n'],
                    realm_data.attributes['s'].to_i,
                    realm_data.attributes['t'].to_i,
                    realm_data.attributes['l'].to_i)
            else
                "Realm, #{realm_name}, not found."
            end
        rescue => err
            "Error retrieving realm status: #{err}"
        end
    end
    def to_s
        "#{name} (#{type}) Status: #{status} Population: #{pop}"
    end
    # just a longer, tabluar format
    # might be good if displaying multiple realms
    def _to_s
        sprintf("%-8s %-20s %-8s %-9s\n%-11s %-22s %-8s %-9s",
            "Status","Realm","Type","Population",
            status,name,type,pop)
    end
private
    def pretty_status(status)
        case status
        when 1
            "3Up"
        when 2
            "5Down"
        end
    end
    def pretty_pop(pop)
        case pop
        when 1
            "3Low"
        when 2
            "7Medium"
        when 3
            "4High"
        when 4
            "5Max(Queued)"
        end
    end
    def pretty_realm(realm)
        "#{realm}"
    end
    def pretty_type(type)
        case type
        when 0
            'RP-PVP'
        when 1
            'Normal'
        when 2
            'PVP'
        when 3
            'RP'
        end
    end
end

class RealmPlugin < Plugin
    USAGE="realm <realm> => determine the status of a Warcraft realm"
    def initialize
        super
        class << @registry
            def store(val)
                val
            end
            def restore(val)
                val
            end
        end
    end
    def help(plugin,topic="")
        USAGE
    end
    def usage(m,params={})
        m.reply USAGE
    end
    def realm(m,params)
        if params[:realm_name] and params[:realm_name].any?
            realm_name = params[:realm_name].collect{|tok|
                tok.capitalize
            }.join(' ')
            @registry[m.sourcenick] = realm_name
            m.reply Realm.get_realm_status(realm_name){|url| bot.httputil.get url}
        else
            if @registry.has_key?(m.sourcenick)
                realm_name = @registry[m.sourcenick]
                m.reply Realm.get_realm_status(realm_name){|url| bot.httputil.get url}
            else
                m.reply "I don't know which realm you want.\n#{USAGE}"
            end
        end
    end
end
plugin = RealmPlugin.new
plugin.map 'realm *realm_name', :defaults => {:realm_name => false}
