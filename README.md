## Containers for dummies

_Disclaimer_
I am an dummy myself, this is how someone like myself understands
a concept that seems a lot more complex than it really is. Containers are awesome
but the current ecosystem around them is NOT simple whatsoever, and finding answers
in plain English is next to impossible.

So, with my limited understanding, in programming and in containers...
I will try my best to make a simple explanation so that anyone can get the
basic idea (including myself) I have less than a year of experience with Linux, programming
and containers.

**Containers**
Containers are deceptively simple things.
Go ahead and run:

```sh
  ls /
```

we should see something like this:

```sh
 bin -> usr/bin
 boot
 dev
 efi
 etc
󱂵 home
 lib -> usr/lib
 lib64 -> usr/lib
 lost+found
 mnt
 opt
 proc
 root
 run
 sbin -> usr/bin
 srv
 sys
 tmp
 usr
 var
```

It's essentially the common organization of a Linux filesystem. We can see some
directories and a few symlinks to other directories for compatibility reasons.
(example: /sbin is symlinked to /usr/bin so if a program looks for a binary or tries
to put a binary in /sbin, it will be directed to /usr/bin.) This is for compatiblity
and legacy reasons.

in `/usr/bin` we see binaries that are often found on most Linux distributions. Like
the core utilities for example (ls, cat, less, head, sed, chroot, sudo) etc...

Poking around in there and we see a lot of interesting things and locations where
files are kept. Including libs in `/usr/lib` and boot files in `/boot`

this is what makes up the core of a Linux system (besides the Kernel)

## Creating our own.

- Pull an image from Docker hub (or a similar registry)
  run our included image pull script that we got from github.com/moby/moby

```sh
  # ./download-frozen-image.sh <output-dir> <image>
  ./download-frozen-image.sh arch-dir archlinux:latest
```

This script will downlaod the latest arch linux image from Docker hub.
Docker hub has a lot of images that you can pull from and a lot of different
release tags from the creators of the image. Like `archlinux:base-devel` or
`debain:latest` etc...

Lets run `ls arch-dir` to see the contents of the directory that holds the information
about the image we just downloaded...

```
 51e4cf10935ead003f616f2363ae3260e28c7bc9536763dc0631638526168e2b
 879df13c861a38a80e992a4ef150d4a6527f62993cc6e79ab0141e7e42d30f4a
 2453f16847591dc207580fbab7ae626626f9d3ab347f7efd66eb2ee25c8969b7.json
 manifest.json
 repositories
```

oof, that looks like shit.
lets pick it apart

lets look in the `manifest.json`

```json
[
  {
    "Config": "2453f16847591dc207580fbab7ae626626f9d3ab347f7efd66eb2ee25c8969b7.json",
    "RepoTags": ["archlinux:latest"],
    "Layers": [
      "879df13c861a38a80e992a4ef150d4a6527f62993cc6e79ab0141e7e42d30f4a/layer.tar",
      "51e4cf10935ead003f616f2363ae3260e28c7bc9536763dc0631638526168e2b/layer.tar"
    ]
  }
]
```

Opening the `Config` field json we can see some basic information about the image...
The output is long but I will summarize it. It contains an entry point command `/usr/bin/bash`
the $PATH variable, LC_ALL=C and other arch linux default environment variables. Alongside some
info about the maintainers, License, and things like that. As well as some history on the container.

Hey! We recognize those `RepoTags` thats what we used to pull this image.

whats really important to start things off is the Layers.

<b>Layers<\b>

```sh
  tar --list --file "879df13c861a38a80e992a4ef150d4a6527f62993cc6e79ab0141e7e42d30f4a/layer.tar
```

Wow! It looks exactly like when we ran `ls /` earlier! That's because it is. (for the most part)
this is our base system layer! It contains all of the same system files that would be found on
any normal Linux system after a fresh install.

The first layer is our base system layer.

Lets look at the other layer

```sh
  tar --list --file 51e4cf10935ead003f616f2363ae3260e28c7bc9536763dc0631638526168e2b/layer.tar
```

Hmm, its similar but only has a few files instead of the 100's of files that the base layer had.

```
etc/
etc/ld.so.cache
etc/os-release
var/
var/cache/
var/cache/ldconfig/
var/cache/ldconfig/.wh..wh..opq
var/cache/ldconfig/aux-cache
```

