
task :default => :test

task :login do
  sh('rm ./output/screen.png || true')
  sh('$(npm bin)/phantomjs ./login.js')
  sh('open ./output/screen.png')
end

task :reconsent do
  sh('rm ./output/screen.png || true')
  sh('$(npm bin)/phantomjs ./reconsent.js')
  sh('open ./output/screen.png')
end
