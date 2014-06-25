package DSPS_Room;

use DSPS_String;
use DSPS_User;
use DSPS_Debug;
use DSPS_Util;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = ('%g_hRooms');

our %g_hRooms;


sub humanSort {
    my $bA = ($a =~ /^\!/);
    my $bB = ($b =~ /^\!/);

    return 1 if ($bA && !$bB);
    return -1 if ($bB && !$bA);
    return($a cmp $b);
}



sub createRoom {
    my $iEmptyRoom = 0;
    while (defined $g_hRooms{++$iEmptyRoom}) { 1; }

    $g_hRooms{$iEmptyRoom} = {
        occupants_by_phone => {},
        saved_occupants_by_phone => {},
        most_occupants_by_phone => {},
        expiration_time => time() + ROOM_LENGTH,
        escalation_time => 0,
        escalation_to => '',
        escalation_orig_sender => '',
        escalation_name => '',
        ticket_number => 0,
        broadcast_speaker => 0,
        history => [],
        maintenance => 0,
        ack_mode => 0,
        last_problem_time => 0,
        last_human_reply_time => 0,
        creation_time => time(),
        last_nonhuman_message => '',
        summary => '',
        sum_reminder_sent => '',
    };

    debugLog(D_rooms, "created room #$iEmptyRoom with expiration of " . $g_hRooms{$iEmptyRoom}->{expiration_time});
    return $iEmptyRoom;
}



sub destroyRoom($) {
    my $iRoomNumber = shift;
    delete $g_hRooms{$iRoomNumber};
    debugLog(D_rooms, "cleaned up room #$iRoomNumber");
}


sub cloneRoomMinusOccupants($) {
    my $iOrigRoom = shift;
    my $iNewRoom = createRoom();

    $g_hRooms{$iNewRoom}->{most_occupants_by_phone} = $g_hRooms{$iOrigRoom}->{most_occupants_by_phone};
    $g_hRooms{$iNewRoom}->{escalation_orig_sender} = $g_hRooms{$iOrigRoom}->{escalation_orig_sender};
    $g_hRooms{$iNewRoom}->{ticket_number} = $g_hRooms{$iOrigRoom}->{ticket_number};
    $g_hRooms{$iNewRoom}->{history} = $g_hRooms{$iOrigRoom}->{history};
    $g_hRooms{$iNewRoom}->{maintenance} = $g_hRooms{$iOrigRoom}->{maintenance};
    $g_hRooms{$iNewRoom}->{ack_mode} = $g_hRooms{$iOrigRoom}->{ack_mode};
    $g_hRooms{$iNewRoom}->{last_problem_time} = $g_hRooms{$iOrigRoom}->{last_problem_time};
    $g_hRooms{$iNewRoom}->{last_human_reply_time} = $g_hRooms{$iOrigRoom}->{last_human_reply_time};
    $g_hRooms{$iNewRoom}->{creation_time} = $g_hRooms{$iOrigRoom}->{creation_time};
    $g_hRooms{$iNewRoom}->{last_nonhuman_message} = $g_hRooms{$iOrigRoom}->{last_nonhuman_message};
    $g_hRooms{$iNewRoom}->{summary} = $g_hRooms{$iOrigRoom}->{summary};
    $g_hRooms{$iNewRoom}->{sum_reminder_sent} = $g_hRooms{$iOrigRoom}->{sum_reminder_sent};

    debugLog(D_rooms, "room $iOrigRoom cloned to $iNewRoom");
    return $iNewRoom;
}

sub checkpointOccupants($) {
    my $iRoom = shift;

    if ($iRoom && (defined $g_hRooms{$iRoom})) {
        my %SavedOccupants = defined($g_hRooms{$iRoom}->{occupants_by_phone}) ? %{$g_hRooms{$iRoom}->{occupants_by_phone}} : {};
        $g_hRooms{$iRoom}->{saved_occupants_by_phone} = \%SavedOccupants;
    }
}


