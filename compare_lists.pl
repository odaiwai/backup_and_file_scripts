#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use DBI;

# scrip to compare the local and remote file listings
# 20171112 dave o'brien
my $verbose = 1;
my $firstrun = 0;
my $clean_uuid = 0;
my $update_remote = 1;
my $update_local = 0;
my $recover = 0;
my $dry_run = 0;
my $frequency = 10;
my $remote_prefix = "/backup";

# TODO:
#   add estimated time to completion (elapsed, etc)

my $db = DBI->connect("dbi:SQLite:dbname=compare.sqlite","","") or die $DBI::errstr;
if ($firstrun) {
   print "Building the Database...\n";
    my $result = make_db();
    #my $verbose = 0;
    print "Reading in the filelists...\n";
    #$result = build_tables_from_file($db, "local_list", "local_files", $verbose);
    $result = build_tables_from_file($db, "remote_list", "remote_files", $verbose);
    # tidy up the list a bit
    dbdo($db, "delete from remote_files where filepath like '/backup/root/%';", $verbose);
    dbdo($db, "delete from remote_files where filepath like '/backup/home/.%';", $verbose);
}
if ( $update_remote ) {
    # update the local list
    print "Updating the remote list...\n";
    print "Populate the local_size, local_filepath field of the remote_files table...\n";
    my @remote_files = array_from_query($db, "Select filepath from [remote_files] where remote_size is NULL;", $verbose);
    #$verbose = 1;
    dbdo($db, "BEGIN", $verbose);
    my $numfiles = scalar(@remote_files);
    my $counter = 0;
    print "$numfiles remote files\n";
    #$verbose = 1;
    foreach my $remote_filepath (@remote_files){
        print "\t".comma_separated_thousands($counter)."/".comma_separated_thousands($numfiles).":";
        if ($verbose) {print "\n";} else {print "\r";}
        my $escaped_remote_filepath = escape_filepath($remote_filepath);
        print "Testing: $remote_filepath:" if $verbose;
        my ($local_basedir, $filename) = local_path_filename_from_remote_filename($remote_filepath);
        my $local_filepath = "$local_basedir/$filename";
        my $escaped_local_filepath = escape_filepath($remote_filepath);
        #print "(local: $local_filepath)" if $verbose;
	     if ( -e "$escaped_remote_filepath") {
            print " exists and " if $verbose;
            if (-d $escaped_remote_filepath) {
                print "is a directory\n" if $verbose;
                my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, isDir, islink, remote_size, local_size) Values (\"$remote_filepath\", 1, 0, 0, 0);", 0);
            }
            if (-l $escaped_remote_filepath) {
                print "is a symbolic link\n" if $verbose;
                my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, local_size, islink, isdir) Values (\"$remote_filepath\", 0, 1, 0);", 0);
            }
            my ($remote_size, $local_size, $retrievable) = (-1, -1, 0);
            # Get the UUIDs if they exist
            my @result = row_from_query($db, "Select remote_uuid, local_uuid from [remote_files] where filepath = '$remote_filepath';", 0);
            my $remote_uuid = $result[0] // "blah";
            my $local_uuid  = $result[1] // "blah";
            if (-f $escaped_remote_filepath) {
                my @result = row_from_query($db, "Select remote_size, local_size, category from [remote_files] where filepath = '$remote_filepath';", 0);
                $remote_size = $result[0] // -1; # return value if defined or -1
                $local_size = $result[1] // -1; # return value if defined or -1
               print "is a real file ($remote_size, $local_size, $remote_uuid, $local_uuid)" if $verbose;
                my $category = $result[2] // "blah"; # return value if defined or -1
                $remote_size = (-s "$escaped_remote_filepath") if ($remote_size == -1);
                $local_size = (-s "$escaped_local_filepath") if ($remote_size == -1);
                $remote_uuid = checksum_from_filepath($remote_filepath) if ($remote_uuid eq "blah");
                $local_uuid = checksum_from_filepath($local_filepath) if ($local_uuid eq "blah");
               print "->($remote_size, $local_size, $remote_uuid, $local_uuid)\n" if $verbose;
                $retrievable = 1 if ($remote_size>=0);
                $category = category_from_filename($remote_filepath) if ($category eq "blah");
                #print "\tFile has $remote_size, $local_size bytes, Cat: $category \n" if $verbose;
                if (($remote_size != $local_size) and ($recover)) {
                    my @result = row_from_query($db, "Select category from [remote_files] where filepath = '$remote_filepath';", $verbose);
                    my $category = $result[0] // "blah"; # return value if defined or ""
                    if ($category eq "required") {
                        print "\t\tCategory: $category\n" if $verbose;
                        $category = category_from_filename($local_filepath);
                        print "\t\tCategory2: $category\n" if $verbose;
                        my $command = "rsync -aHAX --progress \"$remote_filepath\" \"$local_basedir/\"";
                        #my $command = "ddrescue \"$remote_filepath\" \"$local_filepath/\"";
                        $command =~ s/''/'/g;
                        print "\t\tCommand: $command\n";
                        my $result = `mkdir -p \"$local_basedir\" && $command 2>&1`;
                        print "\t\tResult: $result\n";
                        #sleep 2;
                    }
                }
                my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, local_filepath, remote_size, local_size, retrievable, remote_uuid, local_uuid, isdir, islink) Values (\"$remote_filepath\", \"$local_filepath\", $remote_size, $local_size, $retrievable, \"$remote_uuid\", \"$local_uuid\", 0, 0);", 0);
            }
        } else {
            print "is not a file that exists\n" if $verbose;
            if (-l $escaped_remote_filepath) {
               print "\tIt's a dead symlink\n" if $verbose;
                my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, remote_size, islink, isdir) Values (\"$remote_filepath\", 0, 1, 0);", 0);
               my $command = "rsync -aHAX --progress \"$escaped_remote_filepath\" \"$local_basedir/\"";
               #my $command = "ddrescue \"$remote_filepath\" \"$local_filepath/\"";
               $command =~ s/''/'/g;
               print "\t\tCommand: $command\n";
               my $result = `mkdir -p \"$local_basedir\" && $command 2>&1`;
               print "\t\tResult: $result\n";
               dbdo($db, "COMMIT", $verbose);
               dbdo($db, "BEGIN", $verbose);
            } else {
               #exit;
            }
            #dbdo($db, "delete from remote_files where filepath = '$remote_filepath';", $verbose);
            #dbdo($db, "COMMIT", $verbose);
            #dbdo($db, "BEGIN", $verbose);
            #exit;
        }
        $counter++;
        if (int($counter/$frequency) == ($counter/$frequency)) {
            dbdo($db, "COMMIT", $verbose);
            dbdo($db, "BEGIN", $verbose);
        }
        #sleep 1;
    }
   dbdo($db, "COMMIT", $verbose);
}
if ( $update_local ) {
    # update the local list
    print "Updating the local list...\n";
    print "Populate the local_size, local_filepath field of the remote_files table...\n";
	#my @local_files = array_from_query($db, "Select filepath from [remote_files] where isDir = 0 and (local_size = -1 or local_uuid = 'blah');", $verbose);
    my @local_files = array_from_query($db, "Select filepath from [remote_files];", $verbose);
    #$verbose = 1;
    dbdo($db, "BEGIN", $verbose);
    my $numfiles = scalar(@local_files);
    my $counter = 0;
    print "$numfiles local files\n";
    #$verbose = 1;
    foreach my $remote_filepath (@local_files){
        print "\t".comma_separated_thousands($counter)."/".comma_separated_thousands($numfiles).":";
        if ($verbose) {print "\n";} else {print "\r";}
        my ($local_basedir, $filename) = local_path_filename_from_remote_filename($remote_filepath);
        my $local_filepath = "$local_basedir/$filename";
        $local_filepath=~ s/\`/\\`/g;
        print "Testing:\n\t$local_filepath:\n\tFile " if $verbose;
	     if ( -e $local_filepath) {
			print " exists and " if $verbose;
	        if (-d $local_filepath) {
	            print "is a directory\n" if $verbose;
	            my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, isDir) Values (\"$remote_filepath\", 1);", 0);
	        }
	        if (-l $local_filepath) {
	            print "is a symbolic link\n" if $verbose;
	            #my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, local_size) Values (\"[DIRECTORY]\", 0);", $verbose);
	        }
	        # Get the UUIDs if they exist
	        my @result = row_from_query($db, "Select local_uuid, local_size, category from [remote_files] where filepath = '$remote_filepath';", 0);
	        my $local_uuid  = $result[0] // "blah";
			my $local_size  = $result[1] // -1;
	        my $category = $result[2] // "blah"; # return value if defined or -1
	        if (-f $local_filepath) {
				print "is a real file\n" if $verbose;
	            $local_size = (-s "$local_filepath") if ($local_size == -1);
	            $local_uuid = checksum_from_filepath($local_filepath) if ($local_uuid eq "blah");
	            $category = category_from_filename($local_filepath) if ($category eq "blah");
	            print "\tFile has $local_size bytes, Cat: $category \n" if $verbose;
	        }
	        my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, local_filepath, local_size, local_uuid) Values (\"$remote_filepath\", \"$local_filepath\", $local_size, \"$local_uuid\");", $verbose);
	    } else {
			print "does not exist!\n" if $verbose;
			$remote_filepath =~ s/''/'/g;
			if ( -f $remote_filepath) {
				my $command = "rsync -aHAX --progress \"$remote_filepath\" \"$local_basedir/\"";
				#my $command = "ddrescue \"$remote_filepath\" \"$local_filepath/\"";
				$command =~ s/''/'/g;
				print "\tCommand: $command\n";
				my $result = `mkdir -p \"$local_basedir\" && $command 2>&1`;
				print "\tResult: $result\n";
				#sleep 5;
				#exit;
			}
		}
		$counter++;
	    if (int($counter/$frequency) == ($counter/$frequency)) {
	        dbdo($db, "COMMIT", $verbose);
	        dbdo($db, "BEGIN", $verbose);
	    }
	    #sleep 1;
	}
	dbdo($db, "COMMIT", $verbose);
}


