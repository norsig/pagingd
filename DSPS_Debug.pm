package DSPS_Debug;
use strict;
use warnings;
use Sys::Syslog qw(:standard :macros);

use base 'Exporter';
our @EXPORT = ('D_all', 'D_rooms', 'D_users', 'D_pageEngine', 'D_filters', 'D_escalations', 'D_permissions', 'D_config', 'D_state', 'D_rt', 'D_email',
                'debugLog', 'infoLog');

use constant D_rooms                      => 0x00000004;
use constant D_users                      => 0x00000008;
use constant D_pageEngine                 => 0x00000010;
use constant D_filters                    => 0x00000020;
use constant D_escalations                => 0x00000040;
use constant D_permissions                => 0x00000080;
use constant D_config                     => 0x00000100;
use constant D_state                      => 0x00000200;
use constant D_rt                         => 0x00000400;
use constant D_email                      => 0x00000800;

use constant D_                           => 0x00001000;
use constant D_interface                  => 0x00002000;
use constant D_lists                      => 0x00004000;
use constant D_load                       => 0x00008000;
use constant D_lookup                     => 0x00010000;
use constant D_memory                     => 0x00020000;
use constant D_pid                        => 0x00040000;
use constant D_process_info               => 0x00080000;
use constant D_queue_run                  => 0x00100000;
use constant D_receive                    => 0x00200000;
use constant D_resolver                   => 0x00400000;
use constant D_retry                      => 0x00800000;
use constant D_rewrite                    => 0x01000000;
use constant D_route                      => 0x02000000;
use constant D_timestamp                  => 0x04000000;
use constant D_tls                        => 0x08000000;
use constant D_transport                  => 0x10000000;
use constant D_uid                        => 0x20000000;
use constant D_verify                     => 0x40000000;
use constant D_all						  => 0xffffffff;


sub debugLog($$) {
	my $iTopic = shift;
	my $sMessage = shift;

	if ($main::g_iDebugTopics & $iTopic) {
        my @aCaller = caller(1);
		syslog(LOG_DEBUG, $aCaller[3] . " $sMessage");
	}
}


sub infoLog($) {
    my $sMessage = shift;
    syslog(LOG_INFO, "$sMessage");
    return $sMessage . "\n";
}

openlog('dsps3', 'pid', 'local0');

1;
