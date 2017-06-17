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
##################################################################################
##################################################################################

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
