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

# Constants
VERBOSE = True


class Filesystem:
    def __init__(self, label, uuid, mountpoint):
        self.label = label
        self.uuid = uuid
        self.mountpoint = mountpoint

    def __str__(self):
        return f'{self.label}, {self.uuid}, {self.mountpoint}'


class Snapshot:
    def __init__(self,
                 filesystem: str,
                 snap_id: int,
                 gen: int,
                 parent: int,
                 groupid: int,
                 path: str,
                 excl_size: int,
                 refr_size: int):
        self.filesystem = filesystem
        self.snap_id = snap_id
        self.gen = gen
        self.parent = parent
        self.groupid = groupid
        self.path = path
        self.excl_size = excl_size
        self.refr_size = refr_size

    def __str__(self):
        return (f'ID {self.parent}/{self.snap_id} GroupID {self.groupid}'
                f' {self.filesystem}/{self.path},'
                f' EX: {pretty_bytes(self.excl_size)},'
                f' RF: {pretty_bytes(self.refr_size)}')


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


def run_external_cmd(cmd: list) -> subprocess.CompletedProcess:
    """
    Run and external command and return the results.

    :param cmd: command in the form of a list
    :return: Completed process instance
    """
    result = subprocess.run(cmd,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            text=True,
                            check=True)
    # print('OUT:', result.stdout)
    # print('ERR:', result.stderr)
    return result


def btrfs_mounted_fs() -> list:
    # Look for all btrfs mounted_fs
    mounted_fs = []
    mounts = run_external_cmd('mount')
    for mount in mounts.stdout.split('\n'):
        # print(mount)
        components = mount.rstrip('\n').split(' ')
        # print(components)
        if len(components) > 3:
            if components[4] == 'btrfs':
                mounted_fs.append(components[2])
    return mounted_fs


def dict_of_snapshots(filesystem: list) -> dict:
    """Return a dict of the snapshots for a given filesystem."""
    # Returns a dict of {'id': 'snapshot_object'...}
    snapshots = {}
    snapshots['5'] = Snapshot(filesystem, 5, 0, 0, 0, '/', 0, 0)
    parents = {}
    parents[5] = 1
    cmd = ['sudo', 'btrfs', 'subvolume', 'list', filesystem]
    subvols = run_external_cmd(cmd)
    for subvol in subvols.stdout.split('\n'):
        if len(subvol) > 0:
            (_, snap_id, _, gen, _, _, parent_id, _, path) = subvol.split()
            snapshot = Snapshot(filesystem, snap_id, gen,
                                parent_id, 0, path, 0, 0)
            snapshots[snap_id] = snapshot
            if VERBOSE:
                print(f'snapshot: {snapshot}')

    print(f' There are: {len(snapshots)} snapshots.')
    return snapshots


def get_size_of_snapshots(filesystem: str, snapshots: dict) -> dict:
    """Get the sizes of the filesystem snapshots."""
    # get the qgroups to determine the size of each snapshop
    cmd = ['sudo', 'btrfs', 'qgroup', 'show', '--raw', filesystem]
    qgroup_show = run_external_cmd(cmd)

    err = 'ERROR: can\'t list qgroups: quotas not enabled'
    if err in qgroup_show.stderr.split('\n'):
        print('Quotas not enabled:', qgroup_show.stderr.split('\n')[0])
        cmd = ['sudo', 'btrfs', 'quota', 'enable', filesystem]
        print('Starting the quota enabling', cmd)
        result = run_external_cmd(cmd)
        print('OUT:', result.stdout)
        print('ERR:', result.stderr)
    else:
        for snapshot in qgroup_show.stdout.split('\n'):
            # print('line:', snapshot)
            if len(snapshot) > 0:
                (qgroupid, refer, excl, path) = snapshot.split()
                if ('Qgroupid' not in qgroupid and
                        r'--------' not in qgroupid):
                    if VERBOSE:
                        print(qgroupid, refer, excl, path)
                    qgroupid, snap_id = qgroupid.split('/')
                    snapshot = snapshots[snap_id]
                    # check the path
                    if path != snapshots[snap_id].path:
                        print(('Paths don\'t match!'
                               f' {path} - {snapshots[snap_id].path}'))
                    else:
                        # print(qgroupid, snap_id, components, snapshot)
                        snapshots[snap_id].qgroupid = qgroupid
                        snapshots[snap_id].refr_size = refer
                        snapshots[snap_id].excl_size = excl
                        if VERBOSE:
                            print(f'snapshot: {snapshots[snap_id]}')

    return snapshots


def main(filesystems: list) -> None:
    # get the list of snapshots for all of the filesystems
    print(filesystems)
    snapshots_by_filesystem = {}
    for filesystem in filesystems:
        print(f'Retrieving snapshots for {filesystem}')
        snapshots = dict_of_snapshots(filesystem)
        snapshots = get_size_of_snapshots(filesystem, snapshots)
        for snap_id, snapshot in snapshots.items():
            print(f'{snap_id}: {snapshot}')

        snapshots_by_filesystem[filesystem] = snapshots

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
