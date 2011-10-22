# coding: utf-8

require 'active_support/core_ext/object'

module Retter
  class Entries < Array
    include Retter::Stationery

    def initialize
      load_entries config.retters_dir
    end

    def detect_by_string(str)
      case str
      when nil, ''
        detect_by_today or wip_entry
      when /^e([0-9]+)$/
        index = $1.to_i
        self[index] or wip_entry
      else
        date = parse_date_string(str)
        detect_by_date(date) || wip_entry(date)
      end
    end

    def detect_by_today
      detect_by_date(Date.today)
    end

    def detect_by_date(date)
      detect {|e| e.date == date }
    end

    def parse_date_string(date_str)
      case date_str
      when /^yesterday$/i then 1.day.ago
      when /^today$/i     then 0.day.ago
      when /^tomorrow$/i  then 1.day.since
      when /^[0-9]+[\.\s](?:days?|weeks?|months?|years?)[\.\s](?:ago|since)$/i
        eval(date_str.gsub(/\s+/, '.')).to_date
      else
        Date.parse(date_str)
      end
    end

    def wip_entry(date = nil)
      wip_file = config.retter_file(date)
      wip_date = date || Date.today
      wip_body = wip_file.exist? ? wip_file.read : ''

      Retter::Entry.new date: wip_date, body: markupper.render(wip_body), pathname: wip_file
    end

    def commit_wip_entry!
      if config.wip_file.exist?
        copy = config.wip_file.read
        config.retter_file(Date.today).open('a') {|f| f.puts copy }
        config.wip_file.unlink
      end

      Retter.reset_entries!
    end

    def load_entries(path)
      date_files = find_markup_files(path).map {|file|
        date_str = file.basename('.*').to_s
        [Date.parse(date_str), file]
      }.sort_by(&:first)

      date_files.reverse_each {|date, file|
        self << Retter::Entry.new(date: date, body: markupper.render(file.read))
      }
    end

    def find_markup_files(path)
      path = Pathname.new(path).realpath
      Dir.open(path, &:to_a).grep(/^\d{4}(?:0[1-9]|1[012])(?:0[1-9]|[12][0-9]|3[01])\.(md)$/).map {|f| path.join f }
    end

    def markupper
      @markupper ||= ::Redcarpet::Markdown.new(
        Renderer,
        autolink: true,
        space_after_headers: true,
        fenced_code_blocks: true,
        strikethrough: true,
        superscript: true,
        fenced_code_blocks: true,
        tables: true
      )
    end
  end
end