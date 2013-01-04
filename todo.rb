#!/usr/bin/env ruby

require 'fileutils'
require 'tmpdir'
require 'yaml'
require 'highline/import'

HELP = <<HELP
Command-line TODO management

todo
  List all todo items.

todo -h
todo --help
todo help
  Print help message.

todo Write a program
todo "Write a program"
  Add todo item.

todo r c4
todo rm c4
todo remove c4
  Remove todo item c4. There's no "finish a todo item".

todo a4
  Show content of todo item a4.

todo b3 new todo content
todo b3 "new todo content"
  Change todo item b3.

todo gist https://gist.github.com/12345
  Prepare for uploading to gist.

todo u
todo up
todo update
  Update todo items from gist.

todo c
todo cm
todo commit
  Update todo items to gist.
HELP

class TodoManager

  class Todo
    attr_reader :id
    attr_writer :text

    def initialize id, text
      @id = id
      @text = text
    end
  
    def to_s
      "#@id - #@text"
    end

    def to_hash
      {:id => @id, :text => @text}
    end
  end

  def initialize
    FileUtils.touch todos_path
    @todos = YAML.load(File.read(todos_path)) || []
    @todos = @todos.collect {|t| Todo.new(t[:id], t[:text]) }
  end

  def help
    puts HELP
  end

  def list
    puts @todos
  end

  def is_todo_id? id
    not find_by(id).empty?
  end

  def show id
    puts find_by(id)
  end

  def add text
    id = next_id
    @todos << Todo.new(id, text)
    save_todos
    puts id
  end

  def remove id
    @todos.delete_if {|todo| todo.id == id }
    save_todos
  end

  def edit id, text
    find_by(id).first.text = text
    save_todos
  end

  def prepare gist=nil
    if gist
      File.open(todorc, 'w') {|f| f.write({:gist => gist}.to_yaml) }
    else
      rc = load_todorc
      puts rc[:gist]
    end
  end

  def update
    open_gist do |gist|
      if yesno "Overwrite #{todos_path}?"
        move :from => gist_todo, :to => todos_path
      end
    end
  end

  def commit
    open_gist do |gist|
      if yesno "Override #{gist}/#{gist_todo}?"
        move :from => todos_path, :to => gist_todo
        `git add .`
        `git commit -m 'update'`
        `git push -f origin master`
      end
    end
  end

protected
  def open_gist
    rc = load_todorc
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        `git clone #{rc[:gist]} .`
        yield rc[:gist]
      end
    end
  end

  def gist_todo
    'todo.yaml'
  end

  def move opts={}
    FileUtils.touch opts[:from]
    FileUtils.mv opts[:from], opts[:to], :force => true
  end

  # Handy yes/no prompt for little Ruby scripts
  def yesno prompt, default=true
    s = default ? '[Y/n]' : '[y/N]'
    d = default ? 'y' : 'n'
    a = ''
    until %w[y n].include? a
      a = ask("#{prompt} #{s} ") {|q| q.limit = 1; q.case = :downcase }
      a = d if a.length == 0
    end
    a == 'y'
  end

  def todos_path
    File.expand_path('~/.todo')
  end

  def todorc
    File.expand_path('~/.todorc')
  end

  def load_todorc
    FileUtils.touch todorc
    YAML.load(File.read(todorc)) || {}
  end

  def save_todos
    File.open(todos_path, 'w') {|f| f.write @todos.collect(&:to_hash).to_yaml }
  end

  def next_id
    ('a'..'z').each do |c|
      ('1'..'5').each do |i|
        id = c + i
        return id unless is_todo_id? id
      end
    end
  end

  def find_by id
    @todos.select {|todo| todo.id == id }
  end
end

commands = {
  :'-h'     => :help,
  :'--help' => :help,
  :help     => :help,
  :r      => :remove,
  :rm     => :remove,
  :remove => :remove,
  :gist   => :prepare,
  :u      => :update,
  :up     => :update,
  :update => :update,
  :c      => :commit,
  :cm     => :commit,
  :commit => :commit
}

tm = TodoManager.new

if ARGV.length == 0
  tm.list
elsif ARGV.length == 1 and tm.is_todo_id? ARGV.first
  tm.show ARGV.first
elsif ARGV.length >= 1 and cmd = commands[ARGV.first.to_sym] and tm.respond_to? cmd
  if ARGV.length == 1
    tm.send cmd
  else
    tm.send cmd, ARGV[1..-1].join(" ")
  end
else
  if tm.is_todo_id? ARGV.first
    tm.edit ARGV.first, ARGV[1..-1].join(" ")
  else
    tm.add ARGV.join(" ")
  end
end
