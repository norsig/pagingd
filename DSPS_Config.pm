package DSPS_Config;

use Hash::Case::Preserve;
use DSPS_User;
use DSPS_Room;
use DSPS_Alias;
use DSPS_Escalation;
use DSPS_CmdPermission;
use DSPS_Debug;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = ('%g_hConfigOptions');

# set defaults
our %g_hConfigOptions = ('require_at' => 0);;
our $sConfigPath = '/usr/local/bin/dsps3';
my @aValueDirectives = ('default_maint', 'gateway_url', 'gateway_params', 'fallback_email', 'recovery_regex', 'dsps_server', 'smtp_server', 'server_listen', 'smtp_from', 'admin_email', 
                        'rt_connection', 'override_user', 'override_regex', 'rt_link');
my @aBoolDirectives = ('show_nonhuman', 'require_at');
my %hSeenAliases;


sub checkAliasRecursion($);
sub checkAliasRecursion($) {
    my $sAlias = shift;

    $hSeenAliases{$sAlias} = 1;
    tie my(%hCaselessAliases), 'Hash::Case::Preserve';
    %hCaselessAliases = %g_hAliases;

    while ($g_hAliases{$sAlias}->{referent} =~ m,(\w+),g) {
        my $sThisReferent = $1;

        if (defined $hCaselessAliases{$sThisReferent}) {
            return "$sThisReferent recursively used in $sAlias" if (defined $hSeenAliases{$sThisReferent});

            my $sError = checkAliasRecursion($sThisReferent);
            return $sError if $sError;
        }
    }

    return '';
}



sub configSyntaxValid() {
    my $bValid = 1;

    # per user checks
    foreach my $iPhone (keys %g_hUsers) {
        unless (length($iPhone) == 10) {
            print STDERR infoLog('user ' . $g_hUsers{$iPhone}->{name} . ' of ' . $g_hUsers{$iPhone}->{group} . "doesn't have a 10 digit phone number");
            $bValid = 0;
        }

        unless ($g_hUsers{$iPhone}->{name} =~ /$g_hUsers{$iPhone}->{regex}/i) {
            print STDERR infoLog('user ' . $g_hUsers{$iPhone}->{name} . "'s \"name\" isn't contained in their \"regex\"; this is an internal DSPS requirement");
            $bValid = 0;
        }
    }

    # per escalation checks
    foreach my $sEscName (keys %g_hEscalations) {
       if ($g_hEscalations{$sEscName}->{timer} && !$g_hEscalations{$sEscName}->{escalate_to}) {
           print STDERR infoLog("escalation $sEscName has a timer defined but no escalate_to");
           $bValid = 0;
       }

       if (!$g_hEscalations{$sEscName}->{timer} && $g_hEscalations{$sEscName}->{escalate_to}) {
           print STDERR infoLog("escalation $sEscName has an escalate_to defined but no timer");
           $bValid = 0;
       }
    }

    # per alias check
    foreach my $sAlias (keys %g_hAliases) {

        %hSeenAliases = ();
        my $sError = checkAliasRecursion($sAlias);
        if ($sError) {
            print STDERR infoLog("Alias error: $sError");
            $bValid = 0;
        }
    }

    return $bValid;
}



