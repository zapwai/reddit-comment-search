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
################################################################################
################################################################################
## pull_links:
# Pulls LISTINGS of threads between specific dates using reddit's cloudsearch.
# The timestamp uses epoch dates.
# the subreddit/LINKS folder is created if it does not already exist.
# user is prompted for start and end dates, as well as the subreddit name.
# these are convered to epoch dates, the number of days counted,
# and links for each DAY are pulled.

## An example of using the awesome command-line program jq:
## cat 008ny.json | jq ".[0].data.children[0].data.name"

## pull_comment_threads:
# This script searches EACH listing in the LINKS directory and uses wget to grab
# each actual comment thread. It saves these as .json files
# in Extended_JSON_Comments. If the comments come from a 'load more comments'
# link, they will have a dash in the filename. (e.g. 1wznk9-cf6tvjb.json)
#
# i) Look at a threads .json to see if it contains "kind": "more"
# ii) if it does, run get_ids on the thread.
# By saying $TEXT = <$LocalLink>; and calling it
# iii) Produce the appropriate URL.
# iv) wget the URL (it's another .json)
# v) repeat if necessary.

## search:
# This will search each comment thread in the subreddit folder,
# and produce hashes of links, one for submissions, one for comments,
# containing all occurrences where $username is the author.

# If you desire a case sensitive search
# find each occurrence of =~ /$string/i
# and remove the letter i.

# Currently inefficient.
# For instance, Creates two sets of hashes for no real reason.
# Also many double-checks on existence of $username and $string.
# Lack of logic everywhere.
# The index and checking is unnecessary - reddit ids are ordered alphabetically.

################################################################################
package Local::Foo;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( pull_links pull_comment_threads search );

use strict;
use warnings;

use autodie;
use Cpanel::JSON::XS;

use Local::Routines qw( is_valid_date get_edate split_merged_jsons );


sub pull_links {
    my ($subreddit, $begin_edate, $end_edate ) = @_;
    my $TIME_PERIOD = $Local::GetConfig::ONE_DAY; 

    # Number of days to download.
    my $TOTAL_PERIODS = ($end_edate - $begin_edate)/$TIME_PERIOD; 

    # Make the subreddit directory if it does not already exist.
    unless(-e $subreddit or mkdir $subreddit) {
	die "Unable to create directory $subreddit\n $! \n";
    }

    # Make the listings directory if it does not already exist.
    my $listing_dir = "./".$subreddit."/LINKS";
    unless(-e $listing_dir or mkdir $listing_dir) {
	die "Unable to create directory $listing_dir\n $! \n";
    }

    print "Downloading thread listings.\n";

    my $cnt;			# counter for long downloads.
    $| = 1;

    my $START_TIME = $begin_edate;
    my $END_TIME = $START_TIME + $TIME_PERIOD;
    foreach my $k (1..$TOTAL_PERIODS) {
	my $linkaddy = "https://www.reddit.com/r/".$subreddit
	    ."/search.json?q=timestamp:$START_TIME..$END_TIME"
	    .'&sort=new&restrict_sr=on&limit=100&syntax=cloudsearch';
	my $filename = "$listing_dir/$START_TIME-to-$END_TIME.json";
	`wget -nc -q --tries=100 -O $filename "$linkaddy"`; 
	$START_TIME += $TIME_PERIOD;
	$END_TIME += $TIME_PERIOD;

	# Tiny bit of feedback is nice.
	$cnt++;
	print "." if ($cnt % 100 == 0);
    }

    print "\nListings received."; 
}


sub pull_comment_threads {
    my ($subreddit, $begin_edate, $end_edate ) = @_;
    
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

    open my $the_file, ">>", "download_file.txt"
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
    close $the_file;
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

    print "Threads received.\n";

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

}

