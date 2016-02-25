
task :default => :test

task :test do
  sh('rm ./output/screen.png || true')
  sh('$(npm bin)/phantomjs ./login.js')
  sh('open ./output/screen.png')
end