sub readConfig(;$) {
    my $sConfigFileName = shift || "$sConfigPath/config.dsps";

    unless (open(CFG, $sConfigFileName)) {
        print infoLog("Unable to read $sConfigFileName");
        return 0;
    }

    my $sSection = '';
    my $sInfo = '';
    my $iErrors = 0;
    my $rStruct = 0;
    my $iLine = 0;

    LINE: while (<CFG>) {
        ++$iLine;
        my $sLineNum = "[$sConfigFileName line $iLine]";

        chomp();
        s/^\s*(.*)\s*/$1/;

        # ignore blank lines & comments
        next if /^\s*$/;
        next if /^\s*#/;
        s/\s*#.*$//;

        # group tag
        if (/\bgroup\s*:\s*(\S*)/i) {
            $sInfo = $1;
            $sSection = 'group';

            unless ($sInfo) {
                print infoLog("configuration error - 'group:' must be followed by a name $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # group: user line
        if (/\b(?:u|user)\s*:\s*(.*)/i) {
            my $sLine = $1;
            my $sGroup = $sInfo;

            if ($sSection eq 'group') {
                my @aData = split(/\s*,\s*/, $sLine);

                if (defined $g_hUsers{$aData[2]}) {
                    print infoLog("configuration error - user with phone number " . $aData[2] . " defined twice (" .
                        $g_hUsers{$aData[2]}->{name} . ' & ' . $aData[0] . ") $sLineNum");
                    ++$iErrors;
                    next;
                }

                my $rUser = DSPS_User::createUser($aData[0], $aData[1], $aData[2], $sGroup, $aData[3]);

                # user options
                if (defined $aData[4]) {
                    if ($aData[4] =~ /i(?:nclude)*\s*:\s*(.*)/i) {
                        $rUser->{auto_include} = $1;
                    }
                }
            }
            else {
                print infoLog("configuration error - user not part of valid group: $sLine $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # alias tag
        if (/\balias\s*:\s*(\S*)/i) {
            $sInfo = $1;
            $sSection = 'alias';

            if ($sInfo) {
                $rStruct = DSPS_Alias::createAlias($sInfo);
            }
            else {
                print infoLog("configuration error - 'alias:' must be followed by a name $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # alias referent
        if (/\b(?:r|referent)\s*:\s*(.+)/i) {
            my $iValue = $1;

            if ($sSection eq 'alias') {
                $rStruct->{referent} = $iValue;
            }
            else {
                print infoLog("configuration error - referent not part of a valid alias: r:$iValue $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # options
        if (/\b(?:o|option[s]*)\s*:\s*(.+)/i) {
            my $iValue = $1;

            if ($sSection eq 'alias') {
                while ($iValue =~ m,(\w+),g) {
                    my $sAnOption = $1;
                    if ($sAnOption =~ /hidden/i) {
                        $rStruct->{hidden} = 1;
                    }
                    else {
                        print infoLog("configuration error - unrecognized alias option: o:$sAnOption $sLineNum");
                        ++$iErrors;
                    }
                }
            }
            elsif ($sSection eq 'escalation') {
                if ($iValue =~ /rt_queue\s*[:=]*\s*(.*)/i) {
                    $rStruct->{rt_queue} = $1;
                }
                elsif ($iValue =~ /rt_subject\s*[:=]*\s*(.*)/i) {
                    $rStruct->{rt_subject} = $1;
                }
                else {
                    print infoLog("configuration error - unrecognized escalation option: o:$iValue $sLineNum");
                    ++$iErrors;
                }
            }
            else {
                print infoLog("configuration error - options not part of a valid alias or escalation: o:$iValue $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # swap email
        if (/\b(?:se|swap_email)\s*:\s*(.+)/i) {
            my $sValue = $1;

            if ($sSection eq 'escalation') {
                $rStruct->{swap_email} = $sValue;
            }
            else {
                print infoLog("configuration error - swap email outside of escalation: se:$sValue $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # cancel message
        if (/\b(?:cm|cancel_message|cancel_msg)\s*:\s*(.+)/i) {
            my $sValue = $1;

            if ($sSection eq 'escalation') {
                $rStruct->{cancel_msg} = $sValue;
            }
            else {
                print infoLog("configuration error - cancel message outside of escalation: cancel_msg:$sValue $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # alert email
        if (/\b(?:ae|alert_email)\s*:\s*(.+)/i) {
            my $sValue = $1;

            if ($sSection eq 'escalation') {
                $rStruct->{alert_email} = $sValue;
            }
            else {
                print infoLog("configuration error - alert email outside of escalation: ae:$sValue $sLineNum");
                ++$iErrors;
            }
            next;
        }


        # escalation tag
        if (/\bescalation\s*:\s*(\S*)/i) {
            $sInfo = $1;
            $sSection = 'escalation';

            if ($sInfo) {
                $rStruct = DSPS_Escalation::createEscalation($sInfo);
            }
            else {
                print infoLog("configuration error - 'escalation:' must be followed by a name $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # escalation: t: line
        if (/\b(?:t|timer)\s*:\s*(\d+)/i) {
            my $iValue = $1;

            if ($sSection eq 'escalation') {
                $rStruct->{timer} = $iValue;
            }
            else {
                print infoLog("configuration error - timer not part of a valid escalation: t:$iValue $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # escalation: e: line
        if (/\b(?:e|escalate_to)\s*:\s*(.+)/i) {
            my $iValue = $1;

            if ($sSection eq 'escalation') {
                $rStruct->{escalate_to} = $iValue;
            }
            else {
                print infoLog("configuration error - escalate_to not part of a valid escalation: e:$iValue $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # escalation: s: line
        if (/\b(?:s|sched|schedule)\s*:\s*(\d{8})\W+(.+)$/i) {
            my $sDate = $1;
            my $sSched = $2;
            my $iStartingErrorCount = $iErrors;

            if ($sSection eq 'escalation') {

                if ($sSched =~ /^auto\b(?:\W*)(.*)/i) {
                    my $sPeople = $1;

                    while ($sPeople =~ m,(\w+),g) {
                        my $sPerson = $1;
                        unless (DSPS_User::matchUserByRegex($sPerson)) {
                            print infoLog("configuration error - " . $rStruct->{name} . " schedule $sDate references undefined person $sPerson $sLineNum");
                            ++$iErrors;
                        }
                    }
                }
                elsif ($sSched =~ /^\s*(\w+)\s*$/) {
                    my $sPerson = $1;
                   
                    unless (DSPS_User::matchUserByRegex($sPerson)) {
                        print infoLog("configuration error - " . $rStruct->{name} . " schedule $sDate references undefined person $sPerson $sLineNum");
                        ++$iErrors;
                    }
                }
                else {
                    print infoLog("configuration error - " . $rStruct->{name} . " schedule $sDate should list a single person's name (unless using 'auto') $sLineNum");
                    ++$iErrors;
                }

                if ($iStartingErrorCount == $iErrors) {
                    my %hSchedule = %{$rStruct->{schedule}}; 
                    $hSchedule{$sDate} = $sSched;
                    $rStruct->{schedule} = \%hSchedule;
                    debugLog(D_config, "adding " . $rStruct->{name} . " $sDate schedule as $sSched (now " . keys(%hSchedule) . " entries) $sLineNum");
                }
            }
            else {
                print infoLog("configuration error - schedule not part of a valid escalation: s: $sDate $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # command permission line
        if (/\b(?:cmd|command)\s*:\s*([?:]\w+)\D+(\d+)/i) {
            my $sCmd = $1;
            my $iValue = $2;

            if (defined $DSPS_CmdPermission::hDefaultCmdPermission{$sCmd}) {
                $DSPS_CmdPermission::hCmdPermission{$1} = $2;
            }
            else {
                print infoLog("configuration error - '$sCmd' isn't a valid command $sLineNum");
                ++$iErrors;
            }
            next;
        }

        # ambiguous names lines
        if (/\b(?:amb|ambiguous)\s*:\s*([-|\w]+)[,;:\s]+(.+)/i) {
            $DSPS_User::g_hAmbigNames{$1} = $2;
            next;
        }

        # general configuration x: line
        if (/\b(?:sys|system)\s*:\s*([^:]+)\s*:\s*(.+)/i) {
            my $sOption = $1;
            my $sValue = $2;

            foreach my $sDirective (@aValueDirectives) {
                if ($sOption =~ /$sDirective/i) {
                    $g_hConfigOptions{$sDirective} = $sValue;
                    next LINE;
                }
            }

            foreach my $sDirective (@aBoolDirectives) {
                if ($sOption =~ /$sDirective/i) {
                    $g_hConfigOptions{$sDirective} = ($sValue =~ /yes|true|1|enable|on/i ? 1: 0);;
                    next LINE;
                }
            }
        }

        print infoLog("configuration error - unknown directive: $_ $sLineNum");
        ++$iErrors;
    }

    close(CFG);
    return(!$iErrors);
}



sub writeConfig() {
   my $sConfigFileName = shift || "$sConfigPath/config.dsps";
    open(CFG, $sConfigFileName) || return 0;
    open(NEW, ">$sConfigFileName.new") || return infoLog("Unable to write new config file ($sConfigFileName.new)");

    my $sSection = '';
    my $sInfo = '';
    my $bFoundSchedule = 0;
    my $sIndent = '';

    while (<CFG>) {
        chomp();
        my $sOrigLine = $_;

        # s/^\s*(.*)\s*/$1/;
        s/\s*#.*$//;

        if (/^(\s*)[teso]\s*:/i) {
            $sIndent = $1;
        }
        else {
            $sSection = '' if /:/;
        }

        if (/^\s*escalation\s*:\s*(\S+)/i) {
            $sSection = 'escalation';
            $sInfo = $1;
            $bFoundSchedule = 0;
        }

        if (($sSection eq 'escalation') && /^\s*s\s*:/i && defined($g_hEscalations{$sInfo})) {

            unless ($bFoundSchedule) {
                debugLog(D_config, "rewriting schedule for escalation $sInfo");
                my %hSchedule = %{$g_hEscalations{$sInfo}->{schedule}};
                foreach my $sDate (sort keys %hSchedule) {
                    print NEW "${sIndent}s:$sDate " . $hSchedule{$sDate} . "\n";
                }
            }

            $bFoundSchedule = 1;
            next;
        }

        print NEW "$sOrigLine\n";
    }

    close(CFG);
    close(NEW);

    debugLog(D_config, "saved new configuration file $sConfigFileName");
}

1;
