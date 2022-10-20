#!/usr/bin/env ruby
# frozen_string_literal: true
require 'fileutils'
require 'json'
require 'rake'
require 'time'
require 'zip'
require 'tmpdir'
require 'optparse'

module Slack
  def self.messages(zip, channel)
    # Loop through messages in channel file
    channel = JSON.parse(Filesystem.unzip(zip, channel))
    data = []
    record = false

    channel.each do |msg|

      next unless msg['type'].eql? "message"

      if record
        if msg['text'].eql? '!stop'
          record = false
          data.push({ 'user' => '', 'time' => Time.at(msg['ts'].to_i).utc.strftime('%F %TZ'), 'msg' => "__Transcript stopped by #{msg['user']}.__" })
          next
        end
      else
        if msg['text'].eql? '!start'
          record = true
          data.push({ 'user' => '', 'time' => Time.at(msg['ts'].to_i).utc.strftime('%F %TZ'), 'msg' => "__Transcript started by #{msg['user']}.__" })
          next
        else
          next
        end
      end

      data.push({
                  'user' => msg['user'],
                  'time' => Time.at(msg['ts'].to_i).utc.strftime('%F %TZ'),
                  'msg' => msg['text'].gsub("\n", '<br/>')
                })

      unless msg['reactions'].nil?
        msg['reactions'].each do |reaction|
          reaction['users'].each do |user|
            data.push({ 'user' => '', 'msg' => "__#{user} votes yes__" }) if reaction['name'].eql? '+1'
            data.push({ 'user' => '', 'msg' => "__#{user} votes no__" }) if reaction['name'].eql? '-1'
          end
        end
      end
    end

    # Replace user IDs with names for all messages
    data.each do |msg|
      self.users(zip).each do |id, name|
        msg['user'] = msg['user'].gsub id, name
        msg['msg'] = msg['msg'].gsub id, name
      end
    end
    return data
  end

  def self.users(zip)
    users_file = JSON.parse(Filesystem.unzip(zip, "users.json"))
    users = {}
    users_file.each do |user|
      users[user['id']] = user['profile']['real_name']
    end
    return users
  end
end

module Filesystem
  def self.unzip(zip_path, file_path)
    Zip::File.open(zip_path) do |zipfile|
      Dir.mktmpdir do |tmpdir|
        tmp_path = "#{tmpdir}/#{File.basename(file_path)}"
        zipfile.extract(file_path, tmp_path)
        return File.read(tmp_path)
      end
    end
  end

  def self.toCSV (data, filename)
    output = ['Time,Name,Message']
    data.each do |msg|
      output.push("\"#{msg['time']}\",\"#{msg['user']}\",\"#{msg['msg']}\"")
    end
    File.open(filename, 'w') do |file|
      file.write(output.join("\n"))
    end
  end

  def self.toMD (data, filename)
    output = %w[|Time|Name|Message| |----|----|-------|]
    data.each do |msg|
      output.push("|#{msg['time']}|#{msg['user']}|#{msg['msg'].gsub '|', '\|'}|")
    end
    File.open(filename, 'w') do |file|
      file.write(output.join("\n"))
    end
  end
end

# Get parameters
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-o', '--output FILE', 'Output name') { |v| options[:output] = v }
  opts.on('-i', '--input FILE', 'Source ZIP file') { |v| options[:zip_path] = v }
  opts.on('-c', '--channel NAME', 'Channel name') { |v| options[:channel_name] = v }

end.parse!
required_opts = [:output, :zip_path, :channel_name]
missing_options = required_opts - options.keys
unless missing_options.empty?
  fail "Missing required options: #{missing_options}"
end

data = Slack.messages(options[:zip_path], options[:channel_name])
Filesystem.toCSV(data, "#{options[:output]}.csv")
Filesystem.toMD(data, "#{options[:output]}.md")
