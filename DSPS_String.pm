package DSPS_String;

use DSPS_Debug;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = ('t', 'sv', 'cr', 'S_NoPermission', 'S_NoConversations', 'S_AudienceUpdate', 'S_YoureAlone', 'S_NotInRoom', 'S_NowInMaint',
                'S_UnknownCommand', 'S_NeedTime', 'S_RecoveryAlreadyF', 'S_RecoveryAlreadyU', 'S_RecoveryFiltered', 'S_RecoveryEnabled', 'S_NoReBroadcast',
                'S_NothingToSwap', 'S_NoRecipSwap1', 'S_SwapSyntax', 'S_NoSwapMatches1', 'S_MultipleMatches3', 'S_UnsharedSchedule2', 'S_ScheduleSwap1',
                'C_PIDPath', 'C_StatePath', 'S_AutoReplySyx', 'S_AutoReplySet1', 'S_AutoReplyRm', 'S_NoSuchEscalation1', 'S_NoEscalations', 'S_NoSuchEntity', 'S_NoSuchHelp',
                'S_SmartAlreadyF', 'S_SmartFiltered', 'E_SwapSuccess4', 'S_EmailSent1', 'S_NeedEmail', 'E_VacationSet2', 'E_VacationCancel1', 'E_VacationElapsed1',
                'E_EscalationFire1', 'S_VacaNeedTime', 'S_NoVacations', 'S_AmbiguousIgnored1', 'S_AmbiguousReject2', '@A_HelpTopics');

use constant S_NoPermission     => "You don't have permission for this command.";
use constant S_NoReBroadcast    => "This room is already in broadcast mode from another sender & you don't have permission to override.  Your message was sent only to the original broadcaster.";
use constant S_NoConversations  => 'There are currently no rooms or conversations.';
use constant S_AudienceUpdate   => 'Audience is now';
use constant S_YoureAlone       => "There's no one in this conversation other than you.  Mention a name or group to specify a recipient.";
use constant S_NotInRoom        => "You're not currently in a conversation/room.";
use constant S_NowInMaint       => 'designated this a maintenance window room.  Escalations will not fire for the duration of the room.';
use constant S_UnknownCommand   => 'Unrecognized command.';
use constant S_NeedTime         => "requires a time specification (e.g. 3h).  Units can be 'm'inutes, 'h'ours, 'd'ays, or 'w'eeks.";
use constant S_RecoveryAlreadyF => "You already have recoveries filtered (blocked).  Use ':recovery' to re-enable them.";
use constant S_RecoveryAlreadyU => "You already have recoveries enabled.  Use ':norecovery' to filter them.";
use constant S_RecoveryFiltered => "Recovery pages are now filtered (blocked) for you.";
use constant S_SmartAlreadyF    => "You already have smart recoveries enabled.  Use ':recovery' to disable them.";
use constant S_SmartFiltered    => "Smart sleep recoveries are now enabled for you.";
use constant S_RecoveryEnabled  => "Recovery pages are now restored for you.";
use constant S_NothingToSwap    => "You aren't part of any oncall rotation schedule.  You have no schedule entry to swap.";
use constant S_NoRecipSwap1     => "%% isn't part of any oncall rotation schedule and therefore has nothing to swap.";
use constant S_SwapSyntax       => "You need to specify with whom to swap oncall schedules.  e.g. ':swap PERSON'.";
use constant S_NoSwapMatches1   => "You and %% don't share any oncall rotation schedules.  You can't swap into a different group.";
use constant S_MultipleMatches3 => "You and %% share multiple schedules.  Specify which, e.g. ':swap %% SCHEDULE' where SCHEDULE is one of %%.";
use constant S_UnsharedSchedule2=> "You and %% don't share a schedule on %%.";
use constant S_ScheduleSwap1    => "You've successfully swapped your next oncall week with %%.";
use constant S_AutoReplySet1    => "You have successfully set your auto reply for the next %%.";
use constant S_AutoReplySyx     => "You currently have no auto reply configured.  To set an auto reply use ':autoreply TIME MESSAGE'";
use constant S_AutoReplyRm      => "Your auto reply has been removed.";
use constant S_NoSuchEscalation1=> "There is no escalation named %%.";
use constant S_NoEscalations    => "There are no escalations currently configured";
use constant S_NoSuchEntity     => "There's no group, alias, escalation or user by that name.";
use constant S_EmailSent1       => "The room's history has been emailed to %%.";
use constant S_NeedEmail        => "You need to specify a recipient's email address.  e.g. ':email ADDRESS'";
use constant S_VacaNeedTime     => "The vacation command needs a time specified.  e.g. ':vacation 3d'";
use constant S_NoVacations      => "No one has currently configured vacation time.";
use constant S_AmbiguousIgnored1=> "Ambiguous name reference '%%' ignored;  message was sent as is.";
use constant S_AmbiguousReject2 => "%% is ambiguous.  Try %%.";
use constant S_NoSuchHelp       => 'There are no help topics that match your search.';


