# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::CloseChecklistItems;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Log
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::State
    Kernel::System::Ticket
    Kernel::System::PerlServices::TicketChecklistStatus
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

    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LogObject            = $Kernel::OM->Get('Kernel::System::Log');
    my $ChecklistObject      = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $StateObject          = $Kernel::OM->Get('Kernel::System::State');
    my $TicketObject         = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ChecklistStateObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');

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

    for my $NeededData (qw(TicketID)) {
        if ( !$Param{Data}->{$NeededData} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $NeededData in Data!",
            );

            return;
        }
    }

    my %ViewableStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'HASH',
    );

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{Data}->{TicketID},
    );

    my $IsOpenState = grep{ $Ticket{StateType} eq $_ }values %ViewableStateIDs;

    return 1 if $IsOpenState;

    my $ClosedState = $ConfigObject->Get('TicketChecklist::ClosedState') || 'done';
    my @OpenStates  = @{ $ConfigObject->Get('TicketChecklist::OpenStates') || [] };

    my @ChecklistItems = $ChecklistObject->TicketChecklistTicketGet(
        TicketID => $Param{Data}->{TicketID},
    );

    return 1 if !@ChecklistItems;

    my $ClosedStateID = $ChecklistStateObject->TicketChecklistStatusLookup(
        Name => $ClosedState,
    );

    return 1 if !$ClosedStateID;

    ITEM:
    for my $Item ( @ChecklistItems ) {
        next ITEM if $Item->{Status} eq $ClosedState;

        # set new state
        $ChecklistObject->ChecklistItemStatusSet(
            ID          => $Item->{ID},
            StatusID    => $ClosedStateID,
            OldStatusID => $Item->{StatusID},
            OldStatus   => $Item->{Status},
            UserID      => $Param{UserID},

            NoConditionsActions => 1,
        );
    }

    return 1;
}

1;
