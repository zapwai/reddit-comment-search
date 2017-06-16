#!/usr/bin/perl
# Copyright 2017 David Ferrone
#
# This script takes $subreddit as an argument.
# (That directory will already exist if this is called from pull_links.pl)
#
# This script searches each listing in the LINKS directory and uses wget to grab each actual comment thread.
# It saves these as .json files in Extended_JSON_Comments.
# If the comments come from a 'load more comments' link, they will have a dash in the filename. (e.g. 1wznk9-cf6tvjb.json)

## An example of using the awesome command-line program jq:
## cat 008ny.json | jq ".[0].data.children[0].data.name"

# Despite manually checking for existence of the file, we also use no-clobber mode, adding -nc to the wget, so it doesn't waste bandwidth.
use autodie;
use JSON;
require "resources.pl";

my $subreddit = shift;
if (!length $subreddit) {
    print "No subreddit provided, halt.\n"; exit;
}
my @MoreIDs;
my $target_dir = "$subreddit/Extended_JSON_Comments";

# This pulls MoreIDs for all sub_threads.
sub Recursive_Fetch{
    my ($NewName, $abbrev) = @_;
    open (my $FILENAME, "<", $NewName);
    my $row = <$FILENAME>;
    close $FILENAME;
    # Get some info from the second JSON in $row before you maul it.
    # $abbrev is just the unique id of the main thread.
    # $perma is its permalink which will be prepended in the $MoreLink

    my ($FirstJSON, $SecondJSON) = split_merged_jsons($row);

    my $ListingJSON = decode_json $FirstJSON;
    my $CommentJSON = decode_json $SecondJSON;
    my $link;
    for my $listy ( @{$ListingJSON->{data}->{children}} ) {
	$link = "https://www.reddit.com".$listy->{data}->{permalink};
    }
    my @SubIDs;
    while ( index( $row , '"kind": "more"' ) != -1) {
	$row = substr ( $row, index( $row , '"kind": "more"') + 6 );
	my $start_pt = index ( $row, '"id": "' ) + 7;
	$row = substr ( $row, $start_pt ); 
	my $stop_pt = index ( $row, '"' );
	my $ID = substr($row, 0, $stop_pt);
	#normal case. Move to next occurance of id.
	if ( $ID eq "_" ) {
	    my $start_pt = index ( $row, '"id": "' ) + 7;
	    $row = substr ( $row, $start_pt ); 
	    my $stop_pt = index ( $row, '"' );
	    $ID = substr($row, 0, $stop_pt);
	    push @SubIDs, $ID;
	    $row = substr ( $row, $stop_pt + 1 );
	} else {
	    push @SubIDs, $ID;
	    $row = substr ( $row, $stop_pt + 1 );
	}
    }
    foreach (@SubIDs) {
	my $MoreLink = $link.$_.".json";
	my $NewName = "./$target_dir/$abbrev-$_.json";
	`wget -q -nc -O $NewName $MoreLink`;
	Recursive_Fetch($NewName, $abbrev);
    }
}

# This pulls MoreIDs for the main thread.
sub print_ids {
    my $TEXT = shift;
    while ( index( $TEXT , '"kind": "more"' ) != -1) {
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
	    push @MoreIDs, $ID;
	    $TEXT = substr ( $TEXT, $stop_pt + 1 );
	} else {
	    push @MoreIDs, $ID;
	    $TEXT = substr ( $TEXT, $stop_pt + 1 );
	}
    }
}

    unless (-e $target_dir or mkdir $target_dir) {
	die "Unable to create directory $target_dir\n $! \n";
    }

my $Listing_dir = "$subreddit/LINKS";		

my @files = <"$Listing_dir/*">;
foreach my $file (@files) {
    print "$file \n";
    open (my $FH, "<", $file);
    my $str = <$FH>;
    close $FH;
    my $listing = decode_json $str;
    
    foreach my $item ( @{$listing->{data}->{children}} ) {   
	my $fullname = $item->{data}->{name}; 
	my $abbrev = substr $fullname, 3; # abbrev is the id
	my $link = "https://www.reddit.com/r/$subreddit/".$abbrev.".json";
	my $LocalLink = "./$target_dir/$abbrev.json";
	unless ( -s $LocalLink ){
	    `wget -q -nc -O $LocalLink $link`;
	}
	## Now before we move on, we should...
	# i) Look at this threads .json to see if it contains "kind": "more"
	# ii) if it does, run print_ids on the thread.
	# By saying $TEXT = <$LocalLink>; and calling it
	#  iii) Produce the appropriate URL.
	# iv) wget the URL (it's another .json)
	# v) repeat step iv recursively if necessary.
	# (you just replace the last id with the new one.)
	open (my $FILEHANDLE, "<", $LocalLink);
	my $TEXT = <$FILEHANDLE>;
	close $FILEHANDLE;
	my $row = $TEXT;
	print_ids($TEXT);      # @MoreIDs is now full, or still empty.

	my ($FirstJSON, $SecondJSON) = split_merged_jsons($row);
	
	my $ListingJSON = decode_json $FirstJSON;
	my $CommentJSON = decode_json $SecondJSON;
	# You can use the second JSON, it also has a permalink.
	# But only in a 'more' thread. Not a top-level.
	for my $listy ( @{$ListingJSON->{data}->{children}} ) {
	    my $link = "https://www.reddit.com".$listy->{data}->{permalink};
	    #		my $title = $listy->{data}->{title};
	    #		$edate = $listy->{data}->{created_utc};
	    foreach ( @MoreIDs ) {
		my $MoreLink = $link.$_.".json";
		my $NewName = "./$target_dir/$abbrev-$_.json";
		`wget -q -nc -O $NewName $MoreLink`;
		Recursive_Fetch($NewName, $abbrev);
	    }
	    @MoreIDs = ();
	}
    }
}

exec("perl search.pl");
