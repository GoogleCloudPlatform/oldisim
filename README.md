# Description #

oldisimulator is a framework to support benchmarks that emulate Online Data-
Intensive (OLDI) workloads, such as web search and social networking.

# Prerequisites #

To build oldisim you need to have SCons compiler installed in your system.

oldisim requires a C++11 compatible compiler, e.g., g++ v.4.7.3 or later
versions. It also depends on several other external libraries. Below are the
commands to install the required packages:

$ sudo apt-get install build-essential gengetopt libgoogle-perftools-dev
libunwind7-dev libevent-dev scons libboost-all-dev

Note that Boost version 1.5.3 or greater is required.

# Build oldisim #

To build oldisimulator, run `scons` in the root directory of the project.

If you need to create static libraries, put the following in a new file named
custom.py in the project root:

RELEASE=1
STATICLINK=1
TCMALLOC=1
CXX='$PATH_TO_g++$'
LD='$PATH_TO_LD'
AR='$PATH_TO_AR'
NM='$PATH_TO_NM'
CPPPATH=['/usr/include/', '<PATH_TO_BOOST_FILES>']
LIBPATH='/usr/lib/'

Note that you don’t need to build the boost library, as the dependency on lock
free queues does not require a built libboost.

To speedup compilation, scons supports parallel compilation, e.g. `scons
-j12` to compile with 12 threads in parallel. There are two build modes,
**release** and **debug**. The default build mode is **release**. The build
mode is specified via the **mode** flag, e.g. `scons mode=release`.
The output of the builds will be put into *BUILD_MODE*/

There are several output directories in the build, corresponding to the
different parts of oldisimulator.

+ *BUILD_MODE*/oldisim contains the oldisim framework libraries
+ *BUILD_MODE*/workloads contains the binaries of the workloads built

# Run oldisim: search on the cluster #

This benchmark emulates the fanout and request time distribution for web search.
It models an example tree-based search topology. A user query is first processed
by a front-end server, and eventually fanned out to a set of leaf nodes.

The search benchmark consists of four modules - RootNode, LeafNode, DriverNode,
and LoadBalancer. Note that LoadBalancer is only needed when there exist more
than one root.

## Prepare the cluster ##

To emulate a tree topology with M roots and N leafs, your cluster needs to have
M machines to run RootNode, N machines to run LeafNode and one machine to run
DriverNode.

If M is larger than 1, one more machine is needed to enable LoadBalancer.

Memory container groups and network container groups need to be disabled on each
machine. You can achieve this by archer a kernel with appropriate flags, i.e.,

archer file -m "<machine_list>" -a "cgroup_disable=net,memory" <kernel pkg>

## Run oldisim ##

### step 1. Start LeafNode ###

Copy the binary (release/workloads/search/LeafNode) to all the machines
allocated for LeafNode.

Run the following command:
$PATH_TO_BINARY/LeafNode 

You can run "$PATH_TO_BINARY/LeafNode --help" for more usage details.

### step 2. Start RootNode  ###

Copy the binary (release/workloads/search/ParentNode) to all the machines
allocated for RootNode.

Run the following command:
$PATH_TO_BINARY/ParentNode --leaf=<LeafNode machine 1> ...
                           --leaf=<LeafNode machine N>

You can run "$PATH_TO_BINARY/ParentNode --help" for more usage details.

### step 3. Start LoadBalancer (optional) ###

Copy the binary (release/workloads/search/LoadBalancerNode) to the
machine allocated for LoadBalancerNode.

Run the following command:
$PATH_TO_BINARY/LoadBalancerNode --parent=<RootNode machine 1> ...
                                 --parent=<RootNode machine M>

You can run "$PATH_TO_BINARY/LoadBalancerNode --help" for more usage details.

### step 4. Start DriverNode ###

Copy the binary (release/workloads/search/DriverNode) to the machine
allocated for DriverNode.

Run the following command:
$PATH_TO_BINARY/DriverNode --server=<RootNode machine 1> ...
                           --server=<RootNode machine M>

You can run "$PATH_TO_BINARY/DriverNode --help" for more usage details.

