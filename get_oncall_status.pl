#!/usr/bin/perl -w

use strict;

# sample script for use in a cron to email the weekly on call
# schedule.  pipe output to mail

sub pagerd($;$) {
	my $sGroup = shift;
	my $iPlusDays = shift || 0;

	return `/usr/local/bin/paging/pagingd oncall $sGroup $iPlusDays`;
}


print "STATION RELATIONS\n\n";
print "Today:  \t" . pagerd('StationRelations');
print "Next week:\t" . pagerd('StationRelations', 7);

print "\n\n\nOPERATIONS\n\n";
print "Today:  \t" . pagerd('Ops');
print "Next week:\t" . pagerd('Ops', 7);

