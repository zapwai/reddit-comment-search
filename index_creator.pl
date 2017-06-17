#!/usr/bin/perl
use JSON;
use autodie;
require "routines.pl";

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
    open (my $FH, ">>", "$target_dir/_INDEX");
    print $FH $edate."\t".$file."\n";
    close $FH;
}
