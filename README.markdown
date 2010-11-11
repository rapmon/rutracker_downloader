#Bot for auto downloading updated torrents from rutracker.org 
For example download your favorite serial, as new episode available you recive mail and transmission started dowload it.
## Prerequisites
* ruby-1.8.7 or higher
* transmission-daemon
## Install
* change bot_config.yaml
  * login - your rutracker login 
  * password - your rutracker pass
  * user_mail - your mail for news from bot
  * bot_gmail_login - gmail for bot
  * bot_gmail_password - pass for bot gmail
  * torrents - here is bot saving info about torrents, don't change this line

* change rutracker_bot.rb
  * CONFIG_FILE - bot_config.yaml file place
  * TORRENTS_UPLOAD_PATH - where save downloaded torrent files for transmission

* change /etc/default/transmission-daemon
  * add line NEW_TORRENT_DIR="/home/user/tracker/torrents" change for your settings
  * add at end of string OPTIONS "-c $NEW_TORRENT_DIR"
  * restart transmission-daemon

* add crontab job
  * 17 * * * * /usr/bin/ruby /home/user/tracker/rutracker_bot.rb >> /dev/null 2>&1
## Usage
For usage look at "ruby rutracker_bot.rb -h"
