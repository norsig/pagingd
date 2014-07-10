package DSPS_Util;

use strict;
use warnings;
use DSPS_Debug;
use DSPS_String;
use Date::Calc qw(:all);

use base 'Exporter';
our @EXPORT = ('ONEWEEK', 'ROOM_LENGTH', 'parseUserTime', 'parseDateTime', 'isDuringWakingHours', 'prettyDateTime', 'prettyPhone', 'caselessHashLookup', 'parseRegex', 'dequote');

use constant ONEWEEK     => 604800;
use constant ROOM_LENGTH => 3600;



sub parseRegex($) {
    my $sRegex = shift;

    $sRegex =~ s,^\s*/(.*?)/\s*$,$1,;

    return $sRegex;
}



sub dequote($) {
    my $sString = shift;

    $sString =~ s/['"]*(.*?)['"]*/$1/;

    return $sString;
}



sub isDuringWakingHours() {
    my ($iMinute, $iHour) = (localtime(time()))[1 .. 2];
    return ($iHour > 6 && $iHour < 22);
}



sub prettyDateTime($) {
    my $sTime = shift || time();
    my ($iMon, $iD, $iY, $iH, $iMin) = (localtime($sTime))[4, 3, 5, 2, 1];
    return sprintf('%02d/%02d/%d@%02d:%02d', $iMon + 1, $iD, $iY + 1900, $iH, $iMin);
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
        my $iSeconds   = $1;
        my $sUnit      = $2;
        my $sText      = '';

        if ($sUnit eq 's') {$sText = 'second';}
        if ($sUnit eq 'm') {$iSeconds *= 60;      $sText = 'minute';}
        if ($sUnit eq 'w') {$iSeconds *= ONEWEEK; $sText = 'week';}
        if (($sUnit eq 'h') || ($sUnit eq '')) {$iSeconds *= 3600; $sText = 'hour';}
        if ($sUnit eq 'd') {
            $iSeconds *= 86400;
            $sText = 'day';

            # days to weeks
            if (($iOrigValue > 6) && ($iOrigValue % 7 == 0)) {
                $iOrigValue /= 7;
                $sText    = 'week';
                $iSeconds = ($iOrigValue * ONEWEEK);
            }
        }

        return (0) unless $sText;
        return ($iSeconds, "$iOrigValue $sText" . ($iOrigValue > 1 ? 's' : ''));
    }

    return 0;
}



sub parseDateTime($$$$$) {
    my ($iMonth, $iDay, $iYear, $iHour, $iMinute) = @_;
    if ($iYear < 1000) {$iYear += 2000;}

    my ($iNowSec, $iNowMin, $iNowHour, $iNowDay, $iNowMonth, $iNowYear, $iNowDoW, $iNowDoY, $iNowDST) = localtime(time());
    $iNowYear  += 1900;
    $iNowMonth += 1;

    my ($iDd, $iDh, $iDm, $iDs) = Delta_DHMS($iNowYear, $iNowMonth, $iNowDay, $iNowHour, $iNowMin, 0, $iYear, $iMonth, $iDay, $iHour, $iMinute, 0);
    my $iTotalSeconds = $iDd * 86400 + $iDh * 3600 + $iDm;

    my $sText = '';
    if ($iDd) {$sText = "$iDd day" . ($iDd > 1 ? 's' : '');}
    if    ($iDh) {$sText = cr($sText, ', ') . "$iDh hour" .   ($iDh > 1  ? 's' : '');}
    elsif ($iDm) {$sText = cr($sText, ', ') . "$iDm minute" . ($iDm > 1  ? 's' : '');}
    elsif ($iDs) {$sText = cr($sText, ', ') . "$iDs second" . ($iDs == 1 ? ''  : 's');}

    return ($iTotalSeconds, $sText);
}



sub caselessHashLookup($%) {
    my $sGivenKey = shift;
    my %hGiven    = @_;
    $sGivenKey = lc($sGivenKey);

    my %hCaseless = map {lc($_) => $_} keys %hGiven;
    return $hCaseless{$sGivenKey} if (defined $hCaseless{$sGivenKey});
    return '';
}

1;