sub diffOccupants($) {
    my $iRoom = shift;
    my %hPrevOccupants = defined($g_hRooms{$iRoom}->{saved_occupants_by_phone}) ? %{$g_hRooms{$iRoom}->{saved_occupants_by_phone}} : {};
    my @aResult;

    foreach my $iPhone (keys %{$g_hRooms{$iRoom}->{occupants_by_phone}}) {
        push(@aResult, $iPhone) unless defined ($hPrevOccupants{$iPhone});
    }

    debugLog(D_pageEngine, "diff is [" . join(', ', @aResult) . ']') if ($#aResult > -1);

    return @aResult;
}


sub combinePeoplesRooms($$) {
    my ($rTargetUser, $rDraggedUser) = @_;
    my $bRoomChanged = 0;

    my $iDestinationRoom = findUsersRoom($rTargetUser->{phone});    
    my $iSourceRoom = findUsersRoom($rDraggedUser->{phone});

    # is the sender already in a room or do we need to create one?
    $iDestinationRoom = createRoomWithUser($rTargetUser->{phone}) unless ($iDestinationRoom);

    # are the sender and the mentioned user the same person or already in the same room?
    unless (($iSourceRoom == $iDestinationRoom) || ($rTargetUser->{phone} == $rDraggedUser->{phone})) {
        $bRoomChanged = 1;
        
        if ($iSourceRoom) {
            # dragged user was in a different room
            # now we move over everyone that was in that (source) room
            foreach my $iUserInSourceRoom (keys %{$g_hRooms{$iSourceRoom}->{occupants_by_phone}}) {
                roomRemoveOccupant($iSourceRoom, $iUserInSourceRoom);
                roomEnsureOccupant($iDestinationRoom, $iUserInSourceRoom);
            }

            $g_hRooms{$iDestinationRoom}->{maintenance} = $g_hRooms{$iSourceRoom}->{maintenance} unless $g_hRooms{$iDestinationRoom}->{maintenance};
            $g_hRooms{$iDestinationRoom}->{broadcast_speaker} = $g_hRooms{$iSourceRoom}->{broadcast_speaker} unless $g_hRooms{$iDestinationRoom}->{broadcast_speaker};
            $g_hRooms{$iDestinationRoom}->{ticket_number} = $g_hRooms{$iSourceRoom}->{ticket_number} unless $g_hRooms{$iDestinationRoom}->{ticket_number};
            $g_hRooms{$iDestinationRoom}->{escalation_orig_sender} = $g_hRooms{$iSourceRoom}->{escalation_orig_sender} unless $g_hRooms{$iDestinationRoom}->{escalation_orig_sender};

            destroyRoom($iSourceRoom);
        }
        else {
            # add the dragged user to the room
            roomEnsureOccupant($iDestinationRoom, $rDraggedUser->{phone});
            debugLog(D_rooms, 'user ' . $rDraggedUser->{name} . " (" . $rDraggedUser->{phone} . ") added to room $iDestinationRoom");
        }

        return 1;
    }

    return $bRoomChanged; 
}


sub findUsersRoom($) {
    my $iUser = shift;

    foreach my $iRoom (keys %g_hRooms) {
        return $iRoom if (defined ${$g_hRooms{$iRoom}->{occupants_by_phone}}{$iUser});
    }

    return 0;
}



sub createRoomWithUser($) {
    my $iUser = shift;

    my $iRoom = createRoom();
    roomEnsureOccupant($iRoom, $iUser);
    debugLog(D_rooms, 'user ' . $g_hUsers{$iUser}->{name} . " ($iUser) added to room $iRoom on create");

    return $iRoom;
}



sub findOrCreateUsersRoom($) {
    my $iUser = shift;
    my $iRoom = findUsersRoom($iUser);

    $iRoom = createRoomWithUser($iUser) unless $iRoom;
    
    return $iRoom;
}



sub roomHumanCount($) {
    my $iRoom = shift;
    my $iOccupants = 0;

    if (defined $g_hRooms{$iRoom}) {
        foreach my $iPhone (keys %{$g_hRooms{$iRoom}->{occupants_by_phone}}) {
            $iOccupants++ if (DSPS_User::humanUsersPhone($iPhone));
        }
    }

    return $iOccupants;
}


sub roomStatus($;$$$) {
    my $iTargetRoom = shift;
    my $bNoGroupNames = shift || 0;
    my $bSquashSystemUsers = shift || 0;
    my $bUseMostOccupants = shift || 0;
    my $sFullResult = '';
    my %hFullHash = ();

    foreach my $iRoom (keys %g_hRooms) {
        next if ($iTargetRoom && ($iRoom != $iTargetRoom));  # target == 0 means all rooms

        # our room stores a list of all occupants
        my %hRoomOccupants = %{ ($bUseMostOccupants ? $g_hRooms{$iRoom}->{most_occupants_by_phone} : $g_hRooms{$iRoom}->{occupants_by_phone}) };
        
        # but the list of people can get pretty long if we try to print them all one by one
        # so lets substitute in group names if every person from a given group is in the room
        # $hGroupMembers is our temporary tracking hash
        unless ($bNoGroupNames) {
            foreach my $sGroup (DSPS_User::allGroups()) {
                my %hOrigRoomOccupants = %hRoomOccupants;
                my %hGroupMembers;
                $hGroupMembers{$_}++ for (DSPS_User::usersInGroup($sGroup));

                # remove each group member from the room if present
                foreach my $sPersonInGroup (keys %hGroupMembers) {
                    if (defined $hRoomOccupants{$sPersonInGroup}) {
                        delete $hRoomOccupants{$sPersonInGroup}; 
                        delete $hGroupMembers{$sPersonInGroup}; 
                    }
                }

                if (keys(%hGroupMembers)) {
                    # if anyone is left in our temp hash then not everyone from the group was in the
                    # room.  so we have to revert to our original copy and not remove anyone from this group
                    %hRoomOccupants = %hOrigRoomOccupants;
                }
                else {
                    # or we've removed all the members of this group because they were all there
                    # in which case let's replace them with the group name itself
                    $hRoomOccupants{$sGroup} = 1 if (DSPS_User::humanTest($sGroup) || 
                        (!$bSquashSystemUsers && main::getShowNonHuman()));  # human-based group actually
                }
            }
        }

        # convert phone numbers to names
        foreach my $iPhone (keys %hRoomOccupants) {
            if (defined $g_hUsers{$iPhone}) {
                delete $hRoomOccupants{$iPhone};
                $hRoomOccupants{$g_hUsers{$iPhone}->{name}} = 1 if (DSPS_User::humanUsersPhone($iPhone) || 
                    (!$bSquashSystemUsers && main::getShowNonHuman()));
            }
        }
            
        $sFullResult = cr($sFullResult) .  ($iTargetRoom ? '' : "Room $iRoom: ") . join(', ', sort humanSort keys(%hRoomOccupants));
        @hFullHash{keys %hRoomOccupants} = values %hRoomOccupants;
    }

    return (wantarray() ? sort(keys(%hFullHash)) : ($sFullResult ? $sFullResult : S_NoConversations));
}



sub roomEnsureOccupant {
	my ($iRoomNumber, $sUserPhone) = @_;

    $g_hRooms{$iRoomNumber}->{occupants_by_phone}{$sUserPhone} = 1;
    $g_hRooms{$iRoomNumber}->{most_occupants_by_phone}{$sUserPhone} = 1;
	debugLog(D_rooms, "adding user with phone $sUserPhone to room #$iRoomNumber");
}



sub roomRemoveOccupant {
	my ($iRoomNumber, $sUserPhone) = @_;

	delete $g_hRooms{$iRoomNumber}->{occupants_by_phone}{$sUserPhone};
	debugLog(D_rooms, "removing user with phone $sUserPhone from room #$iRoomNumber");
}



sub roomsHealthCheck {
    my $iNow = time();


    foreach my $iRoomNumber (keys %g_hRooms) {

        # room half-way to expired
        if (($g_hRooms{$iRoomNumber}->{expiration_time} <= $iNow + (ROOM_LENGTH / 2)) && 
            $g_hRooms{$iRoomNumber}->{last_nonhuman_message}) {   # it wasn't just a human-to-human chat

            # admin has summary reminders enabled, it's day-time,
            # summary hasn't been set and reminder hasn't been sent
            if (main::getSummaryReminder() && isDuringWakingHours() && 
                !$g_hRooms{$iRoomNumber}->{summary} && !$g_hRooms{$iRoomNumber}->{sum_reminder_sent}) {

                main::sendCustomSystemMessageToRoom((keys(%{$g_hRooms{$iRoomNumber}->{occupants_by_phone}}))[0], S_SummaryReminder, 0);
                $g_hRooms{$iRoomNumber}->{sum_reminder_sent} = 1;
            }

        }

        # room expired
        if ($g_hRooms{$iRoomNumber}->{expiration_time} <= $iNow) {
            infoLog("room $iRoomNumber expired with " . keys(%{$g_hRooms{$iRoomNumber}->{occupants_by_phone}}) . " occupants");
            logRoom($iRoomNumber);
            delete $g_hRooms{$iRoomNumber};
        }
    }
}



sub timeLength($) {
    my $iDiffSecs = shift;
    my $sResult = '';

    if ($iDiffSecs >= 3600) {
        my $iHours = int($iDiffSecs / 3600);
        $sResult = "$iHours hour" . ($iHours > 1 ? 's' : '');
        $iDiffSecs -= 3600 * $iHours;
    }

    if ($iDiffSecs >= 60) {
        my $iMinutes = int($iDiffSecs / 60);
        $sResult .= ($sResult ? ', ' : '') . "$iMinutes minute" . ($iMinutes > 1 ? 's' : '');
        $iDiffSecs -= 60 * $iMinutes;
    }

    # only show seconds if there are no hours or minutes
    if (!$sResult && $iDiffSecs) {
        $sResult = "$iDiffSecs second" . ($iDiffSecs > 1 ? 's' : '');
    }

    $sResult = '0 minutes' unless $sResult;

    return $sResult;
}



sub logRoom($) {
    my $iRoom = shift;
    my $sLogFile = main::getLogRoomsTo();

    if ((defined $g_hRooms{$iRoom}) && $sLogFile) {
        open(LOG, ">>$sLogFile") || return infoLog("Unable to write to $sLogFile");
        print LOG localtime($g_hRooms{$iRoom}->{creation_time}) . " for " . timeLength(time() - $g_hRooms{$iRoom}->{creation_time}) . "\t";
        print LOG roomStatus($iRoom, 0, 1, 1) . "\n";

        if ($g_hRooms{$iRoom}->{summary} && ($g_hRooms{$iRoom}->{summary} =~ /^(.*?)\s*;\s*(.*)$/)) {
            print LOG "\n\t* " . ${$g_hRooms{$iRoom}->{history}}[0] . "\n\n";
            print LOG "Description: $1\n";
            print LOG "Station Impact: $2\n";
        } else {
            foreach my $sHistory (@{$g_hRooms{$iRoom}->{history}}) {
                $sHistory =~ s/\n/; /g;
                print LOG $sHistory . "\n";
            }
        }

        print LOG "\n--------------------------------------------------------------------------------\n";

        close(LOG);
    }
}



1;

