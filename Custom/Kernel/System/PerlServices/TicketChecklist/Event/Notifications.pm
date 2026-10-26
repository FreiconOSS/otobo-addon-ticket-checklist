# --
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Event::Notifications;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::PerlServices::TicketChecklistNotification
    Kernel::System::Ticket
    Kernel::System::Log
);

=head1 NAME

Kernel::System::PerlServices::Event::Notifications - TicketChecklist notification lib

=head1 SYNOPSIS

Event handler module for notifications for ticket checklist

=head1 PUBLIC INTERFACE

=over 4

=item new()

create an object

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $ChecklistObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $MainObject         = $Kernel::OM->Get('Kernel::System::Main');
    my $NotificationObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistNotification');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');

    # check needed stuff
    for my $Argument (qw(Data Event Config UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # do not modify the original event, because we need this unmodified in later event modules
    my $Event = $Param{Event};

    my %Item = $ChecklistObject->TicketChecklistGet(
        ID => $Param{Data}->{ItemID} // -1,
    );

    $Item{ResponsibleID}  //= '';
    $Item{ResponsibleKey} //= '';

    my $TicketID = $Param{Data}->{TicketID} // $Item{TicketID};

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $TicketID,
        UserID   => $Param{UserID},
    );

    my %ExcludedQueues = map { $_ => 1 } @{ $ConfigObject->Get('TicketChecklist::NotificationQueueExclude') || [] };

    return 1 if $ExcludedQueues{ $Ticket{Queue} };

    my %Recipients = (
        ItemResponsibleUpdate => $Item{ResponsibleKey} || $Item{ResponsibleID},
        ItemDelete            => $Item{ResponsibleKey} || $Item{ResponsibleID},
        ItemStatusUpdate      => $Ticket{OwnerID},
        ItemDueDateBefore     => $Item{ResponsibleKey} || $Item{ResponsibleID} || $Ticket{OwnerID},
        ItemDueDateUpdate     => $Item{ResponsibleKey} || $Item{ResponsibleID} || $Ticket{OwnerID},
        ItemDateStartBefore   => $Item{ResponsibleKey} || $Item{ResponsibleID} || $Ticket{OwnerID},
        ItemDateStartUpdate   => $Item{ResponsibleKey} || $Item{ResponsibleID} || $Ticket{OwnerID},
        ItemsAllClosed        => [ $Ticket{OwnerID}, ( $Ticket{ResponsibleID} // () ) ],
    );

    return 1 if $Event eq 'ItemResponsibleUpdate' && ! ( $Item{ResponsibleID} || $Item{ResponsibleKey} );

    my $IsOwnAction = 0;

    if ( $Event eq 'ItemResponsibleUpdate' && $Param{UserID} eq ( $Item{ResponsibleKey} || $Item{ResponsibleID} ) ) {
        $IsOwnAction = 1;
    }
    elsif ( $Event eq 'ItemDelete' && $Param{UserID} eq ( $Item{ResponsibleKey} || $Item{ResponsibleID} ) ) {
        $IsOwnAction = 1;
    }
    elsif ( $Event eq 'ItemStatusUpdate' && $Param{UserID} == $Ticket{OwnerID} ) {
        $IsOwnAction = 1;
    }

    return 1 if $IsOwnAction;

    my $RecipientIDs = $Recipients{$Event};
    my @IDs          = ref $RecipientIDs ? @{ $RecipientIDs } : $RecipientIDs;

    if ( $Event eq 'ItemsAllClosed' ) {
        if ( !$ConfigObject->Get('Ticket::Responsible') ) {
            pop @IDs;
        }

        @IDs = grep{ $_ != $Param{UserID} }@IDs;
    }

    return if !@IDs;

    $Item{TicketID} = $TicketID;

    $NotificationObject->NotificationSend(
        %Param,
        Data     => \%Item,
        AgentIDs => [ @IDs ],
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
