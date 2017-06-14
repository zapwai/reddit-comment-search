#!/usr/bin/perl

## Requires config file.
## This will search each comment thread in the subreddit folder,
## and produce two hashes of links, one for submissions, one for comments,
## containing all occurrences where $username is the author.

## Currently inefficient. Creates two hashes for no real reason.

#use warnings;
#use strict;
use JSON;

my $config_file = "scraper_config.txt";
if (!-e $config_file) {
    print "No configuration file, halt.\n";
    print "Please run pull_links.pl first.\n";
    exit;
}

my ($user_begin, $user_end, $subreddit, $username, $keywords);

if (-e $config_file) {
    open (FH, "<", $config_file);
    my @data;
    while (my $line = <FH>){
	my @pieces = split(":", $line);
	push @data, pop @pieces;
    }
    ($user_begin, $user_end, $subreddit, $username, $keywords) = @data;
}

chomp ($user_begin, $user_end, $subreddit, $username, $keywords);

unless (!$keywords) {
    print "\nI will return only the threads in the $subreddit folder by /u/$username containing the string:$keywords.\n";
}
if (!$keywords) {
    print "\nA general search for /u/$username in the $subreddit folder.\n";
}

# Reddit thread JSONs are two merged together. e.g. [{},{}]
# We remove the [], then create header ($FirstJSON) and content ($SecondJSON).
# For some context check out a .json file, perhaps try the jq command. e.g.
# jq "." Buddhism/Extended_JSON_Comments/15sk1n-c7r0v33.json | grep replies -C 5

our $link;	 # permalink to the thread itself.
my %submit_link; # Submitted links by $username (key is edate of submission)
my %comment_link; # Commented links by $username (key is edate of comment)

my %comment_content; # The body of the comments. (key is edate of comment)

### In the event that a string was supplied in $keywords, we use these:
my %keyword_comment_link;
my %keyword_comment_content;

#my $cnt=0; 			# testing, remove
#my $limit=10;			# testing, remove
foreach my $Thread (<"$subreddit/Extended_JSON_Comments/*">) {
#    last if ($cnt == $limit);	# testing remove
    open (my $FILE, $Thread) or die("Thread $Thread cannot be opened.\n$!\n");
    my $row = <$FILE>;
    close $FILE;
    # I want the location of the  second  occurance of the word "Listing".
    # I need to split the JSONs a bit earlier than this, at comma.
    my $MehPt = index( $row, 'Listing' ) + 3;
    my $BrokenRow = substr ( $row, $MehPt );
    my $EndPt = index( $BrokenRow, 'Listing' ) + 4;
    my $FirstJSON= substr ( $row, 1 , ($EndPt - 3) ); 
    my $SecondJSON = substr ( $row, $EndPt , -1);
#    $cnt++;			# testing, remove

    $FirstJSON = decode_json($FirstJSON);
    $SecondJSON = decode_json($SecondJSON);

    for my $listy ( @{$FirstJSON->{data}->{children}} ) {
	my $author = $listy->{data}->{author};

	$link = "https://www.reddit.com".$listy->{data}->{permalink};
	
	if (is_username($author)) {
	    my $edate = $listy->{data}->{created_utc};
	    # {id} in header JSON (in content JSON it's under {link_id}).
	    #	    my $id = $listy->{data}->{id}; 
	    my $title = $listy->{data}->{title};
	    $submit_link{$edate} = $link;
	}
    }

    for my $contenty ( @{$SecondJSON->{data}->{children}} ) {
	my $id = $contenty->{data}->{link_id}; 
	$id = substr($id,3);
	
	my $author = $contenty->{data}->{author};
	
	if (is_username($author)) {
	    my $edate = $contenty->{data}->{created_utc}; 
	    my $new_link = $link.$contenty->{data}->{id};

	    my $comment = $contenty->{data}->{body};
	    # Search for the string, if one was supplied.
	    unless (!$keywords) {
		if ($comment =~ /$keywords/) {
		    $keyword_comment_link{$edate} = $new_link;
		    $keyword_comment_content{$edate} = $comment;
		}
	    }
	    
	    $comment_link{$edate} = $new_link;
	    $comment_content{$edate} = $comment;
	}
	# If no reply we are done. Otherwise traverse the replies.
	unless ($contenty->{data}->{replies} eq "") { 
	    my $hash_ref_to_replies = $contenty->{data}->{replies};
	    traverse_replies($hash_ref_to_replies);
	}
    }
}

## We always print submissions.
print "\n";
print "Submissions by /u/$username: \n";
foreach (sort keys %submit_link) {
    print "---"x10,"\n";
    print "$_: ",$submit_link{$_};
    print "\n";
}


## If no keyword was supplied, print all comments by given username.
if (!$keywords) {
    print "Comments by /u/$username: \n";
    foreach (sort keys %comment_link) {
	print "---"x10,"\n";
	print "$_: ",$comment_link{$_};
	print "\n\n";
	print $comment_content{$_};
	print "\n\n";
    }
}
## If a search string was supplied to $keywords, print the other hash.
elsif ($keywords) {
    print "Comments by /u/$username containing $keywords: \n";
    foreach (sort keys %keyword_comment_link) {
	print "---"x10,"\n";
	print "$_: ",$keyword_comment_link{$_};
	print "\n\n";
	print $keyword_comment_content{$_};
	print "\n\n";
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
	# The "continue this thread" links.
	unless ($_->{kind} eq "more") { 
	    if ( is_username($_->{data}->{author}) ) {
		my $edate = $_->{data}->{created_utc};
		my $new_link = $link.$_->{data}->{id};
		my $comment = $_->{data}->{body};
		$comment_link{$edate} = $new_link;
		$comment_content{$edate} = $comment;
		# Search for the string, if it was supplied.
		unless (!$keywords) {
		    if ($comment =~ /$keywords/) {
			$keyword_comment_link{$edate} = $new_link;
			$keyword_comment_content{$edate} = $comment;
		    }
		}
	    }
	    if ($_->{data}->{replies} eq "") {
		next;
	    } else {
		my $next_hash_ref = $_->{data}->{replies};
		traverse_replies($next_hash_ref);
	    }
	}
    }
}
