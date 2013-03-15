package paging_contacts;

require(Exporter);
@ISA = qw(Exporter);
@EXPORT = qw(%hStaff %hAmbiguousNames $CFGsEmergencyGroup $CFGbReplyOnEscalationCancel $CFGbRequireAtForNames $CFGsEmergencyGroup
			$CFGsEmergencySMTPServer $CFGsEmergencySMTPFrom $CFGsEmergencySMTPTo $CFGsEmergencyRTLink $CFGsRTConnectionString 
			$CFGsRTTicketQueue $CFGsAdminEmail $CFGsVacationSMTPTo);


#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
#
#  CHANGES TO THIS FILE REQUIRE A SIGHUP TO THE DAEMON 
#
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

# This is the file that will contain all of your changes and customizations.
# There are a few configuration parameters here at the top where you set email
# addresses, SMTP servers, and RT integration settings.  Then the bulk of the
# file is defining your Staff.  Staff are defined in groups or teams.  Some
# quick notes:
#
# 1.  A person can only belong to a single group/team.
# 2.  A person needs to have a cell number defined.
# 3.  A person can be paged by name, group or an alias.
# 4.  Aliases can reference other aliases, groups and/or people.

# If FALSE, any name (person or group) mentioned in a message (delimited by word boundaries /\b/) will
# be added to the audience of the conversation: "hey rick what's up?"
# If TRUE people or groups need to be prefixed by an 'at' symbol to be recognized: "hey @rick"
our $CFGbRequireAtForNames = 0;

# used for debugging - can only be a single email address
our $CFGsAdminEmail = 'myEmail@myCompany.com';

our $CFGsEmergencyGroup = 'StationRelations';
our $CFGsEmergencySMTPServer = 'localhost';
our $CFGsEmergencySMTPFrom = 'noreply@myCompany.com';
our $CFGsEmergencySMTPTo = 'dev@myCompany.com, stationrelations@myCompany.com';
our $CFGsEmergencyRTLink = 'http://rt.myCompany.com/Ticket/Display.html?id=';
our $CFGsVacationSMTPTo = 'myEmail@myCompany.com, bigboss@myCompany.com';
our $CFGsRTConnectionString = '/usr/bin/ssh automation\@rt.myCompany.com /usr/bin/rt';
our $CFGsRTTicketQueue = 'Emergency-Tickets';

# if you use signalhq.com for sending texts, this is where you specify your account info
our $CFGsSignalA = '999999';
our $CFGsSignalCampaign = '99999';

# if signalhq isn't able to send the page, where should we email instead?  ideally this
# will end up being a text as well, like xxxxxxxx@txt.att.net (where xxx is your cell number)
# sending an email to this address should turn it into a text, but it may become the victim
# of the cell company's spam filter.  most often this will be the cell number of your main
# admin to notify them that signalhq.com messages aren't getting through
our $CFGsFallbackEmail = '5555551234@txt.att.net';


our %hStaff = (

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

	'911' => { 'alias' => 'ops, dev' },

	'all_staff' => { 
			'alias' => '911, stationrelations',
			'hidden' => 1,
	},

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

# in reality obviously everyone should have unique phone numbers

	'Ops' => {

			'members' => {
				'Rick|jones'			=> '5555551234',
				'DavidSmith|dsmith'		=> '5555551234',
				'Sean|stephens'			=> '5555551234',
				'Joe|holmes'			=> '5555551234',
			},

			'escalation' => {
				'tag' => 'opscall',
				'timer' => 119,
				'on_expire_to' => 'ops'
			},

			'schedule' => {
				'20120116'  => 'rick',
				'20120123'  => 'dsmith',
        		'20130130'  => 'auto/sean,dsmith,rick',
			},
	},

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

	'Dev' => {

			'members' => {
				'John'				=> '5555551234',
    			'DavidHenly|henly'			=> '5555551234',
				'Moore'		        => '5555551234',
    			'Charles|robinson'  => '5555551234',
			}
	},

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

	'StationRelations' => {

			'members' => {
    			'Rakiesha'			=> '5555551234',
    			'Janeen|smiley'		=> '5555551234',
    			'Sara|hopey'		=> '5555551234',
    			'Sabrina|miller'	=> '5555551234',
			},

			'escalation' => {
				'tag' => 'cscall',
				'timer' => 299,
				'on_expire_to' => 'ops',
				'cancel_msg' => "[Escalation canceled.  You're on your own.  Good luck!]",
			},

			'schedule' => {
        		'20121018'  => 'Sabrina',
        		'20121024'  => 'Janeen',
        		'20121031'  => 'Rakiesha',
        		'20121107'  => 'Sara',
        		'20121114'  => 'Sabrina',
        		'20121121'  => 'Janeen',
        		'20121128'  => 'Rakiesha',
        		'20121205'  => 'Sara',
        		'20121212'  => 'Janeen',
        		'20121219'  => 'Sabrina',
        		'20130102'  => 'Sara',
        		'20130109'  => 'auto',
			}
	},
);

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

our %hAmbiguousNames = (
	'Dave|David'			=> 'DavidSmith or DavidHenly',
);


1;
