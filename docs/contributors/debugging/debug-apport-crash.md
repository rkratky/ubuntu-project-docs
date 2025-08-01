(debug-apport-crash)=
# Debug an Apport crash

The Apport service running on a user's computer can automatically file bug
reports triggered on a system malfunction, with logs and core dump information
collected at the instance of failure. The data for these bug reports are
aggregated into a `<something>.crash` file.

This section explains how to get a useful stacktrace from one of these `.crash`
files.


## Enable debug symbols

There are various ways to enable debug symbols; one way is to append `ddebs` to
your `apt` sources:

```none
$ echo "deb http://ddebs.ubuntu.com focal main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list
$ echo "deb http://ddebs.ubuntu.com focal-updates main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list

$ sudo apt install ubuntu-dbgsym-keyring
$ sudo apt update
```

or as a deb822 entry:

```none
$ cat << EOF > /etc/apt/sources.list.d/ddebs.sources
Types: deb
URIs: http://ddebs.ubuntu.com
Suites: noble noble-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-dbgsym-keyring.gpg
```


## Install package with debug symbols

```none
$ sudo apt install bind9 bind9*-dbgsym
```

Often there are also secondary libraries (**`libs`**) or dependencies
(**`deps`**) with more symbols (**`syms`**) that we'll need. This examines the
binary for other possible debug symbols (**`dbgsyms`**):

```none
$ sudo apt install debian-goodies
$ sudo apt install $(find-dbgsym-packages /usr/sbin/named 2>/dev/null)
```

The following NEW packages will be installed:

* `libcap2-dbgsym libcom-err2-dbgsym libgcc-s1-dbgsym libicu67-dbgsym libjson-c5-dbgsym libkeyutils1-dbgsym`
* `libkrb5-dbg liblmdb0-dbgsym liblzma5-dbgsym libmaxminddb0-dbgsym libxml2-dbgsym zlib1g-dbgsym`


## Download the .crash file to a temporary directory

```none
$ mkdir /tmp/bind9-crash
$ cd /tmp/bind9-crash
$ wget https://bugs.launchpad.net/ubuntu/+source/bind9/+bug/1954854/+attachment/5551855/+files/_usr_sbin_named.114.crash
```


## Register the package with the crash file

```none
$ cat <(echo "Package: bind9") _usr_sbin_named.114.crash > bind9_named.114.crash
```

```{note}

`apport-retrace` complains if the package isn't specified, but Apport hooks
don't insert it, so you have to do it manually.
```

## Check that your installed version matches the reporter's version exactly

```none
$ apt-cache policy bind9 | grep '^  Installed'
  Installed: 1:9.16.1-0ubuntu2.9
```

Unfortunately the `.crash` file doesn't include the version number, but the
Launchpad bug report will show it:

```none
 Package: bind9 1:9.16.1-0ubuntu2.9
```


## Retrace symbols

```none
$ sudo apt-get install apport-retrace
$ apport-retrace bind9_named.114.crash
```

The above command inserted an empty '`separator: `' line into the crash file,
which `apport-unpack` will choke on, so delete that line:

```none
$ sed -i '/^separator: *$/d' ./bind9_named.114.crash
```


## Unpack crash

```none
$ apport-unpack bind9_named.114.crash crash-114
```

The `crash-114/` subdirectory will now include a `ThreadStacktrace` file that
hopefully (!) should have a usable backtrace. This one looks great but the full
stacktrace provides rather too much information.

```none
$ wc -l crash-114/ThreadStacktrace
415 crash-114/ThreadStacktrace
```


## (Advanced) GDB

```none
$ apt-get source bind9
$ cd bind9-9.16.1/

$ apport-retrace --gdb /tmp/bind9-crash/bind9_named.114.crash
```

This will give you an interactive GDB session on the reporter's coredump. For
example, with this particular crash, we can get a simple backtrace:

