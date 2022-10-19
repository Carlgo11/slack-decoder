#!/usr/bin/env ruby
# frozen_string_literal: true
require 'fileutils'
require 'json'
require 'rake'
require 'time'

module Slack
  def self.messages(file)
    # Loop through messages in channel file
    channel = JSON.parse(File.read(file))
    data = []
    channel.each do |msg|
      next unless msg['type'].eql? "message"
      data.push({
                  'user' => msg['user'],
                  'time' => Time.at(msg['ts'].to_i).utc.strftime('%F %TZ'),
                  'msg' => msg['text']
                })
    end

    # Replace user IDs with names for all messages
    data.each do |msg|
      self.users.each do |id, name|
        msg['user'] = msg['user'].gsub id, name
        msg['msg'] = msg['msg'].gsub id, name
      end
    end
    return data
  end

  def self.users
    users_file = JSON.parse(File.read(ARGV[1]))
    users = {}
    users_file.each do |user|
      users[user['id']] = user['profile']['real_name']
    end
    return users
  end
end

data = Slack.messages ARGV[0]

def toCSV (data)
  output = ['Time,Name,Message']
  data.each do |msg|
    output.push("\"#{msg['time']}\",\"#{msg['user']}\",\"#{msg['msg']}\"")
  end
  File.open(ARGV[0].ext('.csv'), 'w') do |file|
    file.write(output.join("\n"))
  end
end

def toMD (data)
  output = %w[|Time|Name|Message| |----|----|-------|]
  data.each do |msg|
    output.push("|#{msg['time']}|#{msg['user']}|#{msg['msg'].gsub '|', '\|'}|")
  end
  File.open(ARGV[0].ext('.md'), 'w') do |file|
    file.write(output.join("\n"))
  end
end

toCSV data
toMD data