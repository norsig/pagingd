package DSPS_SystemFilter;

use FreezeThaw qw(freeze thaw);
use DSPS_User;
use DSPS_Debug;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = ();

our $iFilterRecoveryLoadTill = 0;
our $iFilterAllNagiosTill = 0;
our %rFilterRegex;


sub freezeState() {
    my %hFilterState;

    $hFilterState{recovery} = $iFilterRecoveryLoadTill;
    $hFilterState{all} = $iFilterAllNagiosTill;
    $hFilterState{regex} = \%rFilterRegex;

    return freeze(%hFilterState);
}


sub thawState($) {
    my %hFilterState;

    eval { %hFilterState = thaw(shift); };
    return infoLog("Unable to parse filter state data - ignoring") if ($@);

    $iFilterRecoveryLoadTill = $hFilterState{recovery};
    $iFilterAllNagiosTill = $hFilterState{all};
    %rFilterRegex = %{$hFilterState{regex}};
    debugLog(D_state, "restored filter state data (regexes: " . keys(%rFilterRegex) . ")");
}



sub blockedByFilter($) {
    my $sMessage = shift; 
    my $iNow = time();

    # check the recovery or system load filter
    if (($iFilterRecoveryLoadTill > $iNow) &&
        ($sMessage =~ /(^[-+!]{0,1}RECOVERY)|(System Load)/)) { 
        infoLog("message matched Recovery or Load filter");
        return 1;
    }

    # check the all nagios filter
    if (($iFilterAllNagiosTill > $iNow) &&
        ($sMessage =~ /^[-+!]{0,1}(PROBLEM|RECOVERY)/)) { 
        infoLog("message matched All Nagios filter");
        return 1;
    }

    # check all regex filters
    foreach my $iRegexFilterID (keys %rFilterRegex) {
        if (($rFilterRegex{$iRegexFilterID}->{till} >= $iNow) &&
            ($sMessage =~ /$rFilterRegex{$iRegexFilterID}->{regex}/i)) {
            infoLog("message matched Regex filter (" . $rFilterRegex{$iRegexFilterID}->{regex} . ")");
            return 1;
        }

        rmRegexFilter($rFilterRegex{$iRegexFilterID}->{regex}) if ($rFilterRegex{$iRegexFilterID}->{till} < $iNow); 
    }

    # nothing matched
    return 0;
}



sub setRecoveryLoadFilterTill($) {
    my $iTill = shift;
    $iFilterRecoveryLoadTill = $iTill;
}



sub setAllNagiosFilterTill($) {
    my $iTill = shift;
    $iFilterAllNagiosTill = $iTill;
}



sub getAllNagiosFilterTill() { return $iFilterAllNagiosTill; }

sub getRecoveryLoadFilterTill() { return $iFilterRecoveryLoadTill; }



sub newRegexFilter($$) {
    my ($sRegex, $iTill) = @_;
    my $iLastID = 1;
    
    # if the regex matches an existing one, we'll use the same ID and update that one's expiration
    # time.  otherwise we find the next available ID
    foreach my $iRegexFilterID (sort keys %rFilterRegex) {
        $iLastID = $iRegexFilterID;
        last if ($sRegex eq $rFilterRegex{$iRegexFilterID}->{regex});
        $iLastID++;
    }

    debugLog(D_filters, (defined $rFilterRegex{$iLastID} ? 'updated' : 'added') . " RegexFilter $sRegex (id $iLastID)");
    $rFilterRegex{$iLastID} = { regex => $sRegex, till => $iTill }; 
}



sub rmRegexFilter($) {
    my $sRegex = shift;

    foreach my $iRegexFilterID (keys %rFilterRegex) {
        if ($rFilterRegex{$iRegexFilterID}->{regex} eq $sRegex) {
            debugLog(D_filters, "removed " . $rFilterRegex{$iRegexFilterID}->{regex} . " (id $iRegexFilterID)");
            delete $rFilterRegex{$iRegexFilterID};
            return 1;
        }
    }

    return 0;
}


1;
