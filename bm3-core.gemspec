require 'rubygems'

Gem::Specification.new do |spec|
  spec.name        = 'bm3-core'
  spec.version     = '0.1.2'
  spec.author      = 'Ben Nagy'
  spec.license     = 'MIT'
  spec.email       = 'ben@iagu.net'
  #spec.homepage   = '<INTERNAL ONLY>'
  spec.summary     = 'Core components shared by BM3 projects'
  spec.test_files  = Dir['test/*.rb']
  spec.files       = Dir['**/*'].delete_if{ |item| item.include?('git') }

  spec.executables = 'monitor_server'

  spec.extra_rdoc_files = ['CHANGES', 'README', 'MANIFEST']

  spec.add_dependency('ffi')
  spec.add_dependency('msgpack')
  spec.add_dependency('march_hare')
  spec.add_dependency('bindata')
  spec.add_dependency('beanstalk-client')
  spec.add_dependency('trollop')

  spec.add_development_dependency('test-unit')

  spec.description = <<-EOF

  This contains core components that are used by all BM3 projects, mainly
  networking, logging and Windows bug analysis

  EOF
end
