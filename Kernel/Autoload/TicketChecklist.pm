# --
# Kernel/Autoload/TicketChecklist.pm - wraps Kernel::System::Ticket::TicketDelete
# Copyright (C) 2017 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-26: moved from Ticket::CustomModule
# (Kernel::System::Ticket::Custom::TicketChecklist) to an autoload wrapper for OTOBO 11.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Autoload::TicketChecklist;    ## no critic (Modules::RequireFilenameMatchesPackage)

use strict;
use warnings;
use utf8;

# Load the original module first, or a later require of it would redefine
# TicketDelete again and silently drop the wrapper.
use Kernel::System::Ticket ();    ## no perlimports

our @ObjectDependencies = (
    'Kernel::System::PerlServices::TicketChecklist',
    'Kernel::System::PerlServices::TicketChecklistTicketInfo',
);

# Keep the original only once: under PSGI this file is re-required after a package
# upgrade, and a plain "my $Orig" would then wrap the wrapper.
our $OrigTicketDelete;
$OrigTicketDelete //= \&Kernel::System::Ticket::TicketDelete;

{
    no warnings 'redefine';    ## no critic (TestingAndDebugging::ProhibitNoWarnings)

    # The checklist tables reference ticket.id, so their rows have to go before
    # the ticket does. The TicketDelete event fires too late for that.
    *Kernel::System::Ticket::TicketDelete = sub {
        my ( $Self, %Param ) = @_;

        if ( $Param{UserID} && $Param{TicketID} ) {
            $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTicketInfo')->DeleteInfoForTicket(
                TicketID => $Param{TicketID},
            );

            $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist')->TicketChecklistDelete(
                TicketID => $Param{TicketID},
            );
        }

        return $OrigTicketDelete->( $Self, %Param );
    };
}

1;
