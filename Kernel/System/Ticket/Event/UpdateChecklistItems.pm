# --
# Copyright (C) 2017 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::UpdateChecklistItems;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Log
    Kernel::System::Ticket
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

    my $LogObject        = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject     = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ChecklistObject  = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

    my $FeatureActive = $ConfigObject->Get('TicketChecklist::AllowTicketsAsItems');

    return 1 if !$FeatureActive;

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

    my $TicketID = $Param{Data}->{TicketID};

    my @Items = $ChecklistObject->ItemListForForeignTicketID(
        ID => $TicketID,
    );

    return 1 if !@Items;

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $TicketID,
        UserID   => $Param{UserID},
    );

    my %NewValues;
    if ( $Param{Event} eq 'TicketTitleUpdate' ) {
        $NewValues{Comment} = $Ticket{Title};
    }
    elsif ( $Param{Event} eq 'TicketStateUpdate' ) {
        my $Mapping = $ConfigObject->Get('TicketChecklist::TicketStateToItemState') || {};
        my $Value   = $Mapping->{ $Ticket{State} };

        if ( $Value ) {
            $NewValues{Status} = $Value;
        }
    }

    for my $ItemID ( @Items ) {
        my %Checklist = $ChecklistObject->TicketChecklistGet( ID => $ItemID );

        $ChecklistObject->TicketChecklistUpdate(
            %Checklist,
            %NewValues,
            UserID => $Param{UserID},
        );
    }

    return 1;
}

1;

