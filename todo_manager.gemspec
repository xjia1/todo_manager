Gem::Specification.new do |s|
  s.name        = 'todo_manager'
  s.version     = '0.9.4'
  s.date        = '2013-01-06'
  s.summary     = 'Todo Manager'
  s.description = 'A simple todo manager gem with a command-line interface. You can also upload your todo items to a git/gist repository.'
  s.authors     = ['Xiao Jia']
  s.email       = 'me@xiao-jia.com'
  s.homepage    = 'http://xiao-jia.com/todo_manager/'
  s.files       = ['README', 'LICENSE', 'lib/todo_manager.rb']
  s.executables << 'todo_manager'
  s.add_dependency 'highline'
end