if ($recover) {
    print "Find files that differ...\n";
    $verbose = 1;
    my @remote_files = array_from_query($db, "Select filepath from [remote_files] where (remote_size != local_size) order by remote_size asc;", $verbose); # biggest files first
    my $numfiles = scalar(@remote_files);
    my $counter = 0;
    foreach my $remote_filepath (@remote_files){
        print "\t".comma_separated_thousands($counter)."/".comma_separated_thousands($numfiles).":";
        if ($verbose) {print "\n";} else {print "\r";}
        my @result = row_from_query($db, "select filepath, local_filepath, remote_size, local_size from[remote_files] where filepath = '$remote_filepath'; ", $verbose);
        my $local_filepath = $result[1];
        my $remote_size = $result[2];
        my $local_size = $result[3];
        my ($local_basedir, $local_filename) = local_path_filename_from_remote_filename($remote_filepath);
        print "\tBefore: $remote_filepath, remote:$remote_size, local:$local_size\n";
        $remote_filepath =~ s/''/'/g;
        $local_basedir =~ s/''/'/g;
        my $command = "rsync -aHAX --progress \"$remote_filepath\" \"$local_basedir/\"";
        my $result = "Not Run";
        $result = `mkdir -p \"$local_basedir\" && $command 2>&1` if !($dry_run);
        print "\t\tCommand: $command\n";
        print "\t\tResult: $result\n";
        $local_size = (-s "$local_filepath") || 0;
        print "\tAfter: $remote_filepath, remote:$remote_size, local:$local_size\n";
        $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, local_size) Values (\"$remote_filepath\", $local_size);", $verbose);
        #sleep 30 if $dry_run;
        $counter++;
        #exit;
    }
}
if ( $clean_uuid ) {
	# Find all the UUIDS that are not an error or a MD5SUM result and replace
	print "Cleaning up the UUIDs...\n";
    $verbose = 1;
    my @remote_files = array_from_query($db, "Select filepath from [remote_files] where remote_uuid != 'blah';", $verbose); # biggest files first
    my $numfiles = scalar(@remote_files);
    my $counter = 0;
    foreach my $remote_filepath (@remote_files){
        print "\t".comma_separated_thousands($counter)."/".comma_separated_thousands($numfiles).":";
        my @result = row_from_query($db, "select remote_uuid, isDir from [remote_files] where filepath = '$remote_filepath'; ", $verbose);
		my $remote_uuid = $result[0] // "blah";
		my $isDir = $result[1] // 0;
		#my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, isDir) Values (\"$remote_filepath\", $isDir);", $verbose);
		print "\t$remote_filepath: ($isDir) '$remote_uuid' - " if $verbose;
		# test for an MD5
		if ( $remote_uuid =~ /^[0-9a-fA-F]{32}$/) {
			# This is an MD5 Sum
			print " MD5SUM OK!\n" if $verbose;
		} elsif ( $remote_uuid =~ /^Input\/Output error/) {
			#
			print " Input/output error - OK\n" if $verbose;
		} elsif ( $remote_filepath =~ /\Q$remote_uuid\E/) {
			# remote_uuid is a substring of filepath
			print " Substring - replacing with 'blah'\n" if $verbose;
			$remote_uuid = "blah";
			my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, remote_uuid) Values (\"$remote_filepath\", \"$remote_uuid\");", $verbose);
		} elsif ( $remote_uuid = "null" ) {
			$remote_uuid = "blah";
			my $result = dbdo($db, "Insert or Replace into [remote_files] (filepath, remote_uuid) Values (\"$remote_filepath\", \"$remote_uuid\");", $verbose);
		} else {
			print " NOT OK!\n" if $verbose;
			$remote_uuid = "blah";
			exit;
		}
		$counter++;
	}
 # them with "blah"
}
# todo:
#   select files that are different sizes in remote and local and try to recover them
#   Select filepath from local_files where local_size != remote_size order by remote_size
#   rsync -aHAX $remote_path $local_basedir
#   if that doen

