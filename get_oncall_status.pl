#!/usr/bin/perl -w

use strict;

# where is the paging daemon installed?
my $PAGINGD = '/usr/local/bin/paging/pagingd';


# sample script for use in a cron to email the weekly on call
# schedule.  pipe output to mail

sub pagerd($;$) {
	my $sGroup = shift;
	my $iPlusDays = shift || 0;

	return `$PAGINGD oncall $sGroup $iPlusDays`;
}


# here we hardcode some group names that we have oncall schedules for
# we say we want to see who is oncall now and who is oncall 7 days from now

print "STATION RELATIONS\n\n";
print "Today:  \t" . pagerd('StationRelations');
print "Next week:\t" . pagerd('StationRelations', 7);

print "\n\n\nOPERATIONS\n\n";
print "Today:  \t" . pagerd('Ops');
print "Next week:\t" . pagerd('Ops', 7);