use constant E_SwapSuccess4     => "Subject: Oncall schedule change\n\n" .
                                   "%% has swapped weeks with %%.\n\n" .
                                   "The new schedule for %% is as follows:\n\n%%";
use constant E_VacationSet2     => "Subject: DSPS vacation time update\n\n" .
                                   "%% has set %% of vacation time and will be removed from all groups and escalations.  You can still contact this person directly by name.\n\n" .
                                   "The '?vacation' paging command can be used to see everyone that currently has vacation days configured.\n"; 
use constant E_VacationCancel1  => "Subject: DSPS vacation time update\n\n" .
                                   "%% has canceled their remaining vacation time and is now restored to all groups and escalations.\n\n" .
                                   "The '?vacation' paging command can be used to see everyone that currently has vacation days configured.\n"; 
use constant E_VacationElapsed1 => "Subject: DSPS vacation time update\n\n" .
                                   "%%'s vacation time has elapsed and is now restored to all groups and escalations.\n\n" .
                                   "The '?vacation' paging command can be used to see everyone that currently has vacation days configured.\n"; 
use constant E_EscalationFire1  => "Subject: DSPS Escalation!\n\n".
                                    "[%% escalation]\n\n%%";

use constant C_PIDPath => '/tmp/.dsps.pid';
use constant C_StatePath => '/tmp/.dsps.state';


our @A_HelpTopics = (
    ":vacation T (set)\n" .
    "?vacation (query)",

    ":macro NAME DEFINITION (set)\n" .
    ":macro NAME (delete)\n" .
    "?macros (query)\n" .
    ":nomacros (delete all)",

    ":nonagios (block)\n" .
    ":nagios (unblock)\n" .
    ":noregex T RE (block)\n" .
    ":noregex 0 RE (unblock)\n" .
    ":sleep (load&recv 3h)\n" .
    ":nosleep\n" .
    ":maint (no escs)\n" .
    "?filters (query)",

    ":norecovery (block)\n" .
    ":smartrecovery (enable)\n" .
    ":recover (unblock)\n" .
    "?filters (query)",

    ":swap PERSON (swap on call)",

    ":autoreply T TEXT (set)\n" .
    ":noautoreply (delete)",

    ":email ADDRESS",

    ":ack (enable room acknowledgement mode)",

    "?oncall\n" .
    "?rooms\n" .
    "?groups\n" .
    "?GROUP\n" 
);


# substitute in variables
sub sv($;@) {
    my $sText = shift;

    while ($sText =~ /%%/) {
        my $sParam = shift || '';

        if ($sParam) {
            $sText =~ s/%%/$sParam/;
        }
        else {
            last;
        }
    }

    return $sText;
}


# theme system messages
sub t($;@) {
    my $sText = shift;

    return('[' . sv($sText, @_) . ']');
}



# continue a line
sub cr($) {
    my $sText = shift;
    return ($sText ? "$sText\n" : $sText);
}


1;
