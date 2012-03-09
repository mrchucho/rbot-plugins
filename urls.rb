#
# URL Cataloging and Reporting plugin for rbot
# by MrChucho (mrchucho@mrchucho.net)
# Copyright (C) 2008 Ralph M. Churchill
#
require 'sqlite3'
require 'cgi'
require 'uri'
require 'date'

class FakeDB
  attr_accessor :results_as_hash
  def table_info(table); return {} ; end
  def execute_batch(sql); end;
  def execute(sql); end;
end

=begin
Notes:
    1. need to make sure I limit the number of responses, use BotConfig 'max'
    2. need a way to browse/list urls
    3. keywords:
        * today
        * yesterday
        * <nick>
        * key off of .com/.net/.edu, then search host?
    4. output format? URL [date]<user>
    5. google-like syntax? 
        * search site:www.host.com
        * search user/nick:Carebear
        * search since/before/after:<date>
        * search last #
=end


=begin
    SQLite3 Config (http://web.utk.edu/~jplyon/sqlite/SQLite_optimization_FAQ.html)
    1. PRAGMA default_synchronous=OFF;
    2. PRAGMA count_changes=OFF;
=end

TITLE_RE = /<\s*?title\s*?>(.+?)<\s*?\/title\s*?>/im
DATABASE = File.join(File.dirname(__FILE__),"data","urls.db")
DATETIME_FORMAT = '%m/%d/%y'
USAGE = "urls [query|(today|tomorrow)] [limit]\nurls <last # urls>"

class UrlsPlugin < Plugin
    Irc::Bot::Config.register BotConfigIntegerValue.new('murls.max_results',
                                                 :default => 10,
                                                 :validate => Proc.new{|v| v>0 and v<13},
                                                 :desc => "Number of URL Search Results to return.")
    def initialize
      super
      begin
        @db = SQLite3::Database.new(DATABASE)
        @db.results_as_hash = true

        #@db.create_function('date_only',1) do |ctx,dt|
        #DateTime.parse(dt).strftime(DATETIME)
        #end
      rescue => e
        @db = FakeDB.new
        puts "Error opening database: #{e}"
      end
    end

    def create_database
        if @db.table_info("urls").empty? then
            puts "Database does not exist, creating"
            @db.execute_batch(<<EOF
CREATE TABLE urls (
id INTEGER PRIMARY KEY AUTOINCREMENT,
url TEXT NOT NULL,
host TEXT,
title TEXT,
seen_at DATETIME,
submitted_by VARCHAR(255),
channel VARCHAR(255)
);
EOF
                       )
        else
            puts "Database exists"
        end
    end

    def help(plugin,topic="")
      "All your URLs belong to us!"
    end

    def listen(m)
      return unless m.kind_of?(PrivMessage)
      return if m.address?

      if m.message =~ /(f|ht)tps?:\/\//
        if m.message =~ /((f|ht)tps?:\/\/.*?)(?:\s+|$)/
          urlstr = $1
        title = find_title(urlstr)
        inform_title(m,urlstr,title) if title
        save_url(m,urlstr,title)
        end
      end
    end

    def search(m, parameters)
      results = Array.new
      # in case they're still using
      # the "urls search" syntax, remove the first "search"
      params = parameters[:query]
      params.shift if (params[0] == "search" && params.size>1)

      maxurls = @bot.config['murls.max_results']
      if params[-1].to_i > 0 then
        wants = params.pop.to_i
        limit = (wants <= maxurls) ? wants : maxurls
      else
        limit = maxurls
      end
      query = params.join(' ').downcase
      if query.to_i > 0 then
        wants = query.to_i
        @db.execute("""
                select distinct url,seen_at,submitted_by
                from urls
                order by seen_at desc
                limit ?""",
                  (wants <= maxurls) ? wants : maxurls){|row| results.push row_to_message(row)}
      elsif is_member(m,query) then
        @db.execute("""
                select distinct url,seen_at,submitted_by
                from urls
                where lower(submitted_by) = lower(?)
                order by seen_at desc
                limit ?""",
                  query,limit){|row| results.push row_to_message(row)}
      elsif query == 'yesterday'
        @db.execute("""
                select distinct url,seen_at,submitted_by
                from urls
                where strftime('%Y%m%d',seen_at)=strftime('%Y%m%d','now','-1 days')
                order by seen_at desc
                limit ?""",
                  limit){|row| results.push row_to_message(row)}
      elsif query == 'today'
        @db.execute("""
                select distinct url,seen_at,submitted_by
                from urls
                where strftime('%Y%m%d',seen_at)=strftime('%Y%m%d','now')
                order by seen_at desc
                limit ?""",
                  limit){|row| results.push row_to_message(row)}
      elsif query == 'tomorrow'
        results.push "I cannot predict the future..."
      else
=begin
            # hrm, not sure. it seems like you should probably *always* search
            # the hostname, too
            if query =~ /\.(com|net|org|gov|tv|info|edu)/ then
                @db.execute("""
                    select distinct url
                    from urls
                    where (lower(host) like '%#{query}%' or
                            lower(title) like '%#{query}%')
                    order by seen_at desc
                    limit ?""",
                    limit){|row| results.push row}
            else
                @db.execute("""
                    select distinct url
                    from urls
                    where lower(title) like '%#{query}%'
                    order by seen_at desc
                    limit ?""",
                    limit){|row| results.push row}
            end
=end
        @db.execute("""
                    select distinct url,seen_at,submitted_by
                    from urls
                    where (lower(host) like '%#{query}%' or
                            lower(title) like '%#{query}%')
                    order by seen_at desc
                    limit ?""",
                      limit){|row| results.push row_to_message(row)}
      end

      if results.empty?
        m.reply "No matching URLs found."
      else
        results.each{|res| m.reply res}
      end
    end

    def stats(m,params)
      m.reply "-=[ Today ]=-"
      @db.execute("""
            select submitted_by,count(url)
            from urls
            where strftime('%Y%m%d',seen_at) = strftime('%Y%m%d','now')
            group by submitted_by
            order by count(url) desc"""){|row| m.reply "#{row[0]} => #{row[1]}"}

        m.reply "-=[ Top 10 ]=-"
        @db.execute("""
            select submitted_by,count(url)
            from (select distinct submitted_by,url from urls)
            group by submitted_by
            order by count(url) desc
            limit 10"""){|row| m.reply "#{row[0]} => #{row[1]}"}
    end

    def find_title(urlstr)
      pagedata = @bot.httputil.get(URI.parse(urlstr))
      return unless TITLE_RE.match(pagedata)
      title = $1.strip.gsub(/\s*\n+\s*/, " ")
      title = CGI::unescapeHTML title
      # title = title[0..255] if title.length > 255
      return title
    end

    def inform_title(m,urlstr,title)
      m.reply "13#{title} 14-=[ #{urlstr} ]=-"
    end

    def save_url(m,urlstr,title)
      url = URI.parse(urlstr)
      begin
        @db.execute("insert into urls(url,host,title,seen_at,submitted_by,channel) values(?,?,?,datetime('now'),?,?)",
                    urlstr,url.host,title,m.sourcenick,m.channel)
      rescue => err
        m.reply "Error: #{err}"
      end
    end

    def is_member(m,query)
      return false if not m.channel
      #q = query.downcase
      #return @bot.channels[m.channel].users.keys.find {|u| u.downcase == q}
      return m.channel.has_user?(query)
    end

    def row_to_message(row)
      "#{row['url']} [#{DateTime.parse(row['seen_at']).strftime(DATETIME_FORMAT)}] <#{row['submitted_by']}>"
    end
end

plugin = UrlsPlugin.new
plugin.map('urls *query', :action => 'search', :defaults => {:query => false})
plugin.map('urlstats', :action => 'stats')
