
task :default => :test

task :test do
  sh('rm ./output/screen.png || true')
  sh('phantomjs ./phantom.js')
  sh('open ./output/screen.png')
end
