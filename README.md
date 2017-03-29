# TX-PI - A Raspberry PI setup for fischertechnik

This repository contains the basic requirements to make a Raspberry Pi
mechanically and logically compatible with the [community firmware
for the fischertechnik TXT](http://cfw.ftcommunity.de/).

![TX-PI]()

# Getting started

You'll need:

  - a Raspberry Pi 2 or 3
  - a Waveshare 3.2" LCD touchscreen (either V3 or V4)

## Hardware setup

3D print the four case parts. The connector height of the display
differs between V3 and V4. The rquired screws are M2.5 * 12mm
countersunk. Assemble everything.

## Software setup

Get the latest [Raspbian Jessie Lite](https://www.raspberrypi.org/downloads/raspbian/) and install it on SD card. Boot your PI with it and do three things:

  - Enable networking so the Pi can access the internet
  - Set the hostname to tx-pi

Now download the [setup script]() onto your PI and run it. It will
download and install the display drivers as well as majaor parts of
the community firmware.

This is a work in progress.
