# --
# Kernel/System/Ticket/Event/MergeTicketChecklists.pm - merge time tracking entries when tickets are merged
# Copyright (C) 2013 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::MergeTicketChecklists;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::PerlServices::TicketChecklist
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

    # check needed stuff
    for my $Needed (qw(Data Event Config UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    for my $NeededData (qw(TicketID MainTicketID)) {
        if ( !$Param{Data}->{$NeededData} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $NeededData in Data!",
            );

            return;
        }
    }

    return if !$ChecklistObject->TicketChecklistMerge(
        OldTicketID => $Param{Data}->{TicketID},
        NewTicketID => $Param{Data}->{MainTicketID},
        UserID      => $Param{UserID},
    );

    return 1;
}

1;
