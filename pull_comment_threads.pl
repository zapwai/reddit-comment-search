#!/usr/bin/perl
# Reddit Comment Search
# Copyright (C) 2017 David Ferrone
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#################################################################################
#################################################################################
# This script takes $subreddit as an argument.
# (That directory will already exist if this is called from pull_links.pl)
# 
# This script searches EACH listing in the LINKS directory and uses wget to grab
# each actual comment thread. It saves these as .json files
# in Extended_JSON_Comments. If the comments come from a 'load more comments'
# link, they will have a dash in the filename. (e.g. 1wznk9-cf6tvjb.json)

## An example of using the awesome command-line program jq:
## cat 008ny.json | jq ".[0].data.children[0].data.name"

# Main body of this script is like this:
# i) Look at a threads .json to see if it contains "kind": "more"
# ii) if it does, run get_ids on the thread.
# By saying $TEXT = <$LocalLink>; and calling it
# iii) Produce the appropriate URL.
# iv) wget the URL (it's another .json)
# v) repeat step iv recursively if necessary.
# (you just replace the last id with the new one.)
#################################################################################
#use strict;
#use warnings;

use autodie;
use Cpanel::JSON::XS;
require "routines.pl";

do "get_config.pl" if (!length $begin_edate);

if (!length $subreddit) {
    print "No subreddit provided, halt.\n"; exit;
}

print " Now downloading each reddit thread.\n";

my $target_dir = "$subreddit/Extended_JSON_Comments";
my $listing_dir = "$subreddit/LINKS";

unless (-e $target_dir or mkdir $target_dir) {
    die "Unable to create directory $target_dir\n $! \n";
}
# Listings were named with edates. So we do not have to open all of them.
my @files_to_open;
opendir my $dir, $listing_dir    or die("Cannot open LINKS $!\n"); 
foreach my $filename (readdir $dir) {
    my @pieces = split "-", $filename; 
    if ($pieces[0] >= $begin_edate and $pieces[0] < $end_edate) {
	unshift @files_to_open, $listing_dir."/".$filename;
    }
}
closedir $dir;

open $the_file, ">>", "download_file.txt"
    or die ("Ugh, unable to open... $!\n");


my $time_counter = 0;
$|=1;

foreach my $file (@files_to_open) {
    open (my $FH, "<", $file);
    my $str = <$FH>;
    close $FH;
    my $ListingJSON = decode_json $str;
    
    foreach my $item ( @{$ListingJSON->{data}->{children}} ) {
	$time_counter++;

	print "." if ($time_counter % 100 == 0);

	my $fullname = $item->{data}->{name}; 
	my $abbrev = substr $fullname, 3; # abbrev is the id
	my $link = "https://www.reddit.com/r/$subreddit/".$abbrev.".json";
	my $LocalLink = "./$target_dir/$abbrev.json";
	unless ( -s $LocalLink ){
	    print $the_file $link."\n";
	}
    }
}

# Downloading the first page of comments in a single call, much faster.
`wget -nc -i "download_file.txt"`;
unlink "download_file.txt";

foreach my $filename (<"./*.json">) {
    rename $filename, $target_dir."/".$filename;
}

# The sub-pages will be slower.
# Because we're going to download, then open, then download more, etc.
foreach my $LocalLink (<"$target_dir/*.json">) {
    open (my $FILEHANDLE, "<", $LocalLink);
    my $TEXT = <$FILEHANDLE>;
    close $FILEHANDLE;

    my ($FirstJSON, $SecondJSON) = split_merged_jsons($TEXT);

    my @MoreIDs;
    get_ids($TEXT, \@MoreIDs);
    ## MoreIDs is now empty if there is only one page of comments.
	
    my $ListingJSON = decode_json $FirstJSON;
    my $CommentJSON = decode_json $SecondJSON;
    # You could use the second JSON, it also has a permalink.
    # But *only* in a 'more' thread. Not a top-level.
    for my $listy ( @{$ListingJSON->{data}->{children}} ) {
	my $fullname = $listy->{data}->{name}; 
	my $abbrev = substr $fullname, 3; # abbrev is the id
		
	my $link = "https://www.reddit.com".$listy->{data}->{permalink};
	#		my $title = $listy->{data}->{title};
	#		$edate = $listy->{data}->{created_utc};
	foreach ( @MoreIDs ) {
	    my $MoreLink = $link.$_.".json";
	    my $new_name = "./$target_dir/$abbrev-$_.json";
	    `wget -q -nc --tries=100 -O $new_name $MoreLink`;
	    recursive_fetch($new_name, $abbrev);
	}
    }
}

close $the_file;

print "Threads received.\n";

do "search.pl";

# This pulls MoreIDs for all subthreads.
sub recursive_fetch{
    my ($new_name, $abbrev) = @_;
    open (my $filename, "<", $new_name);
    my $row = <$filename>;
    close $filename;
    # Get some info from the second JSON in $row before you maul it.
    # $abbrev is the unique id of the main thread.

    my ($FirstJSON, $SecondJSON) = split_merged_jsons($row);

    my $ListingJSON = decode_json $FirstJSON;
    my $CommentJSON = decode_json $SecondJSON;
    my $link;
    for my $listy ( @{$ListingJSON->{data}->{children}} ) {
	$link = "https://www.reddit.com".$listy->{data}->{permalink};
    }
    
    my @SubIDs;
    get_ids($row, \@SubIDs);
    foreach (@SubIDs) {
	my $MoreLink = $link.$_.".json";
	my $new_name = "./$target_dir/$abbrev-$_.json";
	`wget -q -nc --tries=100 -O $new_name $MoreLink`;
	recursive_fetch( $new_name, $abbrev );
    }
}

# If a .json contains a "more" kind, we need to pull that thread as well.
sub get_ids {
    my ($TEXT, $IDsRef) = @_;
    while ( index( $TEXT , '"kind": "more"' ) != -1 ) {
	$TEXT = substr ( $TEXT, index( $TEXT , '"kind": "more"') + 6 );
	my $start_pt = index ( $TEXT, '"id": "' ) + 7;
	$TEXT = substr ( $TEXT, $start_pt ); 
	my $stop_pt = index ( $TEXT, '"' );
	my $ID = substr($TEXT, 0, $stop_pt);
	if ( $ID eq "_" ) { 
	    my $start_pt = index ( $TEXT, '"id": "' ) + 7;
	    $TEXT = substr ( $TEXT, $start_pt ); 
	    my $stop_pt = index ( $TEXT, '"' );
	    $ID = substr($TEXT, 0, $stop_pt);
	    push @{$IDsRef}, $ID;
	    $TEXT = substr ( $TEXT, $stop_pt + 1 );
	} else {
	    push @{$IDsRef}, $ID;
	    $TEXT = substr ( $TEXT, $stop_pt + 1 );
	}
    }
}