$db->disconnect();
# Database stuff
sub make_db {
    #Make the Database Structure
    print "making the database: $db\n" if $verbose;
    my %tables = (
        "local_files"=>"filepath TEXT PRIMARY KEY, filename TEXT, basedir TEXT, size Integer, Category TEXT, remote_filepath TEXT, remote_size INTEGER, UUID TEXT, isDir Integer, isLink Integer, LinkDest TEXT",
        "remote_files"=>"filepath TEXT PRIMARY KEY, filename TEXT, basedir TEXT, remote_size Integer, Category TEXT, local_filepath TEXT, local_size Integer, remote_UUID Text, local_uuid Text, isDir Integer, isLink Integer, LinkDest TEXT, retrievable Integer");
    my %indices = (
        "remote_file_index"=>"[remote_files] (filepath, remote_size, local_size)",
        "local_file_index"=>"[local_files] (filepath, size)");
    my @commands;
    foreach my $tablename (%tables) {
        if (exists $tables{$tablename} ) {
            push @commands, "Drop Table if exists [$tablename];";
            push @commands, "Create Table if not exists [$tablename] ($tables{$tablename})";
        }
    }
    foreach my $index (%indices) {
        if (exists $indices{$index} ) {
            push @commands, "Create UNIQUE Index $index on $indices{$index};";
        }
    }
    foreach my $command (@commands) {
        my $result = dbdo($db, $command, $verbose);
    }

    #build_tables_from_files($db);
}
sub build_tables_from_file {
    my $db = shift;
    my $file = shift;
    my $table = shift;
    my $verbose = shift;
    open (my $infh, "<", $file); #`sudo tree -ifa $dir`;
    dbdo($db, "BEGIN", $verbose);
    while (my $line = <$infh> ) {
        chomp $line;
        my ($remote_size, $isDir, $isLink, $linkDest, $retrievable) = (0, 0, 0, "", -1);
        my $filepath = sanitise_line_for_input($line);
        # Some $filepath are select links and are stored as $linkname -> $linkDest
        if ( $filepath =~ /^(.*) -> (.*)$/) {
            print "\tSymlink: $filepath -> $linkDest\n" if $verbose;
            my ($linkname, $dest) = split " -> ", $filepath;
            $isLink = 1;
            $filepath = $linkname;
            if ($dest =~ /^\./) {
                # relative link
                my ($filename, $basedir) = filename_and_basedir_from_filepath ($filepath);
                $linkDest = "$basedir/$dest";
            } else {
                $linkDest = $dest;
            }
            print "\tSymlink: $filepath -> $linkDest\n" if $verbose;
            #exit;
        }
        my ($filename, $basedir) = filename_and_basedir_from_filepath ($filepath);
        my $category = category_from_filename($filepath);
        if (-d $filepath) { # is a directory
            $isDir = 1;
        }
        if (-f $filepath) { # is a real file
            $remote_size = (-s $filepath);
        }
        my $result = dbdo($db, "INSERT or REPLACE into [$table] (filepath, filename, basedir, remote_size, category, isDir, isLink, linkDest, retrievable) Values (\"$filepath\", \"$filename\", \"$basedir\", $remote_size, \"$category\", $isDir, $isLink, \"$linkDest\", $retrievable);", $verbose);
        #exit;
    }
    dbdo($db, "COMMIT", $verbose);
    close $infh;
}
sub sanitise_line_for_input {
    my $line = shift;
    $line =~ s/\"/#/g;
    $line =~ s/\'/''/g;
    $line =~ s/`/\`/g;
    return $line;
}
sub filename_and_basedir_from_filepath {
    my $filepath = shift;
    my @components = split "/", $filepath;
    my $filename = pop @components;
    my $basedir = join "/", @components;
    return ($filename, $basedir);
}
sub local_path_filename_from_remote_filename {
    # assume that the first two components are the remote prefix
    my $remote_filename = shift;
    #$remote_filename s/$remote_prefix//;
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
    if ($filename =~ /\/home\/odaiwai\/tmp/) { $category = "tmp";}
    if ($filename =~ /cache/) { $category = "cache";}
    if ($filename =~ /iTunes U/) { $category = "ignore";}
    if ($filename =~ /MediaLibrary/) { $category = "Media";}
    #if ($filename =~ /cache/) { $category = "ignore";}
    #if ($filename =~ /cache/) { $category = "ignore";}
    if ($filename =~ /iPhoto Library\/Previews/) { $category = "previews";}
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
    #print "\t$db: ".length($command)." $command\n" if $verbose;
    print "\tDBDO: $command\n" if $verbose;
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

sub checksum_from_filepath {
    # return a checksum or error from a filepath
    my $filepath = shift;
	$filepath = escape_filepath($filepath);
    my $checksum_app = "md5sum";
    my $command = "$checksum_app \"$filepath\" 2>&1";
	$command =~ s/\\/\\\\/g;
	#print "\t$command\n" if $verbose;
    my $result = `$command`;
    chomp $result;
    #print "\tmd5sum $result\n";
    my ($csum, $error);
    if ($result =~ /^([a-f0-9\\]+)\s+(.*)/ ) {
        $csum = $1
    } elsif ($result =~ /^md5sum:\s+(.*)\s+(Input\/output error)$/) {
        $error = $2;
    } elsif ($result =~ /^md5sum:\s+(.*)\s+(No such file or directory)$/) {
        $error = $2;
    } else {
        print "\tUntrapped result: '$result'\n" if $verbose;
        exit;
    }
    return $csum //  $error;
}
sub comma_separated_thousands {
    my $number = shift;
    my $revnum = reverse($number);
    my @groups = unpack("(A3)*", $revnum);
    my $result = reverse(join (",", @groups));
    return $result
}
sub escape_filepath {
	my $input = shift;
	$input =~ s/\`/\\`/g;
	$input =~ s/''/\'/g;
	return $input;
}
 
