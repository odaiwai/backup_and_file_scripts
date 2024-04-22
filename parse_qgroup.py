#!/usr/bin/env python3
"""
Report on the QGroups.

Script to make a table of the subvolumes on the system and link them to
their sizes
"""
# import os
import sys
# import re
# import tkinter as tk
import subprocess

# TODO
#   Implement a GUI for this using:
#   https://wiki.wxpython.org/Getting%20Started#Building_a_simple_text_editor


class Filesystem:
    def __init__(self, label, uuid, mountpoint):
        self.label = label
        self.uuid = uuid
        self.mountpoint = mountpoint

    def __str__(self):
        return f'{self.label}, {self.uuid}, {self.mountpoint}'


class Snapshot:
    def __init__(self, snap_id, gen, parent, groupid, path, excl_size, refr_size):
        self.snap_id = snap_id
        self.gen = gen
        self.parent = parent
        self.groupid = groupid
        self.path = path
        self.excl_size = excl_size
        self.refr_size = refr_size

    def __str__(self):
        return (f'ID {self.snap_id} parent {self.parent} GroupID {self.groupid}'
                f' {self.path}, {pretty_bytes(self.excl_size)},'
                f' {pretty_bytes(self.refr_size)}')


def pretty_bytes(size: int, scale: int = 0, long: bool = False) -> str:
    """
    Return a human readable size given an input in KBytes.

    given a number of b, return a nice looking number like 1.21 GB
    optional:
        use powers of ten instead? This is controlled using the scale=1 arg

    :param size: size in KBytes
    :param scale: 0 for powers of 2, 1 for powers of 10
    :param long: long form or sohort form of name
    :return: pretty-description
    """
    base = (1024, 1000)[scale]
    powers = {
        0: {'S0': 'B',   'L0': 'Bytes',     'S1': 'B',  'L1': 'Bytes'},
        1: {'S0': 'KiB', 'L0': 'Kibibytes', 'S1': 'KB', 'L1': 'Kilobytes'},
        2: {'S0': 'MiB', 'L0': 'Mebibytes', 'S1': 'MB', 'L1': 'Megabytes'},
        3: {'S0': 'GiB', 'L0': 'Gibibytes', 'S1': 'GB', 'L1': 'Gigabytes'},
        4: {'S0': 'TiB', 'L0': 'Tebibytes', 'S1': 'TB', 'L1': 'Terabytes'},
        5: {'S0': 'PiB', 'L0': 'Pebibytes', 'S1': 'PB', 'L1': 'Petabytes'},
        6: {'S0': 'EiB', 'L0': 'Exbibytes', 'S1': 'EB', 'L1': 'Exabytes'},
        7: {'S0': 'ZiB', 'L0': 'Zebibytes', 'S1': 'ZB', 'L1': 'Zettabytes'},
        8: {'S0': 'YiB', 'L0': 'Yobibytes', 'S1': 'YB', 'L1': 'Yottabytes'},
        9: {'S0': 'RiB', 'L0': 'Ronibytes', 'S1': 'RB', 'L1': 'Ronnabytes'},
        10: {'S0': 'QiB', 'L0': 'Quebibytes', 'S1': 'QB', 'L1': 'Quettabytes'}
    }

    size = int(size) * base  # Usage reported in KB as default
    pretty_size = ''
    size = size / base  # divide to get KiB/KB
    for power, suffix in powers.items():
        suffix_key = (f'L{scale}', f'S{scale}')[long]
        divisor = base ** power
        # print(f'1024 ^ {power} = {divisor}')
        if size > divisor:
            pretty_size = f'{(size/divisor):0.2f} {suffix[suffix_key]}'

    return pretty_size


def btrfs_mounted_fs() -> list:
    # Look for all btrfs mounted_fs
    mounted_fs = []
    mounts = subprocess.run('mount',
                            stdout=subprocess.PIPE,
                            text=True,
                            check=True)
    for mount in mounts.stdout.split('\n'):
        # print(mount)
        components = mount.rstrip('\n').split(' ')
        # print(components)
        if len(components) > 3:
            if components[4] == 'btrfs':
                mounted_fs.append(components[2])
    return mounted_fs


def dict_of_snapshots(filesystem):
    # Parse the snapshots for a given filesystem
    # Returns a dict of {'id': 'snapshot_object'...}
    snapshots = {}
    root_snapshot = Snapshot(5, 0, 0, 0, filesystem, 0, 0)
    snapshots['5'] = root_snapshot
    parents = {}
    parents[5] = 1
    cmd = ['sudo', 'btrfs', 'subvolume', 'list', filesystem]
    subvols = subprocess.run(cmd,
                             stdout=subprocess.PIPE,
                             text=True,
                             check=True)
    for subvol in subvols.stdout.split('\n'):
        components = subvol.split()
        # print(components)
        if len(components) > 1:
            snap_id = components[1]
            gen = components[3]
            parent_id = components[6]
            path = f'{filesystem}/{components[8]}'
            snapshot = Snapshot(snap_id, gen, parent_id, 0, path, 0, 0)
            snapshots[snap_id] = snapshot
            print('snapshot:', snapshot)

    # print(snapshots)

    # get the qgroups to determine the size of each snapshop
    cmd = ['sudo', 'btrfs', 'qgroup', 'show', '--raw', filesystem]
    qgroup_show = subprocess.run(cmd,
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE,
                                 text=True,
                                 check=True)
    # print('OUT:', qgroup_show.stdout)
    # print('ERR:', qgroup_show.stderr)
    err = 'ERROR: can\'t list qgroups: quotas not enabled'
    if err in qgroup_show.stderr.split('\n'):
        print('Quotas not enabled:', qgroup_show.stderr.split('\n')[0])

        cmd = ['sudo', 'btrfs', 'quota', 'enable', filesystem]
        print('Starting the quota enabling', cmd)
        result = subprocess.run(cmd,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                text=True,
                                check=True)
        print('OUT:', result.stdout)
        print('ERR:', result.stderr)
    else:
        for snapshot in qgroup_show.stdout.split('\n'):
            # print('line:', snapshot)
            components = snapshot.split()
            if ('Qgroupid' not in components and
                    r'--------' not in components):
                print(components)
                if len(components) > 1:
                    ids = components.pop(0)
                    qgroupid, snap_id = ids.split('/')
                    snapshot = snapshots[snap_id]
                    # print(qgroupid, snap_id, components, snapshot)
                    snapshots[snap_id].qgroupid = qgroupid
                    snapshots[snap_id].refr_size = components[0]
                    snapshots[snap_id].excl_size = components[1]
                    # print('snapshot:', snapshots[snap_id])

    return snapshots


def main(filesystems: list) -> None:
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

    # win = tk.Tk()
    # win.title('Parsing QGroups')

    # win.resizable(0,0)
    # win.mainloop()


if __name__ == '__main__':
    # pass whatever command line args are there
    print(sys.argv, len(sys.argv))
    if len(sys.argv) == 1:
        print('looking')
        filesystems = btrfs_mounted_fs()
    else:
        filesystems = sys.argv[1:]

    main(filesystems)
