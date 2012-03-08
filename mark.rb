class MarkPlugin < Plugin
    def help(plugin,topic="")
        "mark => sets a marker for you"
    end
    def usage(m,params={})
        m.reply 'mark'
    end
    def privmsg(m)
        m.reply '****************MARK*********************'
    end
end
plugin = MarkPlugin.new
plugin.register("mark")

