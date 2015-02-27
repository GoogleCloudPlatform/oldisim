# Copyright 2015 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# user specified variables
vars = Variables('custom.py')
vars.Add(BoolVariable('RELEASE', 'Set to 1 to build for release', 1))
vars.Add(BoolVariable('STATICLINK', 'Set to 1 to link libraries statically', 0))
vars.Add(BoolVariable('TCMALLOC', 'Set to 1 to use tcmalloc', 1))
vars.Add(('CXX', 'The default C++ compiler used'))
vars.Add(('LD', 'The default linker used'))
vars.Add(('AR', 'The default make library archive used'))
vars.Add(('NM', 'The default symbol table viewer used'))
vars.Add(('CPPPATH', 'System default C++ include directory'))
vars.Add(('LIBPATH', 'System default library directory'))

env = Environment(variables = vars)

if env['RELEASE']:
  mymode = 'release'
  env.Append(CCFLAGS=['-O3', '-DNDEBUG'])
else:
  mymode = 'debug'

#tell the user what we're doing
print '**** Compiling in ' + mymode + ' mode...'
if env['STATICLINK']:
  print '**** Using static linking...'
  env.Append(LINKFLAGS=['--static'])

buildroot = '#' + mymode  #holds the root of the build directory tree

# add project-wide includes
env.Append(CPPPATH  = ['#oldisim/include/', '#third_party/cereal/include/', '#third_party/boost_1_53_0'])

# use pthreads
env.Append(CXXFLAGS=['-pthread'])
env.Append(LINKFLAGS=['-pthread'])

#make sure the sconscripts can get to the variables
Export('env', 'buildroot')

#put all .sconsign files in one place
env.SConsignFile()

#specify the sconscript for myprogram
project = 'oldisim'
SConscript(project + '/SConscript', exports=['project'])

project = 'workloads'
SConscript(project + '/SConscript', exports=['project'])
