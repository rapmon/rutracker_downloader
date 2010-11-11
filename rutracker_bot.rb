require 'net/http'
require 'uri'
require 'yaml'
require 'optparse'
require 'net/smtp'

CONFIG_FILE = '/home/user/tracker/bot_config.yml'
TORRENTS_UPLOAD_PATH = '/home/user/tracker/torrents' 
GMAIL_SMTP = 'smtp.gmail.com'

def options
  options = {}

  optparse = OptionParser.new do|opts|
    opts.banner = "Usage: torrentbot.rb [options] [url url1 url2 ...]  \n    url format = [http://rutracker.org/forum/viewtopic.php?t=123456 | 123456 ]"

    options[:add] = false
      opts.on( '-a', '--add', 'Add one or many torrents for downloading' ) do
      options[:add] = true
    end

    options[:remove] = false
      opts.on( '-r', '--remove', 'Remove one or many torrents from downloading' ) do
      options[:remove] = true
    end

    options[:delall] = false
      opts.on( '-d', '--delall', 'Remove all torrents from downloading' ) do
      options[:delall] = true
    end

    opts.on( '-h', '--help', "Display this screen" ) do
      puts opts
      exit
    end
  end
  
  optparse.parse!

  puts "No compatiable options -a and -r, use them separate" if (options[:add] and (options[:remove] or options[:delall]))

  if (options[:add])
    ARGV.each do |t|
      if ( t =~ /(.*)(^|=)(\d+)(.*)/)
        new_torrent($3)
      end
    end 
  end

  if (options[:remove])
    ARGV.each do |t|
      if ( t =~ /(.*)(^|=)(\d+)(.*)/)
        remove_torrent($3)
      end
    end
  end

  if (options[:delall])
    remove_all_torrents
  end
  
end

def read_config
  YAML.load_file(CONFIG_FILE)
end

def set_size(id,size)
  settings = YAML.load_file(CONFIG_FILE)
  settings["torrents"][id] = size
  File.open(CONFIG_FILE, 'w') {|f| YAML.dump(settings, f)}
end

def new_torrent(id)
  settings = YAML.load_file(CONFIG_FILE)
  unless (settings["torrents"].member?(id)) 
    settings["torrents"][id] = 0
  end
  File.open(CONFIG_FILE, 'w') {|f| YAML.dump(settings, f)}
end

def remove_torrent(id)
  settings = YAML.load_file(CONFIG_FILE)
  settings["torrents"].delete(id)
  File.open(CONFIG_FILE, 'w') { |f| YAML.dump(settings, f)}
end

def remove_all_torrents
  settings = YAML.load_file(CONFIG_FILE)
  settings["torrents"] = {}
  File.open(CONFIG_FILE, 'w') { |f| YAML.dump(settings, f)}
end

def write_file(filename, data)
  file = File.new(filename, "w")
  file.puts data
  file.close
end

def size_mult (str)
  r = 1;
  if (str == "MB")
    r = 1000
  end
  if (str == "GB")
    r = 1000000
  end
  r
end

def send_mail(from, pass, to, subject, data)
  begin
    smtp = Net::SMTP.new GMAIL_SMTP, 587
    smtp.enable_starttls

    message = <<EMAIL_MESSAGE
From: RuTracker Bot <#{from}>
To: <#{to}>
Subject: #{subject}
#{data}
EMAIL_MESSAGE

    smtp.start(GMAIL_SMTP,
               from, pass, :plain ) do |smpt|
        smtp.send_message message,
            from,
            to
    end
  rescue
    puts "Error while sending mail"
  end
end

def remove_torrent_from_list(filename)
  out = %x[transmissioncli -i #{filename} | sed -n \'\/^hash:\/s\/^hash:\\(.*\\)\/\\1\/p\']
  sout = %x[transmission-remote -t #{out.chomp} -r]
end

def rutracker_parse(settings)
  begin
    http = Net::HTTP.new('login.rutracker.org', 80)
    path = '/forum/login.php'
    data = "redirect=index.php&login_username=#{settings["login"]}&" + 
            "login_password=#{settings["password"]}&login=%C2%F5%EE%E4"
    resp, data = http.post(path, data)
    cookie_auth = resp.response['set-cookie']
  rescue
    puts "Error while login to rutracker.org"
  end

  settings["torrents"].each_key { |id|
    begin
      uri = URI.parse("http://rutracker.org/forum/viewtopic.php?t=#{id}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 5
      request = Net::HTTP::Get.new(uri.request_uri)
      request.initialize_http_header({"Cookie" => cookie_auth})
      resp = http.request(request)
      cookie_thread = resp.response['set-cookie']

      html = resp.body
      torrent_size = 0
      name = ""
      html.each_line do |line|
        if (line =~ /<a href=\".\/viewtopic.php\?(\w)=#{id}\">(.*)<\/a>/ )
          name = $2
        end
        if (line =~ /<td>(.*)&nbsp;(\w+)<\/td>/)
          torrent_size = $1.to_f * size_mult($2).to_i
        end
      end

      if (torrent_size.to_f > settings["torrents"][id].to_f)
        uri_dl = URI.parse("http://dl.rutracker.org/forum/dl.php?t=#{id}")
        http = Net::HTTP.new(uri_dl.host, uri_dl.port)
        http.open_timeout = 5
        http.read_timeout = 5
        request_dl = Net::HTTP::Post.new(uri_dl.request_uri)
        unless (cookie_thread.nil?)
          cookie = cookie_thread.split("\;")[0] + ";"
        else
          cookie = ""
        end
        cookie_dl = cookie_auth.split("\;")[0] + ";" + cookie + "bb_dl=#{id}"
        request_dl.initialize_http_header({"Cookie" => cookie_dl })
        response = http.request(request_dl)
        data = response.body

        filename = File.join(TORRENTS_UPLOAD_PATH, id.to_s + ".torrent")
        unless (settings["torrents"][id] == 0)
          remove_torrent_from_list(filename)
        end

        write_file(filename,data)
        set_size(id,torrent_size)
        send_mail(settings["bot_gmail_login"],
                  settings["bot_gmail_password"], 
                  settings["user_mail"], name, name)
      end
    rescue
      puts "Error while processing torrent #{id}"
    end
  }
end

options
rutracker_parse(read_config)