sub search {
    my ( $begin_edate, $end_edate, $subreddit, $username, $string, $print_option,
	 $get_option ) = @_;
    my $config_report = <<"endl";
 Config file supplied the following:
 startdate:$Local::GetConfig::user_begin
 enddate:$Local::GetConfig::user_end
 subreddit:$subreddit
 username:$username
 string:$string
 print_comments:$print_option
endl
    # download_program:$get_option
    print $config_report;

    if (!-e $subreddit) {
	print "The folder $subreddit does not appear to exist...\n";
	print "(Have you run the pull_links.pl script?)\n";
	exit;
    }

    unless (!length($string) or !length($username)) {
	print "\nI will return threads from the $subreddit 
folder in which /u/$username said the string:$string.\n";
    }

    if (!length($string) and !length($username)) {
	print "(No username and no string will simply print all 
links in your requested timeframe.)\n";
    } elsif (!length $string and length $username) {
	print "\nA general search for /u/$username in the $subreddit folder.\n";
    } elsif (length $string and !length $username) {
	print "\nA general search for the string \"$string\" in the 
$subreddit folder.\n";
    }


    my $link;			# permalink to the thread itself.
    my %submit_link; # Submitted links by $username (key is edate of submission)
    my %comment_link; # Commented links by $username (key is edate of comment)

    my %comment_content; # The body of the comments. (key is edate of comment)

    # In the event that a string was supplied in $string, we ALSO use these:
    my %string_comment_link;
    my %string_comment_content;
    my %string_comment_author;

    my $target_dir = "$subreddit/Extended_JSON_Comments";
    my $index_filename = $target_dir."/_INDEX";
    unless (-e $index_filename) {
	print "Creating index of dates --> files.\n";
	index_creator( $subreddit );
	#	`perl index_creator.pl $subreddit`;
    }
    my @files_to_open;
    print "Reading index";
    open (my $FILE, "<", $index_filename);
    my $time_counter = 0;
    $| = 1;
    while (my $line = <$FILE>) {
	chomp($line);
	my @pieces = split("\t", $line);
	if ($pieces[0] < $begin_edate) {
	    if ($time_counter == 0) {
		$time_counter++;
		print ".";
	    }
	    next;
	} elsif ($pieces[0] > $end_edate) {
	    if ($time_counter == 2) {
		$time_counter++;
		print ".";
	    }
	    next;
	} else {
	    if ($time_counter == 1) {
		$time_counter++;
		print ".";
	    }
	    push @files_to_open, $pieces[1];
	}
    }

    print " done.";
    close $FILE;
    $time_counter=0;
    print " Searching through the Reddit threads";

  THRD:
    foreach my $Thread (@files_to_open) {
	open (my $FILE, "<", $Thread)
	    or die("Thread $Thread cannot be opened.\n$!\n");
	my $row = <$FILE>;	# unnecessary assignment.
	close $FILE;
	$time_counter++;
	print "." if ($time_counter % 100 == 0);
	my ($FirstJSON, $SecondJSON) = split_merged_jsons($row);
    
	$FirstJSON = decode_json($FirstJSON);
	$SecondJSON = decode_json($SecondJSON);

	for my $listy ( @{$FirstJSON->{data}->{children}} ) {
	    $link = "https://www.reddit.com".$listy->{data}->{permalink};
	    my $edate = $listy->{data}->{created_utc};

	    if (!length($string) and !length($username)) {
		$submit_link{$edate} = $link;
		next THRD;
	    }
	    unless (!length $username) {
		my $author = $listy->{data}->{author};
		if (is_username($author)) {
		    $submit_link{$edate} = $link;
		}
	    }
	}

	for my $contenty ( @{$SecondJSON->{data}->{children}} ) {
	    # my $id = $contenty->{data}->{link_id}; 
	    # $id = substr($id,3);  # If you need the id of the thread itself.
	
	    my $author = $contenty->{data}->{author};
	    my $edate = $contenty->{data}->{created_utc}; 
	    my $new_link = $link.$contenty->{data}->{id};
	    my $comment = $contenty->{data}->{body};

	    unless (!length $username) {
		if (is_username($author)) {
		    # Search for the string, if one was supplied.
		    unless (!length $string) {
			if ($comment =~ /$string/i) {
			    $string_comment_link{$edate} = $new_link;
			    $string_comment_content{$edate} = $comment;
			}
		    }
		    $comment_link{$edate} = $new_link;
		    $comment_content{$edate} = $comment;
		}
	    
	    }
	    # Just check for the string, if there is no username.
	    if (!length $username) {
		unless (!length $string) {
		    if ($comment =~ /$string/i) {
			$string_comment_link{$edate} = $new_link;
			$string_comment_content{$edate} = $comment;
			$string_comment_author{$edate} = $author;
		    }
		}
	    }
	    # If no reply we are done. Otherwise traverse the replies.
	    unless (!length $contenty->{data}->{replies}) { 
		my $hash_ref_to_replies = $contenty->{data}->{replies};
		traverse_replies($hash_ref_to_replies);
	    }
	}
    }

    print " done.\n";

    ## Print submissions.
    unless (!(scalar keys %submit_link)) {
	print "\n";
	print "Submissions";
	print " by /u/$username: " unless (!length $username);
	print "\n";
	foreach (sort keys %submit_link) {
	    print "$_: ",$submit_link{$_};
	    print "\n";
	}
    }
    ## If no string was supplied, print all comments by given username.
    if (!length $string) {
	print "All comments";
	print " by /u/$username: " unless (!length $username);
	print "\n";
	foreach (sort keys %comment_link) {
	    print "$_: ",$comment_link{$_};
	    print "\n";
	    unless ($print_option eq "N"){
		print $comment_content{$_};
		print "\n";
	    }
	}
    }
    ## If a search string was supplied to $string, print the string hash.
    elsif (length $string) {
	print "Comments ";
	unless (!length $username) {
	    print "by /u/$username ";
	}
	print "containing the string \"$string\": \n";
	foreach (sort keys %string_comment_link) {
	    print "$_: ",$string_comment_link{$_};
	    print "\n";
	    unless ($print_option eq "N"){
		print $string_comment_content{$_};
		print "\n";
	    }
	    if (!length $username) {
		print "\t--".$string_comment_author{$_}."\n";
	    }
	}
    }

    sub is_username {
	my $author = shift;
	if ($username eq $author) {
	    return 1;
	}
	return 0;
    }

    sub traverse_replies {
	my $hash_ref_to_replies = shift;
	for ( @{$hash_ref_to_replies->{data}->{children}} ) {

	    my $edate = $_->{data}->{created_utc};
	    my $new_link = $link.$_->{data}->{id};
	    my $comment = $_->{data}->{body};
	    my $author = $_->{data}->{author};
	    unless ($_->{kind} eq "more") {
		unless (!length $username) {
		    if ( is_username($_->{data}->{author}) ) {
			$comment_link{$edate} = $new_link;
			$comment_content{$edate} = $comment;
			# Search for the string, if it was supplied.
			unless (!length $string) {
			    if ($comment =~ /$string/i) {
				$string_comment_link{$edate} = $new_link;
				$string_comment_content{$edate} = $comment;
			    }
			}
		    }
		}
		# Just check for the string, if there is no username.
		if (!length $username) {
		    unless (!length $string) {
			if ($comment =~ /$string/i) {
			    $string_comment_link{$edate} = $new_link;
			    $string_comment_content{$edate} = $comment;
			    $string_comment_author{$edate} = $author;
			}
		    }
		}
	    }
	    # The value of {replies} is "" when there are no replies.
	    if (!length $_->{data}->{replies}) {
		next;
	    } else {
		my $next_hash_ref = $_->{data}->{replies};
		traverse_replies($next_hash_ref);
	    }
	}
    }
}

sub index_creator {
    my $subreddit = shift;
    if (!length $subreddit) {
	print "Did you forget the subreddit argument?\n"; exit;
    }
    
    my $target_dir = "$subreddit/Extended_JSON_Comments";

    foreach my $file (<"$target_dir/*">) {
	open (my $FH, "<", $file);
	my $row = <$FH>;
	close $FH;
	my ($FirstJSON, $SecondJSON) = split_merged_jsons($row);
	my $header = decode_json $FirstJSON;
	my $edate;
	for my $item ( @{$header->{data}->{children}} ) {   
	    $edate = $item->{data}->{created_utc};
	}
	open (my $FH2, ">>", "$target_dir/_INDEX");
	print $FH2 $edate."\t".$file."\n";
	close $FH2;
    }

}

1;