```none
(gdb) bt
#0  isc__nm_tcp_send (handle=0x7eff7522dbb0, region=0x7eff7d39a9b8, cb=0x7eff887675a0 <tcpdnssend_cb>, 
    cbarg=0x7eff7d39a9a8) at tcp.c:852
#1  0x00007eff88a2e707 in client_sendpkg (client=client@entry=0x7eff754c31b0, buffer=<optimized out>, 
    buffer=<optimized out>) at client.c:331
#2  0x00007eff88a2ffe9 in ns_client_send (client=client@entry=0x7eff754c31b0) at client.c:592
#3  0x00007eff88a3e9b0 in query_send (client=0x7eff754c31b0) at query.c:552
#4  0x00007eff88a469a7 in ns_query_done (qctx=qctx@entry=0x7eff85476850) at query.c:10914
#5  0x00007eff88a4dde6 in query_respond (qctx=0x7eff85476850) at query.c:7407
#6  query_prepresponse (qctx=qctx@entry=0x7eff85476850) at query.c:9906
#7  0x00007eff88a49936 in query_gotanswer (qctx=qctx@entry=0x7eff85476850, res=res@entry=0) at query.c:6823
#8  0x00007eff88a4f4c6 in query_resume (qctx=0x7eff85476850) at query.c:6121
#9  fetch_callback (task=<optimized out>, event=<optimized out>) at query.c:5703
#10 0x00007eff88770fa1 in dispatch (threadid=<optimized out>, manager=<optimized out>) at task.c:1152
#11 run (queuep=<optimized out>) at task.c:1344
#12 0x00007eff88239609 in start_thread (arg=<optimized out>) at pthread_create.c:477
#13 0x00007eff8815a293 in clone () at ../sysdeps/unix/sysv/linux/x86_64/clone.S:95

(gdb) list tcp.c:852
file: "src/unix/tcp.c", line number: 852, symbol: "???"
847     src/unix/tcp.c: No such file or directory.
file: "tcp.c", line number: 852, symbol: "???"
847                      void *cbarg) {
848             isc_nmsocket_t *sock = handle->sock;
849             isc__netievent_tcpsend_t *ievent = NULL;
850             isc__nm_uvreq_t *uvreq = NULL;
851
852             REQUIRE(sock->type == isc_nm_tcpsocket);
853
854             uvreq = isc__nm_uvreq_get(sock->mgr, sock);
855             uvreq->uvbuf.base = (char *)region->base;
856             uvreq->uvbuf.len = region->length;
(gdb)

(gdb) print sock
$1 = (isc_nmsocket_t *) 0x0
(gdb) print sock->mgr
Cannot access memory at address 0x10
```

The user supplied a second `*.115.crash` file, which you could use the above
process to unpack, and then examine to see how it compares.


## Common causes of crashes


### NULL pointer dereference

It's not at all unusual for software to specify pointers as undefined by
setting them to the NULL pointer (typically represented as the value zero, or
0x0). However, treating a NULL pointer as a valid pointer address is a fatal
programming error. This can arise in code that neglects to create or initialize
an object, invalid use of a freed object, and various kinds of race conditions.
Whatever the cause, they can be spotted when examining the pointers mentioned
in the crash trace:

```none
200     int myfunc(foobar_t *b) {
201         a = b->foo;
...         ...
2xx         return 0;

(gdb) print b
$1 = (foobar_t *) 0x0
(gdb) print b->foo
Cannot access memory at address 0x10
```

To diagnose the problem from here, trace backwards for code that calls
`myfunc()`, which may be passing NULL values. Static analysis tools and
tracing tools can be worth employing when the calling tree is non-trivial.

Sometimes the issue can be "papered over" or at least made more transparent by
adding "`null-ptr checks`" to the problematic code. For example, the above code
could be changed to:

```none
200     int myfunc(foobar_t *b) {
201         if (! b) {
202             printf("ERROR: Badness!");
203             return 1;
204         }
205         a = b->foo;
...         ...
2xx         return 0;
```

Papering over coding errors is generally considered a bad practice in open
source because it can make legitimate bugs less obvious, and often will just
lead to harder-to-diagnose problems elsewhere in the codebase.

However, in production code, avoiding user-experienced crashes can be worth the
diagnostic loss, especially if a minimal test-case to reproduce the original
problem is forwarded upstream.


### Pointer to undefined memory

For efficiency, compilers can skip initializing new pointers to zero, leaving
them set to essentially random values, which likely will not make sense if
dereferenced.

```none
(gdb) print a
$1 = (foobar_t *) 0x41245234
(gdb) print a->foo
Cannot access memory at address 0x41245234
```


### Pointer set to an integer

This type of programming mistake occurs when a pointer variable's value is set
to an integer. Perhaps a code refactoring to change a plain number into a
`struct` object was not done properly, or perhaps an incorrect cast hides a
misassignment. In any case, this can be spotted by unusually simple pointer
values, such as:

```none
(gdb) print goodptr
$1 = (foobar_t *) 0xf8815a29

(gdb) print badptr
$1 = (foobar_t *) 0x00000008
```


## Further reading

* [Ubuntu wiki - Apport](https://wiki.ubuntu.com/Apport)
* [Ask Ubuntu - how to enable/disable Apport](https://askubuntu.com/questions/93457/how-do-i-enable-or-disable-apport)
* [Ask Ubuntu - how to read or open crash file](https://askubuntu.com/questions/1210651/how-to-read-or-open-crash-file-from-var-crash)
* [Ubuntu wiki - Apport Retraces](https://wiki.ubuntu.com/Bugs/ApportRetraces)
* [Ubuntu wiki - interpreting Apport retraces](https://wiki.ubuntu.com/MOTU/School/IntrepretingApportRetraces)
* [Ubuntu wiki - Debugging program crash](https://wiki.ubuntu.com/DebuggingProgramCrash)
* [Ubuntu wiki - error tracker](https://wiki.ubuntu.com/ErrorTracker#Anatomy_of_a_crash)
* [Ubuntu wiki - meeting logs, Apport pkg hooks](https://wiki.ubuntu.com/MeetingLogs/devweek0909/ApportPkgHooks)

