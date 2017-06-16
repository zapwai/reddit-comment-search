use DateTime;

sub is_valid_date {
    my $date = shift;
    if ($date =~ m/[^\d]/){print "Non-numeric character encountered in date.\n"; exit;}
    if (length($date) != 6){print "Wrong date length encountered.\n"; exit;}
    return 1;
}

sub get_edate {
    my $date = shift;
    my @digits = split "", $date;
    my $day = $digits[2].$digits[3];
    my $month = $digits[0].$digits[1];
    my $year = "20".$digits[4].$digits[5];
    my $dt = DateTime->new(
	year => $year,
	month => $month,
	day => $day,
	hour => 0,
	minute => 0,
	second => 0, 
    );
    my $edate = $dt->epoch;
    return $edate;
}
1;
