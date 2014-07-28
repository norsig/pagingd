package DSPS_SystemFilter;

use FreezeThaw qw(freeze thaw);
use DSPS_User;
use DSPS_Room;
use DSPS_Config;
use DSPS_String;
use DSPS_Debug;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = ('getAllNagiosFilterTill', 'setAllNagiosFilterTill');

our $iFilterRecoveryLoadTill = 0;
our $iFilterAllNagiosTill    = 0;
our %rFilterRegex;



sub freezeState() {
    my %hFilterState;

    $hFilterState{recovery} = $iFilterRecoveryLoadTill;
    $hFilterState{all}      = $iFilterAllNagiosTill;
    $hFilterState{regex}    = \%rFilterRegex;

    return freeze(%hFilterState);
}



sub thawState($) {
    my %hFilterState;

    eval {%hFilterState = thaw(shift);};
    return infoLog("Unable to parse filter state data - ignoring") if ($@);

    $iFilterRecoveryLoadTill = $hFilterState{recovery};
    $iFilterAllNagiosTill    = $hFilterState{all};
    %rFilterRegex            = %{ $hFilterState{regex} };
    debugLog(D_state, "restored filter state data (regexes: " . keys(%rFilterRegex) . ")");
}



sub blockedByFilter($$) {
    my $sMessage = shift;
    my $iRoom    = shift;
    my $iNow     = time();

    # check the recovery or system load filter
    if (   ($iFilterRecoveryLoadTill > $iNow)
        && ($sMessage =~ /(^[-+!]{0,1}RECOVERY)|(System Load)/))
    {
        debugLog(D_filters, "message matched Recovery or Load filter");
        return "recovery/load";
    }

    # check the all nagios filter
    if (   ($iFilterAllNagiosTill > $iNow)
        && (($sMessage =~ /$g_hConfigOptions{nagios_problem_regex}/) || ($sMessage =~ /$g_hConfigOptions{nagios_recovery_regex}/)))
    {
        debugLog(D_filters, "message matched All Nagios filter");
        return "allNagios";
    }

    # check all regex filters
    foreach my $iRegexFilterID (keys %rFilterRegex) {
        my $sThisRegex = $rFilterRegex{$iRegexFilterID}->{regex};
        $sThisRegex =~ s/(\\s| )/(\\s|)/g;
        if (   ($rFilterRegex{$iRegexFilterID}->{till} >= $iNow)
            && ($sMessage =~ /$sThisRegex/i))
        {
            debugLog(D_filters, "message matched Regex filter (" . $rFilterRegex{$iRegexFilterID}->{regex} . ")");
            return "regex";
        }

        rmRegexFilter($rFilterRegex{$iRegexFilterID}->{regex}) if ($rFilterRegex{$iRegexFilterID}->{till} < $iNow);
    }

    # check for a previously seen message in a room with ack-mode enabled
    if ($iRoom && $g_hRooms{$iRoom}->{ack_mode}) {
        my $sGenericMessage = $sMessage;
        $sGenericMessage =~ s/\bDate:\s.*$//s;
        $sGenericMessage =~ s/HTTP OK:.*\d+ by.*$//s;

        foreach my $sPrevMsg (@{ $g_hRooms{$iRoom}->{history} }) {
            if ($sPrevMsg =~ /$sGenericMessage/) {
                debugLog(D_filters, "message matched previous in room's history (ack-mode)");
                return "ackMode";
            }
        }
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

sub getAllNagiosFilterTill() {return $iFilterAllNagiosTill;}

sub getRecoveryLoadFilterTill() {return $iFilterRecoveryLoadTill;}



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

    debugLog(D_filters, (defined $rFilterRegex{$iLastID} ? 'updated' : 'added') . " RegexFilter /$sRegex/ (id $iLastID)");
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
