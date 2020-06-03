#!/usr/bin/env python3
import os
import sys
import re
import tkinter as tk
import subprocess

# TODO
#   Implement a GUI for this using:
#   https://wiki.wxpython.org/Getting%20Started#Building_a_simple_text_editor

# Script to make a table of the subvolumes on the system and link them to their sizes
def pretty_bytes(size, *scale):
    # given a number of b, return a nice looking number like 1.21 GB
    # optional: use powers of ten instead? This is controlled using  the scale=1 arg
    base = 1024
    suffixes = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB'] # Bytes
    longsuffixes = ['Bytes', 'Kibibytes', 'Mebibytes', 'Gibibytes', 'Tebibytes', 
            'Pebibytes', 'Exbibytes', 'Zebibytes', 'Yobibytes'] # Bytes
    if scale:
        # using powers of 10
        base = 1000
        suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']  # Bytes
        longsuffixes = ['Bytes', 'Kilobytes', 'Megabytes', 'Gigabytes', 'Terabytes', 
                'Petabytes', 'Exabytes', 'Zettabytes', 'Yottabytes' ] # Bytes
    
    size = int(size) * base  # Usage reported in KB as default
    pretty_size = ''
    size = size / base # divide to get KiB/KB
    for power in range(0,9):
        divisor = base ** power
        #print('1024 ^ {} = {}'.format(power, divisor))
        if size > divisor:
            pretty_size='{:0.2f} {}'.format((size / divisor), suffixes[power])
    
    return pretty_size

class Filesystem:
    def __init__(self, label, uuid, mountpoint):
        self.label = label
        self.uuid == uuid
        self.mountpoint = mountpoint
    
    def __str__(self):
        return '{}, {}, {}'.format(self.label, self.uuid, self.mountpoint)

class Snapshot:
    def __init__(self, snap_id, parent, groupid, path, excl_size, refr_size):
        self.snap_id = snap_id
        self.parent = parent
        self.groupid = groupid
        self.path = path
        self.excl_size = excl_size
        self.refr_size = refr_size
    
    def __str__(self):
        return '{}, {}, {}, {}, {}, {}'.format(self.snap_id, self.parent, 
                self.groupid, self.path, 
                pretty_bytes(self.excl_size), pretty_bytes(self.refr_size))

def return_btrfs_filesystems():
    # Look for all btrfs filesystems
    filesystems = []
    mounts = subprocess.run('mount', stdout = subprocess.PIPE, text = True)
    for mount in mounts.stdout.split('\n'):
        #print(mount)
        components = mount.rstrip('\n').split(' ')
        #print(components)
        if len(components) > 3:
            if components[4] == 'btrfs':
               filesystems.append(components[2])

    return filesystems

def dict_of_snapshots(filesystem):
    # Parse the snapshots for a given filesystem
    # Returns a dict of {'id': 'snapshot_object'...}
    snapshots = {}
    root_snapshot = Snapshot(5, 0, 0, filesystem, 0, 0)
    snapshots['5'] = root_snapshot
    parents = {}
    parents[5] = 1
    cmd = ['sudo', 'btrfs', 'subvolume', 'list', filesystem]
    subvols = subprocess.run(cmd, stdout = subprocess.PIPE, 
                             text = True, check = True)
    for subvol in subvols.stdout.split('\n'):
        components = subvol.split()
        #print(components)
        if len(components) > 1:
            snap_id = components[1]
            gen = components[3]
            parent_id = components[6]
            path = components[8]
            snapshot = Snapshot(snap_id, parent_id, 0,
                                '{}/{}'.format(filesystem, path), 0, 0)
            snapshots[snap_id] = snapshot
            #print('snapshot:', snapshot)

    #print(snapshots)

    # get the qgroups to determine the size of each snapshop
    cmd = ['sudo', 'btrfs', 'qgroup', 'show', '--raw', filesystem]
    qgroup_show = subprocess.run(cmd, stdout = subprocess.PIPE, 
                                 stderr = subprocess.PIPE, text = True)
    #print('OUT:', qgroup_show.stdout)
    #print('ERR:', qgroup_show.stderr)
    if 'ERROR: can\'t list qgroups: quotas not enabled' in qgroup_show.stderr.split('\n'):
        print('Quotas not enabled:', qgroup_show.stderr.split('\n')[0])
        cmd = ['sudo', 'btrfs', 'quota', 'enable', filesystem]
        print('Starting the quota enabling', cmd)
        result = subprocess.run(cmd, stdout = subprocess.PIPE, 
                                stderr = subprocess.PIPE, text = True)
        print('OUT:', result.stdout)
        print('ERR:', result.stderr)
    else:
        for snapshot in qgroup_show.stdout.split('\n'):
            #print('line:', snapshot)
            components = snapshot.split()
            if 'qgroupid' not in components and r'--------' not in components:
                #print(components)
                if len(components) > 1:
                    ids = components.pop(0)
                    qgroupid, snap_id = ids.split('/')
                    snapshot = snapshots[snap_id]
                    #print(qgroupid, snap_id, components, snapshot)
                    snapshots[snap_id].qgroupid = qgroupid
                    snapshots[snap_id].refr_size = components[0]
                    snapshots[snap_id].excl_size = components[1]
                    #print('snapshot:', snapshots[snap_id])

    return snapshots

def main():
    # get the list of snapshots for all of the filesystems 
    print(filesystems)
    snapshots_by_filesystem = {}
    for filesystem in filesystems:
        print('Filesystem', filesystem)
        snapshots_by_filesystem[filesystem] = dict_of_snapshots(filesystem)
        snapshots = dict_of_snapshots(filesystem)
        ids = snapshots.keys()
        snapshots_by_filesystem[filesystem] = snapshots
        for snap_id in ids:
            print(snapshots[snap_id])
        


    #win = tk.Tk()
    #win.title('Parsing QGroups')

    #win.resizable(0,0)
    #win.mainloop()
    return None

if __name__ == '__main__':
    filesystems = []
    filename = sys.argv.pop(0)
    for arg in sys.argv:
        filesystems.append(arg)

    if len(sys.argv) == 0:
        filesystems = return_btrfs_filesystems()

    main()


