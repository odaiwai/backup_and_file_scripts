#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use DBI;

# Script to review the list of files to restore and triage them
# 20171109
my $verbose = 1;
my $firstrun = 1;

my $db = DBI->connect("dbi:SQLite:dbname=files_to_restore.sqlite","","") or die $DBI::errstr;
if ($firstrun) {
    my $result = drop_all_tables($db, "files", $verbose);
    #dbdo($db, "BEGIN", $verbose);
    my $result = make_db();
    open (my $infh, "-|", "tree -ifas /backup/home");
    my ($numdirs, $numfiles);
    my $counter = 0;
    while (my $line = <$infh>) {
        chomp $line;
        print "\r$counter: $line";
        if ($line =~ /^([0-9]+) directories, ([0-9]+) files$/) {
            $numdirs = $1;
            $numfiles = $2;
            print "\t "
        }
        if ($line =~ /^\[([0-9 ]+)\]\s+(.*)$/) {
            my $remote_size = $1;
            my $remote_filename = $2;
            $remote_size =~ s/ //g;
            if (-d $remote_filename) {
                # It's a directory
                #print "\tis a directory\n";
            } elsif ( -z $remote_filename ) {
                # it has zero size and we don't care about them, they are at best lock files or flags.
                #print "\thas zero size\n";
            } else {
                # file exists and is non-zero size
                my $category = category_from_filename($remote_filename);
                my ($local_path, $filename) = local_path_filename_from_remote_filename($remote_filename);
                my $local_filename = "$local_path/$filename";
                #print "local filename: $local_filename\n";
                my $local_size = (-s $local_filename);
                if (!defined($local_size)) {$local_size = 0;}
                my ($remote_uuid, $local_uuid) = (0, 0);
                if ($local_size != $remote_size) {
                    #Only compute the UUIDs if the files are different.
                    my $remote_uuid = get_md5sum_for_filename($remote_filename);
                    my $local_uuid = get_md5sum_for_filename($local_filename);
                    if ($remote_uuid ne $local_uuid ) {
                        # remote and local files differ
                        print "\n\tREMOTE: $remote_size, $remote_uuid, \"$remote_filename\"\n";
                        print "\tLOCAL : $local_size, $local_uuid, \"$local_filename\"\n";
                        my $category = category_from_filename($remote_filename);
                        my $result = dbdo($db, "insert or replace into [files] (filename, remote_filename, remote_UUID, remote_size, local_UUID, local_path, local_size, category) Values (\"$filename\", \"$remote_filename\", \"$remote_uuid\", $remote_size, \"$local_path\", \"$local_uuid\", $local_size, \"$category\");", $verbose);
                    }
                    #sleep 1;
                }
            }
        }
        $counter++;
    }
    close $infh;
    #dbdo($db, "COMMIT", $verbose);
}

$db->disconnect();
# Database stuff
sub make_db {
    #Make the Database Structure
    print "making the database: $db\n" if $verbose;
    my %tables = (
        "files"=>"filename TEXT, remote_filename TEXT PRIMARY KEY, remote_UUID, remote_size INTEGER, local_path TEXT, local_uuid Text, local_size Integer, Category TEXT");
    foreach my $tablename (%tables) {
        if (exists $tables{$tablename} ) {
            my $command = "Create Table if not exists [$tablename] ($tables{$tablename})";
            my $result = dbdo($db, $command, $verbose);
        }
    }
    #build_tables_from_files($db);
}
sub local_path_filename_from_remote_filename {
    my $remote_filename = shift;
    my @components = split "\/", $remote_filename;
    my $base = shift @components; # lose the
    my $base2 = shift @components;# lose the
    my $filename = pop @components;   # lose the filename
    #print "$remote_filename, $base, $base2, $filename\n";
    my $local_path = join "\/", @components;
    return ("/".$local_path, $filename);
}
sub get_md5sum_for_filename {
    my $filename = shift;
    my $result = `sudo md5sum "$filename" 2>&1`;
    chomp $result;
    my ($uuid, @results) = split " ", $result;
    if ($uuid =~ /md5sum:/) {$uuid = $results[2]; }# take the error instead;
    #if ($output eq "")
    return $uuid;
}
sub category_from_filename {
    my $filename = shift;
    my $category = "required";
    if ($filename =~ /\/home\/odaiwai\/tmp/) { $category = "ignore";}
    if ($filename =~ /cache/) { $category = "ignore";}
    if ($filename =~ /\.googleearth/) { $category = "ignore";}
    return $category;
}
sub drop_all_tables {
    # get a list of table names from $db and drop them all
    my $db = shift;
    my $prefix = shift;
    my @tables;
    my $query = querydb($db, "select name from sqlite_master where type='table' and name like '$prefix%' order by name", 1);
    # we need to extract the list of tables first - sqlite doesn't like
    # multiple queries at the same time.
    while (my @row = $query->fetchrow_array) {
        push @tables, $row[0];
    }
    dbdo ($db, "BEGIN", 1);
    foreach my $table (@tables) {
        dbdo ($db, "DROP TABLE if Exists [$table]", 1);
    }
    dbdo ($db, "COMMIT", 1);
    return 1;
}
sub dbdo {
    my $db = shift;
    my $command = shift;
    my $verbose = shift;
    if (length($command) > 1000000) {
        die "$command too long!";
    }
    print "\t$db: ".length($command)." $command\n" if $verbose;
    my $result = $db->do($command) or die $db->errstr . "\nwith: $command\n";
    return $result;
}
sub querydb {
    # prepare and execute a query
    my $db = shift;
    my $command = shift;
    my $verbose = shift;
    print "\tQUERYDB: $command\n" if $verbose;
    my $query = $db->prepare($command) or die $db->errstr;
    $query->execute or die $query->errstr;
    return $query;
}
sub array_from_query {
    # return an array from a query which results in one item per line
    my $db = shift;
    my $command = shift;
    my $verbose = shift;
    my @results;
    my $query = querydb($db, $command, $verbose);
    while (my @row = $query->fetchrow_array) {
        push @results, $row[0];
    }
    return (@results);
}
sub hash_from_query {
    # return an array from a query which results in two items per line
    my $db = shift;
    my $command = shift;
    my $verbose = shift;
    my %results;
    my $query = querydb($db, $command, $verbose);
    while (my @row = $query->fetchrow_array) {
        $results{$row[0]} = $row[1];
    }
    #print Dumper(%results);
    return (\%results);
}
sub row_from_query {
    # return a single row response from a query (actully, the first row)
    my $db = shift;
    my $command = shift;
    my $verbose = shift;
    my $query = querydb($db, $command, $verbose);
    my @results = $query->fetchrow_array;
    return (@results);
}

