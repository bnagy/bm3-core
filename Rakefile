require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rbconfig'

CLEAN.include('**/*.rbc', '**/*.rbx', '**/*.gem')

namespace 'gem' do
  desc 'Create the gem'
  task :create => [:clean] do
    spec = eval(IO.read('bm3-core.gemspec'))
    Gem::Builder.new(spec).build
  end

  desc 'Install the gem'
  task :install => [:create] do
     file = Dir["*.gem"].sort.last
     sh "gem install #{file}"
  end
end

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = true
end

task :default => :test
