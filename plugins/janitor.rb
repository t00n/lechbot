# encoding: utf-8

require 'cinch'
require 'rufus/scheduler'
require 'open-uri'
require 'json'

class Janitor
    include Cinch::Plugin

    set :help, "Tous les mercredis, si le hackerspace est ouvert, deux volontaires sont désignés pour sortir la poubelle"

    def notification name
        amq_conn = Bunny.new config[:amq_server]
        amq_conn.start
        chan = amq_conn.create_channel
        queue = chan.queue config[:amq_queue]
        queue.publish({
            'name' => name, 
            'time' => Time.now.strftime("%Y-%m-%d %H:%M:%S")
        }.to_json)
    end

    listen_to :connect, :method => :start
    def start *args
        now = Time.now
        wed = Time.new now.year, now.month, now.day, 20   #Today 20h
        wed += 86400 until wed.wednesday? && wed>Time.now #Next wednesday, 20h

        @scheduler = Rufus::Scheduler.new
        bot.info "Created scheduler for JANITOR"

        @scheduler.every '1w', first_at:wed do
            pamela_data = JSON.parse open(config[:pamela_url]).read
            people = pamela_data['color'] + pamela_data['grey']
            unless people.empty?
                randomly_chosen = people.shuffle[0...2] 
                notification "trash"
                bot.channels.first.send "Salut #{randomly_chosen*' & '} ! Vous pourriez vider la poubelle s'il-vous-plaît ?"
            end
        end
    end
end
