package DSPS_Util;

use strict;
use warnings;

use base 'Exporter';
our @EXPORT = ('ONEWEEK', 'parseUserTime', 'isDuringWakingHours', 'prettyDateTime', 'prettyPhone', 'caselessHashLookup');

use constant ONEWEEK => 604800;


sub isDuringWakingHours() {
    my ($iMinute, $iHour) = (localtime(time()))[1..2];
    return ($iHour > 7 && $iHour < 22);
}


sub prettyDateTime($) {
    my $sTime = shift || time();
    my ($iMon, $iD, $iY, $iH, $iMin) = (localtime($sTime))[4,3,5,2,1];
    return sprintf('%02d/%02d/%d@%02d:%02d', $iMon+1, $iD, $iY+1900, $iH, $iMin);
}


sub prettyPhone($) {
    my $sPhone = shift;
    
    if (length($sPhone) == 10) {
        substr($sPhone, 3, 0) = '-';
        substr($sPhone, 7, 0) = '-';
    }

    return $sPhone;
}



sub parseUserTime($;$) {
    my $sTimeInput = shift;
    my $sDefault = shift || '1h';

    $sTimeInput = $sDefault unless length($sTimeInput);

    if ($sTimeInput =~ /^\s*(\d+)([smhdw]{0,1})\s*$/i) {
        my $iOrigValue = $1;
        my $iSeconds = $1;
        my $sUnit = $2;
        my $sText = '';

        if ($sUnit eq 's') { $sText = 'second'; }
        if ($sUnit eq 'm') { $iSeconds *= 60; $sText = 'minute'; }
        if ($sUnit eq 'w') { $iSeconds *= ONEWEEK; $sText = 'week'; }
        if (($sUnit eq 'h') || ($sUnit eq '')) { $iSeconds *= 3600; $sText = 'hour'; }
        if ($sUnit eq 'd') {
            $iSeconds *= 86400;
            $sText = 'day';

            # days to weeks
            if (($iOrigValue > 6) && ($iOrigValue % 7 == 0)) {
                $iOrigValue /= 7;
                $sText = 'week';
                $iSeconds = ($iOrigValue * ONEWEEK);
            }
        }

        return (0) unless $sText;
        return ($iSeconds, "$iOrigValue $sText" . ($iOrigValue > 1 ? 's' : ''));
    }

    return 0;
}



sub caselessHashLookup($%) {
    my $sGivenKey = shift;
    my %hGiven = @_;
    $sGivenKey = lc($sGivenKey);

    my %hCaseless = map { lc($_) => $_ } keys %hGiven;
    return $hCaseless{$sGivenKey} if (defined $hCaseless{$sGivenKey});
    return '';
}

1;