thats because this is the next "Layer" that needs to be overlayed on to the base layer.
This layer is sort of like a "diff", meaning that instead of distributing the full system
image _plus_ these small changes to certain files, we just put the difference between
the layers into a new layer and distribute the changed files.

example:
if I wanted to add a `/nix` folder in the root directory and distribute that as an image,
would I rather create a whole new tar archive that contains all of the base system files
with my changes included, or would I just keep the base image as its own layer and create
a new layer that contains the `/nix` directory? Obviously its the latter. It would be very
ineffecient on space to distribute every change as a full image file.

Instead we create a `layer.tar` that contains our `/nix` folder

```
  mkdir -p our_layer/nix
  tar -cf our_layer/layer.tar our_layer/nix
```

```json
[
  {
    "Config": "2453f16847591dc207580fbab7ae626626f9d3ab347f7efd66eb2ee25c8969b7.json",
    "RepoTags": ["archlinux:latest"],
    "Layers": [
      "879df13c861a38a80e992a4ef150d4a6527f62993cc6e79ab0141e7e42d30f4a/layer.tar",
      "51e4cf10935ead003f616f2363ae3260e28c7bc9536763dc0631638526168e2b/layer.tar",
      "our_nix_folder_layer_would_go_here/layer.tar"
    ]
  }
]
```

## Creating a Container using Docker hub image metadata manually

Its hard af to get a straight answer on this WITHOUT using Docker/Podman directly.
It's useless. We want to understand wtf is happening, not rely on every little abstraction
to carry us. So here's how:
(Please note that you can do this manually, or programatically - like pulling this info
directly from Docker and parsing the layers and doing the following instructions)

Alright lets freaking go already:

- Create a temp directory

```sh
  mkdir my_pod
```

- Extract the base layer

```sh
  tar --extract --file 879df13c861a38a80e992a4ef150d4a6527f62993cc6e79ab0141e7e42d30f4a/layer.tar --directory=my_pod/
```

Now our "base image" is in our temp directory

- Extract the other layers
  the layers are in descending order, meaning we go through the `layers` field of our `manifest.json`
  one at a time and extract each one into the `my_pod` temp directory that will serve as our new root
  folder for our image

```sh
  tar --extract --file 51e4cf10935ead003f616f2363ae3260e28c7bc9536763dc0631638526168e2b/layer.tar --directory=my_pod/
  tar --extract --file our_nix_folder_layer_would_go_here/layer.tar --directory=my_pod/
```

tar in this case is overwriting the files in the base image layer with the files in our newer layers.
this is so that we can apply our changes and revisions as described earlier.

At this point we essentially have 90% of a container.
The next to critical steps are:

- `Chroot`
- and `Process isolation`

for now lets just worry about chroot. Run:

```sh
  sudo chroot my_pod
```

and BOOM babyyy! you should see:

```sh
[root@sweetd /]#
```

the same thing in Go-lang would look like:

```go
	// now we chroot into the temporary directory
	err = syscall.Chroot(tempDir)
	if err != nil {
		fmt.Printf("Error chrooting: %v\n", err)
		return err
	}

// This function isolates the process by creating new namespaces
func isolateProcess() error {
	// adding addtional namespace i.e., pid namespace, UTS namespace, mount namespace for more isolation
	if syscall.Unshare(syscall.CLONE_NEWUTS|syscall.CLONE_NEWPID|syscall.CLONE_NEWNS) != nil {
		return fmt.Errorf("Error unsharing")
	}
	return nil
}
```

In this case we also create a new Namespace for the container so that the processes are isolated
as well.

In the most simplest terms a `Container` is a directory that pretends to be a linux `/` root folder...
and we ask the Linux Kernel "Hey, bro can you treat this folder as a `root` directory and give
that baby a shiny new namespace/pid namespace/mount namespace to frolick and play in?" and
Linus Torvalds is personally like, "Yea, dude. I got you fam. You are now chilling in a new root."
We have "Changed root's" so to speak... wait a minute Ch..ange root? Ch-root? CHROOT! CHROOT! CHROOT!

This has been a lesson on containers from a complete noob dumbass. Thanks for coming to my Ted Talk.
