#!/usr/bin/sh
make all -j4
sudo cp bin/* /usr/bin/
make clean -j4