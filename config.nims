# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
switch("define", "ssl")
switch("define", "release")
# end Nimble config
