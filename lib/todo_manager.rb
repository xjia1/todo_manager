require 'fileutils'
require 'tmpdir'
require 'yaml'
require 'highline/import'

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
    @todos.sort! {|x,y| x.id <=> y.id }
  end

  def help
    puts usage = <<USAGE
Usage:
  t --help              Print this help message; also: `-h` or `help`
  t                     List all todo items stored in $HOME/.todo
  t "todo content"      Add todo item
  t a4                  Show content of todo item a4
  t b3 "new content"    Change todo item b3
  t remove c4           Finish (or cancel) todo item c4; also: `r` or `rm`
  t gist <URL>          Set an existing gist URL (stored in $HOME/.todorc)
  t update              Update todo items from gist; also: `u` or `up`
  t commit              pdate todo items to gist; also: `c` or `cm`
USAGE
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
        copy :from => gist_todo, :to => todos_path
      end
    end
  end

  def commit
    open_gist do |gist|
      if yesno "Override #{gist}/#{gist_todo}?"
        copy :from => todos_path, :to => gist_todo
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

  def copy opts={}
    FileUtils.touch opts[:from]
    FileUtils.cp opts[:from], opts[:to]
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
