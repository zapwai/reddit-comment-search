# This is only top-level comments at the moment.
# Will have to write a recursive function to parse all replies.


# jq "." Buddhism/Extended_JSON_Comments/15sk1n-c7r0v33.json | grep replies -C 5

use warnings;
use strict;
use JSON;

my ($subreddit, $username) = (shift, shift);

# Reddit thread JSONs are two merged together. e.g. [{},{}]
# We remove the [] and creating a header $FirstJSON and a content $SecondJSON

our $link;	      # ... easiest to use a global variable.
my %submit_link;      # Submitted links by $username, keys are edates.
my %comment_link;     # Commented links by $username (key is edate)

my $cnt=0; 			# testing, remove
my $limit=5;			# testing, remove
foreach my $Thread (<"$subreddit/Extended_JSON_Comments/*">) {
    last if ($cnt == $limit);	# testing remove
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
    $cnt++;			# testing, remove

    $FirstJSON = decode_json($FirstJSON);
    $SecondJSON = decode_json($SecondJSON);

    my $edate;
    
    for my $listy ( @{$FirstJSON->{data}->{children}} ) {
	my $author = $listy->{data}->{author};

	$link = "https://www.reddit.com".$listy->{data}->{permalink};
	
	if (&is_author($author)) {
	    $edate = $listy->{data}->{created_utc};
	    #	    my $id = $listy->{data}->{id}; # works for header JSON
	    my $title = $listy->{data}->{title};
	    $submit_link{$edate} = "<br><a href='".$link."'>".$title."</a><br>";
	}
    }

    for my $contenty ( @{$SecondJSON->{data}->{children}} ) {
	my $id = $contenty->{data}->{link_id}; 
	$id = substr($id,3);
	
	my $author = $contenty->{data}->{author};
	
	if (&is_author($author)) {
	    $edate = $contenty->{data}->{created_utc}; # not same as above
	    my $new_link = $link.$contenty->{data}->{id}."/ ";
	    #print $link;
	    # Wrong.

	    #my $new_link = "http://www.reddit.com/r/$subreddit/$id/comments/".$contenty->{data}->{id};
	    
	    # For the next version of this script...
	    # We would search the body of this comment for keywords.
	    my $comment = $contenty->{data}->{body};
	    
	    $comment_link{$edate} = "<br><a href='".$new_link."'>"."</a><br>";
	}
	
	unless ($contenty->{data}->{replies} eq "") { # If no reply weare done. Otherwise traverse replies.
	    my $hash_ref_to_replies = $contenty->{data}->{replies};
	    &traverse_replies($hash_ref_to_replies);
	}
    }
}

print "\n"x3;
print "Submissions by $username: \n";
foreach (sort keys %submit_link) {
    print "---"x10,"\n";
    print "$_: ",$submit_link{$_};
    print "\n\n";
}

print "Comments by $username: \n";
foreach (sort keys %comment_link) {
    print "---"x10,"\n";
    print "$_: ",$comment_link{$_};
    print "\n\n";
}

sub is_author {
    my $author = shift;
    if ($username eq $author) {
	return 1;
    }
    return 0;
}

sub traverse_replies {
    my $hash_ref_to_replies = shift;
    for ( @{$hash_ref_to_replies->{data}->{children}} ) {
	unless ($_->{kind} eq "more") { # The "continue this thread" links.
	    #	    print " from ", $_->{data}->{author};
	    if ( &is_author($_->{data}->{author}) ){
		my $edate = $_->{data}->{created_utc}; # not same as above
		my $new_link = $link.$_->{data}->{id};
		my $comment = $_->{data}->{body}; 
		$comment_link{$edate} = $new_link;
	    }
	    if ($_->{data}->{replies} eq "") {
		next;
	    } else {
#		print ", and then";
		my $next_hash_ref = $_->{data}->{replies};
		traverse_replies($next_hash_ref);
	    }
	}
    }
}

## Also need to fix the link that is returned on a 'more' thread.
## Currently the link is malformed, sends you to the wrong place.
## e.g.
## should be
## https://www.reddit.com/r/Buddhism/comments/15sk1n/10_must_read_life_lessons_from_buddha/c7r0v33/
## It's printing
## https://www.reddit.com/r/Buddhism/15sk1n/comments/c7pnn6k/
## That's the wrong link. That's the *top level*, nowhere near the continue link. oops.
